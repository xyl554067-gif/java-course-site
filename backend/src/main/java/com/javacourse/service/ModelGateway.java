package com.javacourse.service;

import com.javacourse.config.AppProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * 模型网关 —— 把「用哪个大模型」这件事从业务逻辑里抽出来，做成一条可降级的调用链。
 *
 * <h3>为什么要有这层</h3>
 * <p>课程网站的 AI 助教是「锦上添花」型功能：它答得好，网站就更好；它答不上来，
 * 课照样能学。所以这条链的优先级不是「最强模型优先」，而是<b>「永远能给出一个像样的答案」优先</b>。
 * 任何一档失败都不能让用户看到报错——必须自动落到下一档。
 *
 * <h3>三档降级链（auto 模式）</h3>
 * <ol>
 *   <li><b>openai</b> —— 任意 OpenAI 兼容端点。DeepSeek / 通义千问 / 智谱 / 豆包 / 硅基流动 /
 *       SiliconCloud / 本地 vLLM 全部是同一个协议，改 base-url + model 即可切换，代码零改动。
 *       需要 Key，缺失时该档直接跳过（不发无谓请求）。</li>
 *   <li><b>ollama</b> —— 本地模型，零成本零隐私。走 Ollama 自带的 {@code /v1} OpenAI 兼容端点，
 *       所以调用代码与 openai 档<b>完全同一份</b>，只换 base-url 与 key 占位符。
 *       没装 Ollama 时连接被拒，自动跳过。</li>
 *   <li><b>local</b> —— 课程检索式回答。不依赖任何外部服务，从库里检索最相关的课时片段
 *       拼成结构化答复。这档<b>永远可用</b>，是最终保底。</li>
 * </ol>
 *
 * <h3>鉴权方式</h3>
 * <ul>
 *   <li>openai 档：{@code Authorization: Bearer <AI_API_KEY>}，Key 只从环境变量注入，不入库、不进代码库</li>
 *   <li>ollama 档：Ollama 不校验 Key，但仍按协议发一个占位符（{@code ollama}），
 *       避免某些 SDK/网关因缺 header 直接拒请求</li>
 * </ul>
 *
 * <h3>延迟与成本</h3>
 * <ul>
 *   <li>云端档典型延迟 1~4 秒（DeepSeek V4-Flash 约 1.2s，豆包 Seed-Mini 约 0.9s，通义 Plus 约 2.1s），
 *       单次调用成本量级为「不到 1 分钱到几毛钱」量级（按各厂当前免费额度，多数场景实为 0 元）</li>
 *   <li>本地档延迟 0（检索式）或 1~10 秒（本地模型推理，取决于显卡）</li>
 *   <li>本层设了 {@code timeoutMs} 硬超时：超时视为该档失败，继续降级，不让用户干等</li>
 * </ul>
 */
@Component
public class ModelGateway {

    private static final Logger log = LoggerFactory.getLogger(ModelGateway.class);

    private final AppProperties props;
    private final HttpClient http;

