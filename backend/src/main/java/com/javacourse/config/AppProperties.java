package com.javacourse.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 应用级配置
 */
@ConfigurationProperties(prefix = "app")
public class AppProperties {

    private final Jwt jwt = new Jwt();
    private final Ai ai = new Ai();
    private final Search search = new Search();
    private final Code code = new Code();

    public Jwt getJwt() { return jwt; }
    public Ai getAi() { return ai; }
    public Search getSearch() { return search; }
    public Code getCode() { return code; }

    public static class Jwt {
        private String secret = "javacourse-default-secret-key";
        private int expireHours = 12;

        public String getSecret() { return secret; }
        public void setSecret(String secret) { this.secret = secret; }
        public int getExpireHours() { return expireHours; }
        public void setExpireHours(int expireHours) { this.expireHours = expireHours; }
    }

    public static class Ai {
        /**
         * 模型接入方式（决定 {@link #callModel} 的路由策略）：
         * <ul>
         *   <li>{@code openai}：任意 OpenAI 兼容端点（DeepSeek / 通义 / 智谱 / 豆包 / Ollama / vLLM 均可），
         *       按 {@code base-url} + {@code api-key} + {@code model} 发起 {@code POST /v1/chat/completions}</li>
         *   <li>{@code auto}（默认）：按 {@link #fallbackOrder} 依次尝试，首个成功即返回</li>
         *   <li>{@code local}：跳过一切远程调用，直接走课程检索式回答（零延迟、零成本、零依赖）</li>
         * </ul>
         */
        private String provider = "auto";

        /** OpenAI 兼容端点根地址（不含 /v1/chat/completions 后缀） */
        private String baseUrl = "https://api.deepseek.com";

        /** API Key；为空则该档不可用（auto 模式下自动跳过） */
        private String apiKey = "";

        /** Dedicated server secret used to encrypt per-account model credentials at rest. */
        private String userConfigEncryptionKey = "";

        /** 模型名 */
        private String model = "deepseek-v3";

        /**
         * auto 模式下的尝试顺序，逗号分隔，取值 openai | ollama | local。
         * 默认 openai → ollama → local：先打云端（质量最好），本地模型兜底（免费但可能未安装），
         * 最后检索式（永远可用，保证功能不中断）。
         */
        private String fallbackOrder = "openai,ollama,local";

        /** Ollama 本地服务地址 */
        private String ollamaBaseUrl = "http://127.0.0.1:11434";

        /** Ollama 本地模型名（需已 ollama pull） */
        private String ollamaModel = "qwen2.5:7b";

        /** 单次模型调用超时（毫秒） */
        private int timeoutMs = 20000;

        /** 检索课程内容喂给模型的上下文条数 */
        private int contextLimit = 6;

        public String getProvider() { return provider; }
        public void setProvider(String provider) { this.provider = provider; }
        public String getBaseUrl() { return baseUrl; }
        public void setBaseUrl(String baseUrl) { this.baseUrl = baseUrl; }
        public String getApiKey() { return apiKey; }
        public void setApiKey(String apiKey) { this.apiKey = apiKey; }
        public String getUserConfigEncryptionKey() { return userConfigEncryptionKey; }
        public void setUserConfigEncryptionKey(String userConfigEncryptionKey) { this.userConfigEncryptionKey = userConfigEncryptionKey; }
        public String getModel() { return model; }
        public void setModel(String model) { this.model = model; }
        public String getFallbackOrder() { return fallbackOrder; }
        public void setFallbackOrder(String fallbackOrder) { this.fallbackOrder = fallbackOrder; }
        public String getOllamaBaseUrl() { return ollamaBaseUrl; }
        public void setOllamaBaseUrl(String ollamaBaseUrl) { this.ollamaBaseUrl = ollamaBaseUrl; }
        public String getOllamaModel() { return ollamaModel; }
        public void setOllamaModel(String ollamaModel) { this.ollamaModel = ollamaModel; }
        public int getTimeoutMs() { return timeoutMs; }
        public void setTimeoutMs(int timeoutMs) { this.timeoutMs = timeoutMs; }
        public int getContextLimit() { return contextLimit; }
        public void setContextLimit(int contextLimit) { this.contextLimit = contextLimit; }
    }

    public static class Search {
        private int minKeywordLength = 2;

        public int getMinKeywordLength() { return minKeywordLength; }
        public void setMinKeywordLength(int minKeywordLength) { this.minKeywordLength = minKeywordLength; }
    }

    /**
     * Java 代码执行环境配置。
     *
     * <p>对应「代码实验室 / 课后习题」：学生提交的源码会被真实送进 JDK 编译并执行。
     * 各项限制是为了防止一段死循环或无限打印把服务拖垮。</p>
     */
    public static class Code {
        /**
         * JDK 根目录（形如 {@code D:/develop/Java/jdk-21}）。
         * 留空则依次尝试环境变量 {@code CODE_JAVA_HOME}、{@code JAVA_HOME}，最后交给系统 PATH。
         */
        private String javaHome = "";

        /** 单次运行时长上限（毫秒），超时强杀进程树 */
        private int timeoutMs = 10000;

        /** 单次编译时长上限（毫秒） */
        private int compileTimeoutMs = 15000;

        /** 运行期 JVM 堆上限（MB） */
        private int memoryLimitMb = 256;

        /** stdout / stderr 各自的最大字符数 */
        private int maxOutputChars = 20000;

        /** 单次提交源码的最大字符数 */
        private int maxSourceChars = 100000;

        public String getJavaHome() { return javaHome; }
        public void setJavaHome(String javaHome) { this.javaHome = javaHome; }
        public int getTimeoutMs() { return timeoutMs; }
        public void setTimeoutMs(int timeoutMs) { this.timeoutMs = timeoutMs; }
        public int getCompileTimeoutMs() { return compileTimeoutMs; }
        public void setCompileTimeoutMs(int compileTimeoutMs) { this.compileTimeoutMs = compileTimeoutMs; }
        public int getMemoryLimitMb() { return memoryLimitMb; }
        public void setMemoryLimitMb(int memoryLimitMb) { this.memoryLimitMb = memoryLimitMb; }
        public int getMaxOutputChars() { return maxOutputChars; }
        public void setMaxOutputChars(int maxOutputChars) { this.maxOutputChars = maxOutputChars; }
        public int getMaxSourceChars() { return maxSourceChars; }
        public void setMaxSourceChars(int maxSourceChars) { this.maxSourceChars = maxSourceChars; }
    }
}

