package com.javacourse.service;

import com.javacourse.config.AppProperties;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class CodeRunnerServiceTest {
    private final CodeRunnerService runner = new CodeRunnerService(new AppProperties());

    @Test
    void runsAClassOnTheSameLineAsItsImport() {
        String source = """
                import java.util.Scanner; public class Main {
                    public static void main(String[] args) {
                        System.out.println(new Scanner(System.in).nextInt() + 1);
                    }
                }
                """;
        var result = runner.run(source, "41\n");
        assertThat(result.success()).as("%s %s", result.output(), result.stderr()).isTrue();
        assertThat(result.stdout().strip()).isEqualTo("42");
    }

    @Test
    void recognizesClassAfterSeveralImportsOnOneLine() {
        String source = """
                import java.util.*; /* class Wrong */ import static java.lang.Math.max; class AccountCheck {
                    public static void main(String[] args) {
                        System.out.println(max(List.of(100).get(0), 120));
                    }
                }
                """;
        var result = runner.run(source, "");
        assertThat(result.success()).as("%s %s", result.output(), result.stderr()).isTrue();
        assertThat(result.stdout().strip()).isEqualTo("120");
    }

    @Test
    void stillRunsAStatementSnippetAfterAnImport() {
        String source = """
                import java.util.List;
                System.out.println(List.of("class Account").get(0));
                """;
        var result = runner.run(source, "");
        assertThat(result.success()).as("%s %s", result.output(), result.stderr()).isTrue();
        assertThat(result.stdout().strip()).isEqualTo("class Account");
    }

    @Test
    void privateBalanceStillProducesACompilerError() {
        String source = """
                import java.util.Scanner; public class AccountCheck {
                    public static void main(String[] args) {
                        System.out.println(new Account().balance);
                    }
                }

                class Account {
                    private int balance = 100;
                }
                """;
        var result = runner.run(source, "");
        assertThat(result.status()).isEqualTo("COMPILE_ERROR");
        assertThat(result.output()).contains("AccountCheck.java:3:", "balance");
        assertThat(result.stdout()).isEmpty();
    }
}
