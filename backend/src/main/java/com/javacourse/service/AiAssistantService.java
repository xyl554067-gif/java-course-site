package com.javacourse.service;

import com.javacourse.config.AppProperties;
import com.javacourse.repository.CourseRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * AI 助教服务 —— 形象为 dsh-pet 的「鲸鲸」(Ciallo~)
 * <p>模型接入采用可替换适配层：
 * <ul>
 *   <li>{@code builtin}：WorkBuddy 内置免密钥通道（默认），无需外部 Key</li>
 *   <li>{@code openai}：OpenAI 兼容接口，Key 走环境变量 {@code AI_API_KEY}</li>
 * </ul>
 * </p>
 */
@Service
public class AiAssistantService {

    private static final Logger log = LoggerFactory.getLogger(AiAssistantService.class);

    private final CourseRepository repo;
    private final SearchService search;
    private final JdbcTemplate jdbc;
    private final AppProperties props;
    private final ModelGateway gateway;

    /** 鲸鲸的人设提示词 */
    private static final String PERSONA = """
            你是「鲸鲸」，一只蓝发猫耳的 Ciallo 小助手，也是这个 Java 课程网站的助教。
            性格：活泼、亲切、略带俏皮，偶尔用「Ciallo~」「喵」结尾，但讲解技术时必须严谨准确。
            规则：
            1. 只依据【课程资料】回答；资料不足时明确说明，并引导用户去看对应课时。
            2. 回答用中文，结构清晰：先给结论，再给分点讲解，必要时给 Java 代码示例。
            3. 代码示例必须可直接编译运行，注明涉及的 JDK 版本与关键 API。
            4. 回答结尾给一句鼓励，但不要过度堆砌颜文字。
            """;

    public AiAssistantService(CourseRepository repo, SearchService search, JdbcTemplate jdbc,
                               AppProperties props, ModelGateway gateway) {
        this.repo = repo;
        this.search = search;
        this.jdbc = jdbc;
        this.props = props;
        this.gateway = gateway;
    }

    /**
     * 提问并返回回答
     */
    public Map<String, Object> ask(long userId, String question, String sessionTitle) {
        long start = System.currentTimeMillis();
        List<String> tokens = search.tokenize(question);
        int limit = props.getAi().getContextLimit();
        List<Map<String, Object>> context =
                repo.searchContext(question, tokens, Math.max(limit * 5, 30));
        // 只保留真正相关的：整串命中优先，其次按命中 token 数排序
        String kw = question.trim().toLowerCase();
        context.sort((a, b) -> {
            int c = Integer.compare(hit(b, kw, tokens), hit(a, kw, tokens));
            return c != 0 ? c : Long.compare((Long) a.get("id"), (Long) b.get("id"));
        });
        List<Map<String, Object>> top = new ArrayList<>(context.subList(0, Math.min(limit, context.size())));
        context = top;

        // 注意：这里不再拼 PERSONA。人设由 ModelGateway 作为 system 消息单独传，
        // 若在这里也拼一遍，同一段人设会在 system 与 user 里各出现一次（既浪费 token 又让模型困惑）。
        StringBuilder prompt = new StringBuilder("【课程资料】\n");
        if (context.isEmpty()) {
            prompt.append("（本次未检索到相关课时内容）\n");
        } else {
            for (Map<String, Object> c : context) {
                prompt.append("## ").append(c.get("title")).append('\n');
                prompt.append(String.valueOf(c.get("summary"))).append('\n');
                String body = String.valueOf(c.get("content"));
                if (body.length() > 1200) {
                    body = body.substring(0, 1200) + "…";
                }
                prompt.append(body).append("\n\n");
            }
        }
        prompt.append("\n【用户问题】\n").append(question);

        String answer = callModel(userId, prompt.toString(), question, context);

        List<Map<String, Object>> citations = new ArrayList<>();
        for (Map<String, Object> c : context) {
            Map<String, Object> m = new HashMap<>();
            m.put("title", c.get("title"));
            m.put("slug", c.get("slug"));
            m.put("summary", c.get("summary"));
            citations.add(m);
        }

        long latency = System.currentTimeMillis() - start;

        // 落库聊天记录
        Long sessionId = ensureSession(userId, sessionTitle, question);
        jdbc.update("INSERT INTO ai_chat_message (session_id, role, content, citations, latency_ms) "
                        + "VALUES (?, 'user', ?, ?, ?)",
                sessionId, question, null, latency);
        jdbc.update("INSERT INTO ai_chat_message (session_id, role, content, citations, latency_ms) "
                        + "VALUES (?, 'assistant', ?, ?, ?)",
                sessionId, answer, toJsonBrief(citations), latency);

        Map<String, Object> result = new HashMap<>();
        result.put("answer", answer);
        result.put("citations", citations);
        result.put("sessionId", sessionId);
        result.put("latencyMs", latency);
        result.put("agent", agentProfile());
        result.put("provider", lastProvider.get());
        result.put("degraded", lastDegraded.get());
        return result;
    }

