package com.javacourse.service;

import com.javacourse.config.AppProperties;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.SocketTimeoutException;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicReference;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class ModelGatewayPrivacyTest {
    private static final String TEST_KEY = "fixture-provider-key-123";

    @Test
    void forwardsOnlyExpectedMessagesAndReadsOnlyRecognizedAnswer() throws IOException {
        HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        AtomicReference<String> reply = new AtomicReference<>();
        AtomicReference<String> sentBody = new AtomicReference<>();
        AtomicReference<String> sentAuthorization = new AtomicReference<>();
        server.createContext("/v1/chat/completions", exchange -> {
            sentBody.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            sentAuthorization.set(exchange.getRequestHeaders().getFirst("Authorization"));
            int status = reply.get().startsWith("{\"error\"") ? 401 : 200;
            byte[] bytes = reply.get().getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(status, bytes.length);
            try (var output = exchange.getResponseBody()) {
                output.write(bytes);
            }
        });
        server.start();
        try {
            UserAiConfigService configs = mock(UserAiConfigService.class);
            AppProperties properties = new AppProperties();
            properties.getAi().setProvider("openai");
            properties.getAi().setBaseUrl("http://127.0.0.1:" + server.getAddress().getPort());
            properties.getAi().setApiKey(TEST_KEY);
            ModelGateway gateway = new ModelGateway(properties, configs);

            reply.set("""
                    {"metadata":{"content":"private envelope"},"choices":[{"message":{"content":"Java hint"}}]}
                    """.strip());
            assertEquals("Java hint", call(gateway).answer());
            assertEquals("Bearer " + TEST_KEY, sentAuthorization.get());
            assertTrue(sentBody.get().contains("Java question"));
            assertFalse(sentBody.get().contains(TEST_KEY));
            assertFalse(sentBody.get().contains("73"));

            reply.set("{\"choices\":[{\"message\":{\"content\":\"" + TEST_KEY + "\"}}]}");
            assertEquals("local answer", call(gateway).answer());

            reply.set("{\"metadata\":{\"content\":\"private envelope\"}}");
            assertEquals("local answer", call(gateway).answer());

            reply.set("{\"error\":{\"message\":\"" + TEST_KEY + "\"}}");
            ModelGateway.Result failure = call(gateway);
            assertEquals("local answer", failure.answer());
            assertTrue(failure.detail().contains("HTTP 401"));
            assertFalse(failure.detail().contains(TEST_KEY));

            when(configs.get(73L)).thenReturn(new UserAiConfigService.ModelConfig(
                    "https://1.1.1.1", "fixture", TEST_KEY));
            ModelGateway.Result blocked = gateway.call(73L, "Java tutor", TEST_KEY, TEST_KEY, List.of(),
                    (question, context) -> "local answer");
            assertEquals(AssistantPolicy.INPUT_BLOCKED, blocked.answer());
            gateway.closeAccountClient();
        } finally {
            server.stop(0);
        }
    }

    @Test
    void accountHttpClientRefusesPrivateDnsAtConnectTime() throws IOException {
        try (ServerSocket listener = new ServerSocket()) {
            listener.bind(new InetSocketAddress("127.0.0.1", 0));
            listener.setSoTimeout(300);
            UserAiConfigService configs = mock(UserAiConfigService.class);
            String url = "https://localhost:" + listener.getLocalPort();
            when(configs.get(73L)).thenReturn(new UserAiConfigService.ModelConfig(url, "fixture", TEST_KEY));
            AppProperties props = new AppProperties();
            props.getAi().setTimeoutMs(750);
            ModelGateway gateway = new ModelGateway(props, configs);
            try {
                assertEquals("local answer", call(gateway).answer());
                assertThrows(SocketTimeoutException.class, listener::accept);
            } finally {
                gateway.closeAccountClient();
            }
        }
    }

    @Test
    void refusesToReuseSavedCredentialsAtAnotherEndpoint() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.query(anyString(), org.mockito.ArgumentMatchers.<RowMapper<Map.Entry<String, String>>>any(), eq(73L)))
                .thenReturn(List.of(Map.entry("https://1.1.1.1/v1", "fixture-not-decrypted")));
        UserAiConfigService configs = new UserAiConfigService(jdbc, "");
        String changedEndpoint = "https://8.8.8.8/v1";
        assertThrows(IllegalArgumentException.class, () -> configs.proposed(changedEndpoint, "fixture", "", 73L));
        assertThrows(IllegalArgumentException.class, () -> configs.save(73L, changedEndpoint, "fixture", ""));
        assertEquals(TEST_KEY, configs.proposed(changedEndpoint, "fixture", TEST_KEY, 73L).apiKey());
    }

    @Test
    void refusesPrivateProviderAddressesAndDoesNotEchoMalformedUrls() {
        UserAiConfigService configs = new UserAiConfigService(mock(JdbcTemplate.class), "");
        for (String url : List.of("https://127.0.0.1", "https://100.64.0.1", "https://[fd00::1]")) {
            assertThrows(IllegalArgumentException.class, () -> configs.validateBaseUrl(url), url);
        }
        var error = assertThrows(IllegalArgumentException.class,
                () -> configs.validateBaseUrl("https://example.org/path " + TEST_KEY));
        assertFalse(error.getMessage().contains(TEST_KEY));
    }

    private ModelGateway.Result call(ModelGateway gateway) {
        return gateway.call(73L, "Java tutor", "Java question", "Java question", List.of(),
                (question, context) -> "local answer");
    }
}
