package com.javacourse.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.javacourse.config.AppProperties;
import jakarta.annotation.PreDestroy;
import org.apache.hc.client5.http.classic.methods.HttpPost;
import org.apache.hc.client5.http.config.ConnectionConfig;
import org.apache.hc.client5.http.config.RequestConfig;
import org.apache.hc.client5.http.impl.classic.CloseableHttpClient;
import org.apache.hc.client5.http.impl.classic.HttpClients;
import org.apache.hc.client5.http.impl.io.PoolingHttpClientConnectionManagerBuilder;
import org.apache.hc.core5.http.ContentType;
import org.apache.hc.core5.http.io.entity.StringEntity;
import org.apache.hc.core5.util.Timeout;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.nio.charset.StandardCharsets;
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
 *   <li>openai 档：使用账号级 AES-GCM 加密配置，未设置时才使用站点环境变量</li>
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

    private static final ObjectMapper JSON = new ObjectMapper();

    private final AppProperties props;
    private final UserAiConfigService userConfigs;
    private final HttpClient http;
    private final CloseableHttpClient accountHttp;

    public ModelGateway(AppProperties props, UserAiConfigService userConfigs) {
        this.props = props;
        this.userConfigs = userConfigs;
        this.http = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(5))
                .followRedirects(HttpClient.Redirect.NEVER)
                .build();
        this.accountHttp = HttpClients.custom()
                .setConnectionManager(PoolingHttpClientConnectionManagerBuilder.create()
                        .setDnsResolver(new PublicModelDns())
                        .setDefaultConnectionConfig(ConnectionConfig.custom()
                                .setConnectTimeout(Timeout.ofSeconds(5)).build())
                        .setMaxConnTotal(16)
                        .setMaxConnPerRoute(4)
                        .build())
                .disableRedirectHandling()
                .disableAutomaticRetries()
                .disableCookieManagement()
                .disableAuthCaching()
                .build();
    }

    @PreDestroy
    void closeAccountClient() throws java.io.IOException {
        accountHttp.close();
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

    /** Course generation shares the same provider configuration as the assistant. */
    public Result generate(long userId, String systemPrompt, String userPrompt, String fallbackJson) {
        long start = System.currentTimeMillis();
        UserAiConfigService.ModelConfig accountConfig;
        try { accountConfig = userConfigs.get(userId); }
        catch (Exception e) {
            log.warn("[ModelGateway] 账号模型配置不可用：{}", safeFailure(e));
            return new Result(fallbackJson, "local", true, "账号 AI 配置不可用，已生成基于资料的可编辑草稿", System.currentTimeMillis() - start);
        }
        if (accountConfig != null) {
            try {
                String answer = postAccountChat(accountConfig, systemPrompt, userPrompt, 6000);
                return new Result(answer, "account", false, "", System.currentTimeMillis() - start);
            } catch (Exception e) {
                log.warn("[ModelGateway] 账号模型配置调用失败：{}", safeFailure(e));
                return new Result(fallbackJson, "local", true,
                        "账号 AI 接口暂不可用，已生成基于资料的可编辑草稿：" + safeFailure(e), System.currentTimeMillis() - start);
            }
        }
        String provider = props.getAi().getProvider() == null ? "auto" : props.getAi().getProvider().toLowerCase();
        List<String> order = resolveOrder(provider);
        List<String> failures = new ArrayList<>();
        if (!"local".equals(provider)) {
            for (String p : order) {
                if ("local".equals(p)) break;
                try {
                    String answer = switch (p) {
                        case "openai" -> postChat(props.getAi().getBaseUrl(), props.getAi().getModel(),
                                props.getAi().getApiKey(), systemPrompt, userPrompt, 6000);
                        case "ollama" -> postChat(props.getAi().getOllamaBaseUrl(), props.getAi().getOllamaModel(),
                                null, systemPrompt, userPrompt, 6000);
                        default -> null;
                    };
                    if (answer != null && !answer.isBlank())
                        return new Result(answer, p, !failures.isEmpty(), String.join("；", failures),
                                System.currentTimeMillis() - start);
                    failures.add(p + "：返回内容为空");
                } catch (Exception e) {
                    failures.add(p + "：" + safeFailure(e));
                    log.warn("[ModelGateway] 课程生成通道 {} 调用失败：{}", p, safeFailure(e));
                }
            }
        }
        return new Result(fallbackJson, "local", true,
                failures.isEmpty() ? "未配置可用的大模型，已生成基于资料的可编辑草稿" : String.join("；", failures),
                System.currentTimeMillis() - start);
    }

    /**
     * 按配置的 provider 策略调用模型。
     *
     * @param systemPrompt 系统提示词（人设）
     * @param userPrompt   拼好的用户提示词（已含课程资料）
     * @param question     原始问题（供 local 档使用）
     * @param context      检索到的课程上下文（供 local 档使用）
     */
    public Result call(long userId, String systemPrompt, String userPrompt, String question,
                       List<Map<String, Object>> context, LocalFallback fallback) {
        long start = System.currentTimeMillis();
        UserAiConfigService.ModelConfig accountConfig;
        try { accountConfig = userConfigs.get(userId); }
        catch (Exception e) {
            log.warn("[ModelGateway] 账号模型配置不可用：{}", safeFailure(e));
            return new Result(fallback.answer(question, context), "local", true,
                    "账号 AI 配置不可用，已使用课程检索兜底", System.currentTimeMillis() - start);
        }
        if (accountConfig != null) {
            if (containsCredential(userPrompt, accountConfig.apiKey())) {
                return new Result(AssistantPolicy.INPUT_BLOCKED, "local", false, "",
                        System.currentTimeMillis() - start);
            }
            try {
                String answer = postAccountChat(accountConfig, systemPrompt, userPrompt, 1500);
                return new Result(answer, "account", false, "", System.currentTimeMillis() - start);
            } catch (Exception e) {
                log.warn("[ModelGateway] 账号模型配置调用失败：{}", safeFailure(e));
                return new Result(fallback.answer(question, context), "local", true,
                        "账号 AI 接口暂不可用，已使用课程检索兜底：" + safeFailure(e), System.currentTimeMillis() - start);
            }
        }
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
                failures.add(p + "：" + safeFailure(e));
                log.warn("[ModelGateway] 通道 {} 调用失败：{}", p, safeFailure(e));
            }
        }

        // 所有远程通道都不可用 → 检索式保底
        log.info("[ModelGateway] 全部远程通道不可用，降级到本地检索式回答。失败详情：{}", failures);
        return new Result(fallback.answer(question, context), "local", true,
                String.join("；", failures), System.currentTimeMillis() - start);
    }

    /** Validate a user's unsaved endpoint and credentials with a minimal completion request. */
    public Map<String, Object> testAccountConfig(long userId, String baseUrl, String model, String apiKey) {
        long start = System.currentTimeMillis();
        UserAiConfigService.ModelConfig config = userConfigs.proposed(baseUrl, model, apiKey, userId);
        try {
            postAccountChat(config,
                    "你是一个连接测试助手。", "请仅回复：连接成功", 24);
            return Map.of("ok", true, "message", "连接成功", "latencyMs", System.currentTimeMillis() - start);
        } catch (Exception e) {
            throw new IllegalArgumentException("连接失败：" + safeFailure(e));
        }
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
        return postChat(props.getAi().getBaseUrl(), props.getAi().getModel(), key, systemPrompt, userPrompt, 1500);
    }

    /**
     * Ollama 本地档。Ollama 自带 {@code /v1} OpenAI 兼容端点，协议与 openai 档完全一致，
     * 差别只在 base-url 与 key 用占位符（Ollama 不校验 key，但缺 header 会被部分网关拒）。
     */
    private String callOllama(String systemPrompt, String userPrompt) throws Exception {
        return postChat(props.getAi().getOllamaBaseUrl(), props.getAi().getOllamaModel(),
                null, systemPrompt, userPrompt, 1500);
    }

    /**
     * 统一的 OpenAI 兼容 POST。
     *
     * @param baseUrl 端点根地址，自动补 {@code /v1/chat/completions}
     */
    private String postChat(String baseUrl, String model, String apiKey,
                            String systemPrompt, String userPrompt, int maxTokens) throws Exception {
        return postChat(baseUrl, model, apiKey, systemPrompt, userPrompt, maxTokens, false);
    }

    private String postAccountChat(UserAiConfigService.ModelConfig config, String systemPrompt,
                                   String userPrompt, int maxTokens) throws Exception {
        return postChat(config.baseUrl(), config.model(), config.apiKey(), systemPrompt, userPrompt, maxTokens, true);
    }

    private String postChat(String baseUrl, String model, String apiKey, String systemPrompt, String userPrompt,
                            int maxTokens, boolean accountEndpoint) throws Exception {
        String root = trimTrailingSlash(baseUrl);
        String url = root.endsWith("/chat/completions") ? root
                : root.endsWith("/v1") ? root + "/chat/completions" : root + "/v1/chat/completions";

        String body = JSON.writeValueAsString(Map.of(
                "model", model,
                "messages", List.of(Map.of("role", "system", "content", systemPrompt),
                        Map.of("role", "user", "content", userPrompt)),
                "temperature", 0.4,
                "max_tokens", maxTokens));

        URI target = URI.create(url);
        int timeout = Math.max(1, maxTokens > 1500
                ? Math.max(90_000, props.getAi().getTimeoutMs()) : props.getAi().getTimeoutMs());
        String response = accountEndpoint
                ? sendAccountRequest(target, apiKey, body, timeout)
                : sendSiteRequest(target, apiKey, body, timeout);
        String content = extractContent(JSON.readTree(response));
        if (content.isBlank() || containsCredential(content, apiKey)) {
            throw new IllegalStateException("模型回复不可用");
        }
        return content;
    }

    private String sendSiteRequest(URI target, String apiKey, String body, int timeout) throws Exception {
        HttpRequest req = HttpRequest.newBuilder()
                .uri(target)
                .header("Authorization", "Bearer " + (apiKey == null ? "ollama" : apiKey))
                .header("Content-Type", "application/json")
                .timeout(Duration.ofMillis(timeout))
                .POST(HttpRequest.BodyPublishers.ofString(body))
                .build();

        HttpResponse<String> resp = http.send(req, HttpResponse.BodyHandlers.ofString());
        if (resp.statusCode() != 200) throw new ProviderHttpError(resp.statusCode());
        return resp.body();
    }

    private String sendAccountRequest(URI target, String apiKey, String body, int timeout) throws Exception {
        if (!"https".equalsIgnoreCase(target.getScheme()) || target.getHost() == null
                || target.getRawUserInfo() != null || target.getRawQuery() != null || target.getRawFragment() != null) {
            throw new IllegalArgumentException("模型接口必须使用公开 HTTPS 地址");
        }
        HttpPost request = new HttpPost(target);
        request.setHeader("Authorization", "Bearer " + apiKey);
        request.setEntity(new StringEntity(body, ContentType.APPLICATION_JSON));
        request.setConfig(RequestConfig.custom().setConnectionRequestTimeout(Timeout.ofSeconds(5))
                .setResponseTimeout(Timeout.ofMilliseconds(timeout)).build());
        return accountHttp.execute(request, response -> {
            if (response.getCode() != 200) {
                request.cancel();
                return new AccountResponse(response.getCode(), "");
            }
            if (response.getEntity() == null) return new AccountResponse(200, "");
            try (var stream = response.getEntity().getContent()) {
                int limit = 512 * 1024;
                byte[] bytes = stream.readNBytes(limit + 1);
                if (bytes.length > limit) {
                    request.cancel();
                    throw new java.io.IOException("模型回复过大");
                }
                return new AccountResponse(200, new String(bytes, StandardCharsets.UTF_8));
            }
        }).bodyOrThrow();
    }

    private record AccountResponse(int status, String body) {
        String bodyOrThrow() throws ProviderHttpError {
            if (status != 200) throw new ProviderHttpError(status);
            return body;
        }
    }

    /** Only extract answer text from a recognized completion, never return the response envelope. */
    private String extractContent(JsonNode response) {
        if (response == null || response.hasNonNull("error")) return "";
        JsonNode choice = response.path("choices").path(0);
        JsonNode content = choice.path("message").path("content");
        if (content.isMissingNode()) content = choice.path("delta").path("content");
        if (content.isMissingNode()) content = choice.path("text");
        if (content.isTextual()) return content.textValue();
        if (!content.isArray()) return "";
        StringBuilder text = new StringBuilder();
        for (JsonNode part : content) {
            JsonNode block = part.path("text");
            if (block.isTextual()) text.append(block.textValue());
        }
        return text.toString();
    }

    private boolean containsCredential(String text, String key) {
        return key != null && !key.isBlank() && text.contains(key);
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

    private String safeFailure(Exception error) {
        if (error instanceof ProviderHttpError httpError) return "HTTP " + httpError.status;
        if (error instanceof java.net.http.HttpTimeoutException) return "连接超时";
        if (error instanceof InterruptedException) Thread.currentThread().interrupt();
        return "模型接口不可用，请检查地址、模型和凭据";
    }

    private static final class ProviderHttpError extends Exception {
        private final int status;

        private ProviderHttpError(int status) {
            this.status = status;
        }
    }
}