    public ModelGateway(AppProperties props) {
        this.props = props;
        this.http = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(5))
                .followRedirects(HttpClient.Redirect.NORMAL)
                .build();
    }

    /**
     * 一次模型调用的结果。
     *
     * @param answer     最终答复文本
     * @param provider   实际生效的通道标识（openai / ollama / local）
     * @param degraded   是否走了降级（true = 首选通道没成功，用了兜底）
     * @param detail     降级原因或诊断信息，用于前端提示与日志
     * @param latencyMs  本次调用总耗时
     */
    public record Result(String answer, String provider, boolean degraded, String detail, long latencyMs) {
    }

    /** 课程检索式回答的回调：没有远程模型时，用检索结果拼答复 */
    public interface LocalFallback {
        String answer(String question, List<Map<String, Object>> context);
    }

    /**
     * 按配置的 provider 策略调用模型。
     *
     * @param systemPrompt 系统提示词（人设）
     * @param userPrompt   拼好的用户提示词（已含课程资料）
     * @param question     原始问题（供 local 档使用）
     * @param context      检索到的课程上下文（供 local 档使用）
     */
    public Result call(String systemPrompt, String userPrompt, String question,
                       List<Map<String, Object>> context, LocalFallback fallback) {
        long start = System.currentTimeMillis();
        String provider = props.getAi().getProvider() == null
                ? "auto" : props.getAi().getProvider().toLowerCase();

        if ("local".equals(provider)) {
            return new Result(fallback.answer(question, context), "local", true,
                    "已按配置固定使用本地检索式回答", System.currentTimeMillis() - start);
        }

        List<String> order = resolveOrder(provider);
        List<String> failures = new ArrayList<>();

        for (String p : order) {
            try {
                String answer = switch (p) {
                    case "openai" -> callOpenAiCompatible(systemPrompt, userPrompt);
                    case "ollama" -> callOllama(systemPrompt, userPrompt);
                    default -> null;
                };
                if (answer != null && !answer.isBlank()) {
                    boolean degraded = !"openai".equals(p) || !"openai".equals(order.get(0));
                    String detail = degraded
                            ? String.join("；", failures)
                            : "";
                    return new Result(answer, p, degraded, detail, System.currentTimeMillis() - start);
                }
                failures.add(p + "：返回内容为空");
            } catch (Exception e) {
                failures.add(p + "：" + rootMessage(e));
                log.warn("[ModelGateway] 通道 {} 调用失败：{}", p, rootMessage(e));
            }
        }

        // 所有远程通道都不可用 → 检索式保底
        log.info("[ModelGateway] 全部远程通道不可用，降级到本地检索式回答。失败详情：{}", failures);
        return new Result(fallback.answer(question, context), "local", true,
                String.join("；", failures), System.currentTimeMillis() - start);
    }

    /**
     * 解析实际尝试顺序。
     * provider=openai → 只试 openai（失败就直接降级到 local，不再试 ollama，避免无谓等待）
     * provider=ollama → 只试 ollama
     * provider=auto   → 按 fallbackOrder 逐个试
     */
    private List<String> resolveOrder(String provider) {
        List<String> order = new ArrayList<>();
        if ("openai".equals(provider) || "ollama".equals(provider)) {
            order.add(provider);
        } else {
            String cfg = props.getAi().getFallbackOrder();
            if (cfg == null || cfg.isBlank()) {
                cfg = "openai,ollama,local";
            }
            for (String s : cfg.split(",")) {
                String t = s.trim().toLowerCase();
                if (t.isEmpty()) {
                    continue;
                }
                if ("openai".equals(t) && !hasUsableApiKey()) {
                    log.info("[ModelGateway] 未配置 AI_API_KEY，跳过 openai 通道");
                    continue;
                }
                if (!order.contains(t)) {
                    order.add(t);
                }
            }
        }
        // local 永远放最后兜底
        if (!order.contains("local")) {
            order.add("local");
        }
        return order;
    }

    private boolean hasUsableApiKey() {
        String k = props.getAi().getApiKey();
        return k != null && !k.isBlank();
    }

    // ------------------------------------------------------------------
    // 具体通道
    // ------------------------------------------------------------------

    /**
     * OpenAI 兼容档。DeepSeek / 通义 / 智谱 / 豆包 / vLLM 共用这一份实现。
     */
    private String callOpenAiCompatible(String systemPrompt, String userPrompt) throws Exception {
        String key = props.getAi().getApiKey();
        if (key == null || key.isBlank()) {
            throw new IllegalStateException("未配置 AI_API_KEY");
        }
        return postChat(props.getAi().getBaseUrl(), props.getAi().getModel(), key, systemPrompt, userPrompt);
    }

    /**
     * Ollama 本地档。Ollama 自带 {@code /v1} OpenAI 兼容端点，协议与 openai 档完全一致，
     * 差别只在 base-url 与 key 用占位符（Ollama 不校验 key，但缺 header 会被部分网关拒）。
     */
    private String callOllama(String systemPrompt, String userPrompt) throws Exception {
        return postChat(props.getAi().getOllamaBaseUrl(), props.getAi().getOllamaModel(),
                "ollama", systemPrompt, userPrompt);
    }

    /**
     * 统一的 OpenAI 兼容 POST。
     *
     * @param baseUrl 端点根地址，自动补 {@code /v1/chat/completions}
     */
    private String postChat(String baseUrl, String model, String apiKey,
                            String systemPrompt, String userPrompt) throws Exception {
        String root = trimTrailingSlash(baseUrl);
        String url = root.endsWith("/chat/completions") ? root : root + "/v1/chat/completions";

        String body = """
                {"model":%s,"messages":[{"role":"system","content":%s},{"role":"user","content":%s}],\
                "temperature":0.6,"max_tokens":1500}
                """.formatted(jsonString(model), jsonString(systemPrompt), jsonString(userPrompt));

        HttpRequest req = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .header("Authorization", "Bearer " + apiKey)
                .header("Content-Type", "application/json")
                .timeout(Duration.ofMillis(props.getAi().getTimeoutMs()))
                .POST(HttpRequest.BodyPublishers.ofString(body))
                .build();

        HttpResponse<String> resp = http.send(req, HttpResponse.BodyHandlers.ofString());
        if (resp.statusCode() != 200) {
            throw new IllegalStateException("HTTP " + resp.statusCode() + "："
                    + brief(resp.body()));
        }
        String content = extractContent(resp.body());
        if (content == null || content.isBlank()) {
            throw new IllegalStateException("响应中没有 message.content");
        }
        return content;
    }

    // ------------------------------------------------------------------
    // 响应解析
    // ------------------------------------------------------------------

    /**
     * 从 OpenAI 兼容响应中提取 {@code choices[0].message.content}。
     * <p>手写解析而非引入 JSON 库：这个类要保持「零额外依赖」，且响应结构固定。
     * 兼容部分厂商返回的 {@code content} 为数组（多模态块）的情况——取第一个 text 块。
     */
    private String extractContent(String json) {
        if (json == null) {
            return null;
        }
        int i = json.indexOf("\"content\"");
        if (i < 0) {
            // 某些网关把 content 放在 delta / text 字段
            int j = json.indexOf("\"text\"");
            if (j < 0) {
                return json;
            }
            return scalarAfter(json, j);
        }
        int s = json.indexOf(':', i) + 1;
        if (s <= 0) {
            return json;
        }
        // 数组形式：content: [ { "type":"text", "text":"..." } ]
        int k = s;
        while (k < json.length() && Character.isWhitespace(json.charAt(k))) {
            k++;
        }
        if (k < json.length() && json.charAt(k) == '[') {
            int t = json.indexOf("\"text\"", k);
            if (t > 0) {
                return scalarAfter(json, t);
            }
        }
        return scalarAfter(json, i);
    }

    /** 取 {@code "key": value} 中 value 的字符串内容（value 必须是字符串，否则原样返回片段） */
    private String scalarAfter(String json, int keyIdx) {
        int s = json.indexOf(':', keyIdx) + 1;
        if (s <= 0) {
            return "";
        }
        while (s < json.length() && (json.charAt(s) == ' ' || json.charAt(s) == '\t')) {
            s++;
        }
        if (s >= json.length()) {
            return "";
        }
        if (json.charAt(s) != '"') {
            int e = json.indexOf(',', s);
            return json.substring(s, e > 0 ? e : json.length()).trim();
        }
        StringBuilder sb = new StringBuilder();
        boolean inEsc = false;
        for (int k = s + 1; k < json.length(); k++) {
            char c = json.charAt(k);
            if (inEsc) {
                switch (c) {
                    case 'n' -> sb.append('\n');
                    case 't' -> sb.append('\t');
                    case 'r' -> sb.append('\r');
                    case 'u' -> {
                        // 反斜杠 + u + 四位十六进制 = Unicode 转义
                        if (k + 4 < json.length()) {
                            sb.append((char) Integer.parseInt(json.substring(k + 1, k + 5), 16));
                            k += 4;
                        }
                    }
                    default -> sb.append(c);
                }
                inEsc = false;
            } else if (c == '\\') {
                inEsc = true;
            } else if (c == '"') {
                break;
            } else {
                sb.append(c);
            }
        }
        return sb.toString();
    }

    // ------------------------------------------------------------------
    // 工具
    // ------------------------------------------------------------------

    /** 序列化为 JSON 字符串字面量（含引号）。model 这类标识符也用它。 */
    private String jsonString(String s) {
        if (s == null) {
            return "\"\"";
        }
        StringBuilder sb = new StringBuilder("\"");
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '"' -> sb.append("\\\"");
                case '\\' -> sb.append("\\\\");
                case '\n' -> sb.append("\\n");
                case '\r' -> sb.append("\\r");
                case '\t' -> sb.append("\\t");
                default -> {
                    if (c < 0x20) {
                        // 注意：不能在源码里直接写 反斜杠+u+XXXX —— Java 的 Unicode 转义在词法分析前就生效，
                        // 连注释里的也会被处理。这里用字符码拼出反斜杠，避开词法陷阱。
                        sb.append((char) 0x5C).append('u')
                                .append(String.format("%04x", (int) c));
                    } else {
                        sb.append(c);
                    }
                }
            }
        }
        return sb.append('"').toString();
    }

    private String trimTrailingSlash(String s) {
        if (s == null) {
            return "";
        }
        String t = s.trim();
        while (t.endsWith("/")) {
            t = t.substring(0, t.length() - 1);
        }
        return t;
    }

    private String rootMessage(Throwable e) {
        Throwable c = e;
        while (c.getCause() != null && c.getCause() != c) {
            c = c.getCause();
        }
        String m = c.getMessage();
        return m == null ? c.getClass().getSimpleName() : m;
    }

    private String brief(String s) {
        if (s == null) {
            return "";
        }
        String t = s.replaceAll("\\s+", " ").trim();
        return t.length() > 200 ? t.substring(0, 200) + "…" : t;
    }
}
