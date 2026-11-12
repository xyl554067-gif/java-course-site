package com.javacourse.controller;

import com.javacourse.service.AiAssistantService;
import com.javacourse.service.AssistantRequestLimit;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.util.Map;

import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class AiAssistantControllerTest {
    private final AiAssistantService service = mock(AiAssistantService.class);
    private final AssistantRequestLimit limit = mock(AssistantRequestLimit.class);
    private final JdbcTemplate jdbc = mock(JdbcTemplate.class);
    private final MockMvc mvc = MockMvcBuilders.standaloneSetup(new AiAssistantController(service, limit, jdbc)).build();

    @Test
    void localEndpointUsesTheExplicitLessonAndRejectsRateLimitedRequests() throws Exception {
        when(service.ask(7L, "解释这节课", true, "arrays")).thenReturn(Map.of("answer", "数组示例"));
        when(limit.retryAfter(7L, false)).thenReturn(0, 17);
        var request = post("/ai/ask/local").requestAttr("userId", 7L).contentType("application/json")
                .content("{\"question\":\"解释这节课\",\"lessonSlug\":\"arrays\"}");
        mvc.perform(request).andExpect(status().isOk()).andExpect(jsonPath("$.data.answer").value("数组示例"));
        mvc.perform(request).andExpect(status().isTooManyRequests()).andExpect(header().string("Retry-After", "17"));
        verify(service).ask(7L, "解释这节课", true, "arrays");
    }

    @Test
    void cleanupUsesAuthenticatedOwnerEvenIfAnotherIdIsSupplied() throws Exception {
        String sql = "DELETE FROM ai_chat_session WHERE user_id = ? AND agent_key = 'whale'";
        when(jdbc.update(sql, 7L)).thenReturn(2);
        mvc.perform(delete("/ai/history").requestAttr("userId", 7L).param("userId", "42"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.removed").value(2));
        verify(jdbc).update(sql, 7L);
        verifyNoMoreInteractions(jdbc);
    }
}
