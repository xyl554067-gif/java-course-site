package com.javacourse.service;

import com.javacourse.config.AppProperties;
import com.javacourse.repository.CourseRepository;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * 搜索服务：应用层分词 + 全文匹配（不依赖 tsvector / pg_trgm）
 */
@Service
public class SearchService {

    /** 常见中英文停用词 */
    private static final Set<String> STOP_WORDS = Set.of(
            "的", "了", "是", "在", "我", "有", "和", "就", "不", "人", "都", "一",
            "一个", "上", "也", "很", "到", "说", "要", "去", "你", "会", "着", "没有",
            "看", "好", "自己", "这", "那", "什么", "怎么", "如何", "为什么",
            "the", "a", "an", "of", "to", "in", "is", "and", "or", "for", "on",
            "how", "what", "why", "can", "do", "does", "with", "java"
    );

    private final CourseRepository repo;
    private final AppProperties props;

    public SearchService(CourseRepository repo, AppProperties props) {
        this.repo = repo;
        this.props = props;
    }

    /**
     * 搜索课程内容
     */
    public List<Map<String, Object>> search(String keyword) {
        if (keyword == null || keyword.trim().isEmpty()) {
            return List.of();
        }
        String kw = keyword.trim();
        // 关键字分词：中文按字/双字，英文按词
        List<String> tokens = tokenize(kw);
        List<Map<String, Object>> raw = repo.searchIndex(kw, tokens, 60);

        // 打分排序
        List<Map<String, Object>> scored = new ArrayList<>();
        for (Map<String, Object> item : raw) {
            String title = String.valueOf(item.getOrDefault("title", ""));
            String body = String.valueOf(item.getOrDefault("body", ""));
            int score = 0;
            if (title.contains(kw)) {
                score += 100;
            }
            if (body.contains(kw)) {
                score += 30;
            }
            for (String t : tokens) {
                if (title.contains(t)) {
                    score += 20;
                }
                if (body.contains(t)) {
                    score += 8;
                }
            }
            if (score > 0) {
                Map<String, Object> m = new HashMap<>(item);
                m.put("score", score);
                m.put("highlight", highlight(body, kw, tokens));
                scored.add(m);
            }
        }
        scored.sort((a, b) -> {
            int c = Integer.compare((Integer) b.get("score"), (Integer) a.get("score"));
            return c != 0 ? c : Long.compare((Long) a.get("id"), (Long) b.get("id"));
        });
        return scored.size() > 30 ? scored.subList(0, 30) : scored;
    }

    /**
     * 简单分词：整串 + 英文/数字词 + 中文单字与双字滑窗。
     * <p>整串必须保留，否则「int和long有什么区别」这类中英混排查询在 SQL 层无法命中。</p>
     */
    public List<String> tokenize(String text) {
        Set<String> out = new LinkedHashSet<>();
        String s = text.trim().toLowerCase();
        if (s.isEmpty()) {
            return List.of();
        }
        if (s.length() >= 2) {
            out.add(s);
        }
        // 英文/数字词
        java.util.regex.Matcher m = java.util.regex.Pattern
                .compile("[a-z0-9_+#.-]{2,}").matcher(s);
        while (m.find()) {
            String t = m.group();
            if (!STOP_WORDS.contains(t)) {
                out.add(t);
            }
        }
        // 中文：单字 + 双字滑窗
        StringBuilder cn = new StringBuilder();
        for (char c : s.toCharArray()) {
            if (c >= 0x4E00 && c <= 0x9FFF) {
                cn.append(c);
            }
        }
        String cns = cn.toString();
        for (int i = 0; i < cns.length(); i++) {
            if (!STOP_WORDS.contains(String.valueOf(cns.charAt(i)))) {
                out.add(String.valueOf(cns.charAt(i)));
            }
            if (i + 2 <= cns.length()) {
                String bi = cns.substring(i, i + 2);
                if (!STOP_WORDS.contains(bi)) {
                    out.add(bi);
                }
            }
        }
        out.removeIf(t -> t.length() < props.getSearch().getMinKeywordLength() && !isChinese(t));
        return new ArrayList<>(out);
    }

    private boolean isChinese(String s) {
        return !s.isEmpty() && s.charAt(0) >= 0x4E00 && s.charAt(0) <= 0x9FFF;
    }

    /** 生成带 <mark> 标记的摘要片段 */
    private String highlight(String body, String keyword, List<String> tokens) {
        if (body == null || body.isEmpty()) {
            return "";
        }
        String excerpt = body.length() > 220 ? body.substring(0, 220) + "…" : body;
        String lower = excerpt.toLowerCase();
        int at = lower.indexOf(keyword.toLowerCase());
        if (at < 0) {
            for (String t : tokens) {
                at = lower.indexOf(t);
                if (at >= 0) {
                    break;
                }
            }
        }
        if (at < 0) {
            return escape(excerpt);
        }
        int from = Math.max(0, at - 60);
        int to = Math.min(excerpt.length(), at + keyword.length() + 100);
        String head = from > 0 ? "…" : "";
        String tail = to < excerpt.length() ? "…" : "";
        String mid = escape(excerpt.substring(from, to));
        String safeKw = escape(keyword);
        mid = mid.replace(safeKw, "<mark>" + safeKw + "</mark>");
        return head + mid + tail;
    }

    private String escape(String s) {
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");
    }
}
