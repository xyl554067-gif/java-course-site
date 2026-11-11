package com.javacourse.service;

import java.util.List;
import java.util.regex.Pattern;

/** Replaces recognizable identifiers in the extracted text before it leaves the import flow. */
final class ImportRedaction {
    private record Rule(Pattern pattern, String replacement) {}
    record Result(String text, int matches) {}

    private static final List<Rule> RULES = List.of(
            rule("(?is)-----BEGIN [A-Z ]{0,40}PRIVATE KEY-----.*?(?:-----END [A-Z ]{0,40}PRIVATE KEY-----|\\z)", "[私钥]"),
            rule("(?i)(\\b(?:api[_ -]?key|access[_ -]?token|client[_ -]?secret|password)\\b|密钥|密码)([\"']?\\h*[:=]\\h*)"
                    + "(?:\"[^\"\\r\\n]*\"|'[^'\\r\\n]*'|[^\\s,;，；)<>]+)", "$1$2[凭据]"),
            rule("(?i)\\bBearer\\h+[A-Za-z0-9._~+/=-]{8,}", "Bearer [令牌]"),
            rule("(?i)(?<![\\w-])(?:sk-[A-Za-z0-9_-]{16,}|gh[pousr]_[A-Za-z0-9]{16,}|github_pat_[A-Za-z0-9_]{16,}|AKIA[A-Z0-9]{16})(?![\\w-])", "[密钥]"),
            rule("(?i)[A-Z0-9.!#$%&'*+/=?^_{}|~-]+@[A-Z0-9-]+(?:\\.[A-Z0-9-]+)+", "[邮箱]"),
            rule("(?<![0-9])[1-9][0-9]{5}[0-9]{4}(?:0[1-9]|1[0-2])(?:0[1-9]|[12][0-9]|3[01])[0-9]{3}[0-9Xx](?![0-9])", "[证件号]"),
            rule("(?<![0-9])(?:(?:\\+?86)[\\h-]?)?1[3-9][0-9](?:[\\h-]?[0-9]){8}(?![0-9])", "[手机号]")
    );

    private ImportRedaction() {}

    static Result redact(String text) {
        int matches = 0;
        for (Rule rule : RULES) {
            var matcher = rule.pattern().matcher(text);
            StringBuilder output = new StringBuilder();
            while (matcher.find()) {
                matches++;
                matcher.appendReplacement(output, rule.replacement());
            }
            text = matcher.appendTail(output).toString();
        }
        return new Result(text, matches);
    }

    private static Rule rule(String pattern, String replacement) {
        return new Rule(Pattern.compile(pattern), replacement);
    }
}
