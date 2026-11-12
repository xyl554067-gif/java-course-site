package com.javacourse.service;

import com.javacourse.config.AppProperties;
import com.javacourse.repository.CourseRepository;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/** 鲸鲸学习助教，只用当前问题和公开课时资料答疑。 */
@Service
public class AiAssistantService {
    private final CourseRepository repo;
    private final SearchService search;
    private final AppProperties props;
    private final ModelGateway gateway;

    public AiAssistantService(CourseRepository repo, SearchService search, AppProperties props, ModelGateway gateway) {
        this.repo = repo;
        this.search = search;
        this.props = props;
        this.gateway = gateway;
    }

    public Map<String, Object> ask(long userId, String question) {
        return ask(userId, question, false, null);
    }

    public Map<String, Object> ask(long userId, String question, boolean localOnly, String lessonSlug) {
        long start = System.currentTimeMillis();
        if (containsSensitiveValue(question)) {
            return reply(AssistantPolicy.INPUT_BLOCKED, List.of(), "local", false, true, start);
        }
        String basic = AssistantPolicy.basicAnswer(question);
        if (basic != null) {
            return reply(basic, List.of(), "local", false, false, start);
        }
        if (AssistantPolicy.requestsPrivateData(question)) {
            return reply(AssistantPolicy.REQUEST_REFUSED, List.of(), "local", false, true, start);
        }

        List<Map<String, Object>> context = publicContext(question, lessonSlug);
        ModelGateway.Result result = localOnly
                ? new ModelGateway.Result(localAnswer(question, context), "local", false, "", 0)
                : gateway.call(userId, AssistantPolicy.PERSONA, modelPrompt(question, context), question,
                        context, this::localAnswer);
        if (AssistantPolicy.INPUT_BLOCKED.equals(result.answer())) {
            return reply(AssistantPolicy.INPUT_BLOCKED, List.of(), "local", false, true, start);
        }
        if (containsConfiguredSecret(result.answer()) || AssistantPolicy.unsafeAnswer(result.answer())) {
            return reply(AssistantPolicy.OUTPUT_BLOCKED, List.of(), "local", false, true, start);
        }
        List<Map<String, Object>> citations = context.stream()
                .map(lesson -> Map.of("title", lesson.get("title"), "slug", lesson.get("slug"),
                        "summary", lesson.get("summary")))
                .toList();
        return reply(result.answer(), citations, result.provider(), result.degraded(), false, start);
    }

    private String modelPrompt(String question, List<Map<String, Object>> context) {
        StringBuilder prompt = new StringBuilder("【公开课程资料】\n");
        if (context.isEmpty()) {
            prompt.append("（本次未检索到相关课时内容）\n");
        } else {
            for (Map<String, Object> lesson : context) {
                prompt.append("## ").append(lesson.get("title")).append('\n');
                prompt.append(lesson.get("summary")).append('\n');
                prompt.append(lesson.get("content")).append("\n\n");
            }
        }
        prompt.append("\n【用户问题】\n").append(question);

        return prompt.toString();
    }

    private Map<String, Object> reply(String answer, List<Map<String, Object>> citations,
                                      String provider, boolean degraded, boolean blocked, long start) {
        return Map.of("answer", answer, "citations", citations, "latencyMs", System.currentTimeMillis() - start,
                "agent", agentProfile(), "provider", provider, "degraded", degraded, "blocked", blocked);
    }

    private List<Map<String, Object>> publicContext(String question, String lessonSlug) {
        int limit = Math.max(0, Math.min(props.getAi().getContextLimit(), 6));
        if (limit == 0) return List.of();

        List<Map<String, Object>> context = new ArrayList<>();
        if (lessonSlug != null) {
            Map<String, Object> selected = publicExcerpt(repo.findPublicAssistantLesson(lessonSlug));
            if (!selected.isEmpty()) context.add(selected);
        }
        if (context.size() == limit) return context;
        List<String> tokens = search.tokenize(question);
        String keyword = question.toLowerCase(Locale.ROOT);
        int remaining = limit - context.size();
        repo.searchContext(question, tokens, 30).stream()
                .filter(lesson -> !String.valueOf(lesson.get("slug")).equals(lessonSlug))
                .filter(lesson -> hit(lesson, keyword, tokens) > 0)
                .sorted(Comparator.<Map<String, Object>>comparingInt(lesson -> hit(lesson, keyword, tokens))
                        .reversed().thenComparingLong(lesson -> ((Number) lesson.get("id")).longValue()))
                .map(this::publicExcerpt)
                .filter(lesson -> !lesson.isEmpty())
                .limit(remaining)
                .forEachOrdered(context::add);
        return context;
    }

