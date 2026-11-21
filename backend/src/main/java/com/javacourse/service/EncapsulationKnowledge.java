package com.javacourse.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;

/** Public learning material prepared by 角色一 for the encapsulation topic. */
@Service
public class EncapsulationKnowledge {
    public static final String LESSON_SLUG = "encapsulation-account";
    private static final Pattern OUTSIDE_JAVA = Pattern.compile("\\b(?:python|pem|ssh|openssl|pandas)\\b|\\bprivate\\s+key\\b|私钥", Pattern.CASE_INSENSITIVE);
    private static final Pattern CODE_COMMENTS = Pattern.compile("(?s)/\\*.*?\\*/|//[^\\r\\n]*");
    private static final Pattern TYPE_IMPORT = Pattern.compile("\\bimport\\s+((?:[\\w$]+\\.)+[\\w$]+)\\s*;");
    private final List<Rule> rules;

    public EncapsulationKnowledge(ObjectMapper mapper) throws IOException {
        var file = new ClassPathResource("db/courses/encapsulation/topic-knowledge.json");
        try (var input = file.getInputStream()) {
            List<Entry> entries = mapper.readValue(input, new TypeReference<>() {});
            rules = entries.stream().map(entry -> new Rule(entry.card(), entry.questions(), entry.groups().stream()
                    .map(group -> Pattern.compile(group, Pattern.CASE_INSENSITIVE | Pattern.UNICODE_CHARACTER_CLASS))
                    .toList())).toList();
        }
    }

    public List<Card> cards() {
        return rules.stream().map(Rule::card).toList();
    }

    List<Card> match(String question) {
        if (question == null || question.length() > 2000 || OUTSIDE_JAVA.matcher(question).find()) return List.of();
        String query = normalize(question);
        if (query.isEmpty()) return List.of();
        boolean importCollision = hasImportCollision(question);
        List<Match> matches = new ArrayList<>();
        for (Rule rule : rules) {
            int score = matchScore(rule, query, importCollision);
            if (score > 0) matches.add(new Match(rule.card(), score));
        }
        return matches.stream().sorted(Comparator.comparingInt(Match::score).reversed()
                        .thenComparing(match -> match.card().id()))
                .limit(3).map(Match::card).toList();
    }

    private String normalize(String text) {
        return text.replace("`", "").strip().replaceAll("\\s+", " ");
    }

    private int matchScore(Rule rule, String query, boolean importCollision) {
        if (rule.questions().stream().anyMatch(question -> normalize(question).equalsIgnoreCase(query))) return 100;
        if (importCollision && "PKG-03".equals(rule.card().id())) return 30;
        if (!rule.groups().stream().allMatch(group -> group.matcher(query).find())) return 0;
        return "PKG-02".equals(rule.card().id()) ? 12 : 10;
    }

    private boolean hasImportCollision(String source) {
        var imports = TYPE_IMPORT.matcher(CODE_COMMENTS.matcher(source).replaceAll(""));
        Map<String, String> names = new HashMap<>();
        while (imports.find()) {
            String full = imports.group(1);
            String previous = names.putIfAbsent(full.substring(full.lastIndexOf('.') + 1), full);
            if (previous != null && !previous.equals(full)) return true;
        }
        return false;
    }

    public record Card(String id, String title, String category, String summary, String example, String sourceUrl) {
        String refUrl() {
            return "/lesson/" + LESSON_SLUG + "#topic-knowledge-" + id;
        }
    }

    private record Entry(Card card, List<String> questions, List<String> groups) {}
    private record Rule(Card card, List<String> questions, List<Pattern> groups) {}
    private record Match(Card card, int score) {}
}