    /** 鲸鲸形象元信息，前端据此渲染 */
    public Map<String, Object> agentProfile() {
        Map<String, Object> m = new HashMap<>();
        m.put("key", "whale");
        m.put("name", "鲸鲸");
        m.put("title", "Ciallo~ 课程助教");
        m.put("greeting", "Ciallo~ 我是鲸鲸！Java 学习上有什么不懂的，尽管问我喵～");
        m.put("avatars", List.of(
                "/assets/agent/agent-idle.png",
                "/assets/agent/agent-happy.png",
                "/assets/agent/agent-think.png",
                "/assets/agent/agent-ok.png"));
        m.put("moods", List.of("idle", "happy", "think", "ok"));
        return m;
    }

    /**
     * AI 通道诊断信息 —— 供前端展示「当前 AI 状态」。
     * 不返回任何密钥内容，只报告「配没配、指向哪」。
     */
    public Map<String, Object> aiHealth() {
        Map<String, Object> m = new HashMap<>();
        String provider = props.getAi().getProvider();
        m.put("provider", provider);
        m.put("baseUrl", props.getAi().getBaseUrl());
        m.put("model", props.getAi().getModel());
        m.put("fallbackOrder", props.getAi().getFallbackOrder());
        m.put("ollamaBaseUrl", props.getAi().getOllamaBaseUrl());
        m.put("ollamaModel", props.getAi().getOllamaModel());
        m.put("timeoutMs", props.getAi().getTimeoutMs());
        boolean hasKey = props.getAi().getApiKey() != null && !props.getAi().getApiKey().isBlank();
        m.put("openaiConfigured", hasKey);
        // 当前能用的最高优先级通道（前端据此提示用户）
        m.put("effective", hasKey ? "openai" : "local");
        m.put("degraded", !hasKey);
        m.put("note", hasKey
                ? "已配置云端大模型 Key，回答由大模型生成"
                : "未配置 AI_API_KEY，回答使用本地课程检索式兜底（功能可用，措辞更机械）");
        return m;
    }

    /**
     * 相关度打分：整串出现在标题/摘要/正文里权重最高，其次统计命中的 token 数。
     */
    private int hit(Map<String, Object> c, String keyword, List<String> tokens) {
        String title = String.valueOf(c.get("title")).toLowerCase();
        String summary = String.valueOf(c.get("summary")).toLowerCase();
        String content = String.valueOf(c.get("content")).toLowerCase();
        int score = 0;
        if (title.contains(keyword)) {
            score += 200;
        }
        if (summary.contains(keyword)) {
            score += 80;
        }
        if (content.contains(keyword)) {
            score += 40;
        }
        for (String t : tokens) {
            if (t.length() < 2) {
                continue;
            }
            if (title.contains(t)) {
                score += 12;
            }
            if (summary.contains(t)) {
                score += 6;
            }
            if (content.contains(t)) {
                score += 2;
            }
        }
        return score;
    }

