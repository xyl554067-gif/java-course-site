package com.javacourse.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.javacourse.repository.CodeRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 习题判题服务。
 *
 * <h3>判题流程</h3>
 * <ol>
 *   <li>取出习题的测试用例（stdin + 期望输出）</li>
 *   <li>对每个用例调用 {@link CodeRunnerService} 真实编译并运行学生代码</li>
 *   <li>比对标准输出与期望值（忽略行尾空白差异）</li>
 *   <li>汇总为 PASSED / FAILED / COMPILE_ERROR / RUNTIME_ERROR / TIMEOUT</li>
 * </ol>
 *
 * <p>注意：判题<b>不做部分给分</b>——全通过才 PASSED。这与多数 OJ 的「按用例给分」
 * 略有不同，但对教学站点更清晰：学生看到的是「哪一条用例没过、期望什么、实际什么」。</p>
 */
@Service
public class CodeJudgeService {

    private static final Logger log = LoggerFactory.getLogger(CodeJudgeService.class);

    private final CodeRunnerService runner;
    private final CodeRepository repo;
    private final ObjectMapper mapper = new ObjectMapper();

    public CodeJudgeService(CodeRunnerService runner, CodeRepository repo) {
        this.runner = runner;
        this.repo = repo;
    }

    /** 一个测试用例 */
    public record TestCase(String name, String stdin, String expected) {
    }

    /** 单条用例的判题结果 */
    public record CaseResult(String name, boolean passed, String expected, String actual, String note) {
    }

    /**
     * 判题并落库。
     *
     * @param userId     提交者（0 表示匿名）
     * @param exerciseId 习题 id
     * @param sourceCode 学生提交的源码
     */
    public Map<String, Object> judge(long userId, long exerciseId, String sourceCode) {
        Map<String, Object> exercise = repo.findExerciseById(exerciseId);
        if (exercise == null) {
            Map<String, Object> err = new LinkedHashMap<>();
            err.put("status", "NOT_FOUND");
            err.put("message", "习题不存在");
            return err;
        }

        List<TestCase> cases = parseCases(str(exercise.get("testCases"), ""));        if (cases.isEmpty()) {
            cases = List.of(new TestCase("默认用例", "", ""));
        }

        List<CaseResult> results = new ArrayList<>();
        int passed = 0;
        String status = "PASSED";
        String stdout = "";
        String stderr = "";
        String errorOutput = "";
        long totalDuration = 0;

        for (TestCase tc : cases) {
            CodeRunnerService.RunResult r = runner.run(sourceCode, tc.stdin());
            totalDuration += r.durationMs();
            boolean ok;
            String note = null;

            if (!r.success()) {
                ok = false;
                note = r.message();
                errorOutput = r.output() != null && !r.output().isBlank() ? r.output() : r.stderr();
                status = switch (r.status()) {
                    case "TIMEOUT" -> "TIMEOUT";
                    case "COMPILE_ERROR" -> "COMPILE_ERROR";
                    default -> "RUNTIME_ERROR";
                };
            } else {
                String actual = r.stdout() == null ? "" : r.stdout();
                ok = normalize(tc.expected()).equals(normalize(actual));
                if (!ok) {
                    status = "FAILED";
                    note = "输出与期望不一致";
                }
                stdout = actual;
                stderr = r.stderr() == null ? "" : r.stderr();
            }
            if (ok) {
                passed++;
            }
            results.add(new CaseResult(tc.name(), ok, tc.expected(),
                    r.stdout() == null ? "" : r.stdout(), note));
        }

        if (passed == cases.size() && "PASSED".equals(status)) {
            status = "PASSED";
        } else if ("PASSED".equals(status)) {
            status = "FAILED";
        }

        String caseJson = toJson(results);
        try {
            repo.insertSubmission(userId, exerciseId, sourceCode, status, caseJson,
                    stdout, stderr, errorOutput, passed, cases.size(), (int) totalDuration);
        } catch (Exception e) {
            log.warn("[CodeJudge] 提交记录落库失败（不影响判题结果）：{}", e.getMessage());
        }

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("status", status);
        out.put("passedCount", passed);
        out.put("totalCount", cases.size());
        out.put("cases", results);
        out.put("stdout", stdout);
        out.put("stderr", stderr);
        out.put("errorOutput", errorOutput);
        out.put("durationMs", totalDuration);
        out.put("message", statusMessage(status, passed, cases.size()));
        out.put("exerciseTitle", exercise.get("title"));
        return out;
    }

    private String statusMessage(String status, int passed, int total) {
        return switch (status) {
            case "PASSED" -> "全部用例通过，" + total + "/" + total + "，太棒了！";
            case "FAILED" -> "有 " + (total - passed) + " 个用例未通过，检查输出内容";
            case "COMPILE_ERROR" -> "编译失败，请根据编译器报错修改代码";
            case "RUNTIME_ERROR" -> "运行出错，请查看异常堆栈";
            case "TIMEOUT" -> "运行超时，可能存在死循环";
            default -> "判题完成";
        };
    }

    /**
     * 解析测试用例 JSON。
     * <p>格式：{@code [{"name":"用例1","stdin":"...","expected":"..."}]}。
     * 解析失败不抛异常——降级成「单个空期望用例」，保证学生至少能看到程序输出。</p>
     */
    public List<TestCase> parseCases(String json) {
        if (json == null || json.isBlank()) {
            return List.of();
        }
        try {
            List<Map<String, Object>> raw = mapper.readValue(json,
                    new TypeReference<List<Map<String, Object>>>() {
                    });
            List<TestCase> out = new ArrayList<>();
            for (Map<String, Object> m : raw) {
                String name = str(m.get("name"), "用例 " + (out.size() + 1));
                String stdin = str(m.get("stdin"), "");
                String expected = str(m.get("expected"), "");
                out.add(new TestCase(name, stdin, expected));
            }            return out;
        } catch (Exception e) {
            log.warn("[CodeJudge] 测试用例解析失败：{}", e.getMessage());
            return List.of();
        }
    }

    private String str(Object v, String def) {
        return v == null ? def : String.valueOf(v);
    }

    /** 输出比对时忽略行尾空白与末尾空行 */
    private String normalize(String s) {
        if (s == null) {
            return "";
        }
        String[] lines = s.replace("\r\n", "\n").split("\n");
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < lines.length; i++) {
            sb.append(lines[i].stripTrailing());
            if (i < lines.length - 1) {
                sb.append('\n');
            }
        }
        return sb.toString().strip();
    }

    private String toJson(List<CaseResult> results) {
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < results.size(); i++) {
            if (i > 0) {
                sb.append(',');
            }
            CaseResult r = results.get(i);
            sb.append("{\"name\":\"").append(esc(r.name()))
                    .append("\",\"passed\":").append(r.passed())
                    .append(",\"expected\":\"").append(esc(r.expected()))
                    .append("\",\"actual\":\"").append(esc(r.actual()))
                    .append("\",\"note\":\"").append(esc(r.note() == null ? "" : r.note()))
                    .append("\"}");
        }
        return sb.append(']').toString();
    }

    private String esc(String s) {
        if (s == null) {
            return "";
        }
        return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "");
    }
}
