package com.javacourse.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.javacourse.config.AppProperties;
import com.javacourse.repository.CourseRepository;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class EncapsulationKnowledgeTest {
    private final ObjectMapper mapper = new ObjectMapper();
    private final EncapsulationKnowledge knowledge = new EncapsulationKnowledge(mapper);

    EncapsulationKnowledgeTest() throws IOException {}

    @Test
    void checksAllRoleOneQueriesAgainstTheIntegratedRules() throws IOException {
        try (var data = getClass().getResourceAsStream("/encapsulation-search-cases.json")) {
            List<QueryCase> cases = mapper.readValue(data, new TypeReference<>() {});
            assertThat(cases).hasSize(63);
            assertThat(knowledge.cards()).hasSize(12);
            assertThat(cases).allSatisfy(row -> {
                var cards = knowledge.match(row.query());
                assertThat(cards.isEmpty() ? "" : cards.get(0).id())
                        .as("%s · %s", row.group(), row.query()).isEqualTo(row.expected());
            });
        }
    }

    @Test
    void searchAndLocalAssistantLinkToTheSamePreciseCard() {
        var repo = mock(CourseRepository.class);
        var props = new AppProperties();
        when(repo.searchIndex(anyString(), anyList(), anyInt())).thenReturn(List.of(Map.of(
                "id", 1L, "title", "泛型与类型擦除", "body", "类型", "refUrl", "/lesson/generics")));
        var search = new SearchService(repo, props, knowledge);
        var assistant = new AiAssistantService(repo, search, props, mock(ModelGateway.class));
        String query = "类型已经引进来了，但还是拿不到那个字段的值。";
        assertThat(search.search(query).get(0).get("refUrl"))
                .isEqualTo("/lesson/encapsulation-account#topic-knowledge-PKG-02");
        var result = assistant.ask(1L, query, true, null);
        assertThat(result.get("answer").toString()).contains("import 与访问权限", "简单类名");
        assertThat(result.get("citations").toString()).contains("knowledgeId=PKG-02");
        assertThat(search.search("Java 的 import 和 Python 的 import 有什么区别？"))
                .allSatisfy(hit -> assertThat(hit.get("refUrl").toString()).doesNotContain("#topic-knowledge-"));
    }

    private record QueryCase(String query, String expected, String group) {}
}