    private Long ensureSession(long userId, String title, String firstQuestion) {
        String t = (title == null || title.isBlank())
                ? truncate(firstQuestion, 40) : truncate(title.trim(), 40);
        if (userId > 0) {
            List<Long> ids = jdbc.queryForList(
                    "SELECT id FROM ai_chat_session WHERE user_id = ? ORDER BY id DESC", Long.class, userId);
            if (!ids.isEmpty()) {
                return ids.get(0);
            }
        }
        org.springframework.jdbc.support.KeyHolder kh = new org.springframework.jdbc.support.GeneratedKeyHolder();
        jdbc.update(connection -> {
            java.sql.PreparedStatement ps = connection.prepareStatement(
                    "INSERT INTO ai_chat_session (user_id, title, agent_key) VALUES (?, ?, 'whale')",
                    new String[]{"id"});
            if (userId > 0) {
                ps.setLong(1, userId);
            } else {
                ps.setNull(1, java.sql.Types.BIGINT);
            }
            ps.setString(2, t);
            return ps;
        }, kh);
        Number key = kh.getKey();
        return key == null ? 0L : key.longValue();
    }

    /**
     * 模型调用适配层 —— 委托给 {@link ModelGateway} 处理多通道降级。
     */
    private final ThreadLocal<String> lastProvider = new ThreadLocal<>();
    private final ThreadLocal<Boolean> lastDegraded = new ThreadLocal<>();

    private String callModel(long userId, String fullPrompt, String question, List<Map<String, Object>> context) {
        ModelGateway.Result r = gateway.call(userId, PERSONA, fullPrompt, question, context, this::localAnswer);
        lastProvider.set(r.provider());
        lastDegraded.set(r.degraded());
        if (r.degraded() && r.detail() != null && !r.detail().isBlank()) {
            log.info("[AI] 已降级到 {} 通道：{}", r.provider(), r.detail());
        }
        return r.answer();
    }

    /**
     * 本地检索式回答（所有远程通道都不可用时的最终兜底）：
     * 从课程内容中定位最相关的片段，拼接成结构化答复。
     */
    private String localAnswer(String question, List<Map<String, Object>> context) {
        if (context.isEmpty()) {
            return "Ciallo~ 我在课程资料里没有检索到和「" + question + "」相关的内容喵。\n\n"
                    + "你可以试试换个说法，或者直接到「课程目录」里按模块浏览，"
                    + "《Java 精通之路》共 6 个模块 42 课时，总有一节能帮到你！";
        }
        StringBuilder sb = new StringBuilder();
        sb.append("Ciallo～关于「").append(question).append("」，我在课程里找到了这些内容：\n\n");
        int i = 1;
        for (Map<String, Object> c : context) {
            sb.append("**").append(i++).append(". ").append(c.get("title")).append("**\n");
            sb.append(c.get("summary")).append("\n");
            String body = String.valueOf(c.get("content"));
            // 截取与问题最相关的一段
            String snippet = relevantSnippet(body, question);
            if (!snippet.isEmpty()) {
                sb.append("\n> ").append(snippet).append("\n");
            }
            sb.append("\n[查看该课时](").append("/lesson/").append(c.get("slug")).append(")\n\n");
        }
        sb.append("---\n想继续深挖的话，点上面的课时链接看完整讲解吧，喵～");
        return sb.toString();
    }

    /** 从正文中截取与问题关键词重合度最高的片段 */
    private String relevantSnippet(String body, String question) {
        if (body == null || body.isEmpty()) {
            return "";
        }
        String[] terms = question.replaceAll("[，。？！,.?！\\s]+", " ")
                .split("\\s+");
        String best = "";
        int bestScore = -1;
        String[] paragraphs = body.split("\n");
        for (String p : paragraphs) {
            if (p.trim().length() < 10) {
                continue;
            }
            int score = 0;
            for (String t : terms) {
                if (t.length() >= 2 && p.contains(t)) {
                    score += t.length();
                }
            }
            if (score > bestScore) {
                bestScore = score;
                best = p.trim();
            }
        }
        if (best.length() > 400) {
            best = best.substring(0, 400) + "…";
        }
        return best;
    }

    private String toJsonBrief(List<Map<String, Object>> citations) {
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < citations.size(); i++) {
            if (i > 0) {
                sb.append(',');
            }
            sb.append("{\"title\":\"").append(escapeJson(String.valueOf(citations.get(i).get("title"))))
                    .append("\",\"slug\":\"").append(escapeJson(String.valueOf(citations.get(i).get("slug"))))
                    .append("\"}");
        }
        return sb.append(']').toString();
    }

    private String escapeJson(String s) {
        return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "");
    }

    private String truncate(String s, int max) {
        if (s == null) {
            return null;
        }
        return s.length() <= max ? s : s.substring(0, max);
    }
}