    private Map<String, Object> publicExcerpt(Map<String, Object> lesson) {
        String slug = String.valueOf(lesson.get("slug"));
        String title = safeExcerpt(lesson.get("title"), 160);
        if (!slug.matches("[a-z0-9-]{1,80}") || title.isBlank()) return Map.of();
        return Map.of("slug", slug, "title", title,
                "summary", safeExcerpt(lesson.get("summary"), 360),
                "content", safeExcerpt(lesson.get("content"), 1200));
    }

    private String safeExcerpt(Object field, int maxLength) {
        if (!(field instanceof String text) || containsSensitiveValue(text)) return "";
        return text.length() <= maxLength ? text : text.substring(0, maxLength) + "…";
    }

    private boolean containsSensitiveValue(String text) {
        return containsConfiguredSecret(text) || AssistantPolicy.containsSensitiveValue(text);
    }

    private boolean containsConfiguredSecret(String text) {
        return containsSecret(text, props.getAi().getApiKey())
                || containsSecret(text, props.getAi().getUserConfigEncryptionKey())
                || containsSecret(text, props.getJwt().getSecret());
    }

    private boolean containsSecret(String text, String secret) {
        return text != null && secret != null && !secret.isBlank() && text.contains(secret);
    }

    public Map<String, Object> agentProfile() {
        return Map.of(
                "key", "whale",
                "name", "鲸鲸",
                "title", "Java 学习助教",
                "greeting", AssistantPolicy.GREETING,
                "avatars", List.of("/assets/agent/agent-idle.png", "/assets/agent/agent-happy.png",
                        "/assets/agent/agent-think.png", "/assets/agent/agent-ok.png"),
                "moods", List.of("idle", "happy", "think", "ok"));
    }

    public Map<String, Object> aiHealth() {
        return Map.of("ready", true);
    }

    private int hit(Map<String, Object> lesson, String keyword, List<String> tokens) {
        String title = String.valueOf(lesson.get("title")).toLowerCase(Locale.ROOT);
        String summary = String.valueOf(lesson.get("summary")).toLowerCase(Locale.ROOT);
        String content = String.valueOf(lesson.get("content")).toLowerCase(Locale.ROOT);
        int score = 0;
        if (title.contains(keyword)) score += 200;
        if (summary.contains(keyword)) score += 80;
        if (content.contains(keyword)) score += 40;
        for (String token : tokens) {
            if (token.length() < 2) continue;
            if (title.contains(token)) score += 12;
            if (summary.contains(token)) score += 6;
            if (content.contains(token)) score += 2;
        }
        return score;
    }

    /** 远程模型不可用时，用公开课时片段提供可核对的线索。 */
    private String localAnswer(String question, List<Map<String, Object>> context) {
        if (context.isEmpty()) {
            return "我暂时没有找到相关课时。可以试试输入 Java 概念、异常名，或贴上去掉个人信息的最小代码片段。";
        }
        StringBuilder answer = new StringBuilder("我在课程里找到了这些线索：\n\n");
        int i = 1;
        for (Map<String, Object> lesson : context) {
            answer.append("**").append(i++).append(". ").append(lesson.get("title")).append("**\n");
            answer.append(lesson.get("summary")).append('\n');
            String snippet = relevantSnippet(String.valueOf(lesson.get("content")), question);
            if (!snippet.isEmpty()) {
                answer.append("\n> ").append(snippet).append('\n');
            }
            answer.append("\n[查看该课时](/lesson/").append(lesson.get("slug")).append(")\n\n");
        }
        return answer.toString();
    }

    private String relevantSnippet(String body, String question) {
        String[] terms = question.split("[，。？！,.?！\\s]+");
        String best = "";
        int bestScore = -1;
        for (String line : body.lines().toList()) {
            String trimmed = line.strip();
            if (trimmed.length() < 10) continue;
            int score = 0;
            for (String term : terms) {
                if (term.length() >= 2 && trimmed.contains(term)) score += term.length();
            }
            if (score > bestScore) {
                bestScore = score;
                best = trimmed;
            }
        }
        return best.length() <= 400 ? best : best.substring(0, 400) + "…";
    }
}
