package com.javacourse.controller;

import com.javacourse.model.ApiResponse;
import com.javacourse.repository.CodeRepository;
import com.javacourse.service.CodeJudgeService;
import com.javacourse.service.CodeRunnerService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 代码实验室 / 课后习题接口
 *
 * <p>三条主线：</p>
 * <ul>
 *   <li>{@code POST /code/run} —— 运行任意 Java 源码，返回编译错误 / 运行输出 / 异常栈</li>
 *   <li>{@code POST /code/submit} —— 按习题测试用例判题，落库提交记录</li>
 *   <li>{@code GET /code/exercises} —— 习题列表与详情</li>
 * </ul>
 */
@RestController
public class CodeController {

    private final CodeRunnerService runner;
    private final CodeJudgeService judge;
    private final CodeRepository repo;

    public CodeController(CodeRunnerService runner, CodeJudgeService judge, CodeRepository repo) {
        this.runner = runner;
        this.judge = judge;
        this.repo = repo;
    }

    /**
     * 代码执行环境自检：JDK 是否就绪、限制参数是多少。
     * 前端在练习页加载时调用，就绪才启用「运行」按钮。
     */
    @GetMapping("/code/runtime")
    public ApiResponse<Map<String, Object>> runtime() {
        return ApiResponse.ok(runner.runtimeInfo());
    }

    /**
     * 运行一段 Java 源码（不判题，只看编译与运行结果）。
     * <p>请求体：{@code {"code":"...","stdin":"..."}}。</p>
     */
    @PostMapping("/code/run")
    public ApiResponse<Map<String, Object>> run(@RequestBody Map<String, String> body) {
        String code = body.get("code");
        if (code == null || code.isBlank()) {
            return ApiResponse.error(400, "代码不能为空");
        }
        String stdin = body.get("stdin");
        CodeRunnerService.RunResult r = runner.run(code, stdin == null ? "" : stdin);

        Map<String, Object> m = new LinkedHashMap<>();
        m.put("status", r.status());
        m.put("output", r.output());
        m.put("stdout", r.stdout());
        m.put("stderr", r.stderr());
        m.put("exitCode", r.exitCode());
        m.put("durationMs", r.durationMs());
        m.put("message", r.message());
        m.put("success", r.success());
        return ApiResponse.ok(m);
    }

    /**
     * 提交习题代码并判题。
     * <p>请求体：{@code {"exerciseId":1,"code":"..."}}。</p>
     */
    @PostMapping("/code/submit")
    public ApiResponse<Map<String, Object>> submit(@RequestBody Map<String, String> body,
                                                    HttpServletRequest http) {
        // 兼容两种字段名：前端用 code，脚本/第三方可能用 sourceCode
        String code = body.get("code");
        if (code == null || code.isBlank()) {
            code = body.get("sourceCode");
        }
        if (code == null || code.isBlank()) {
            return ApiResponse.error(400, "代码不能为空");
        }
        String exerciseIdRaw = body.get("exerciseId");
        if (exerciseIdRaw == null || exerciseIdRaw.isBlank()) {
            return ApiResponse.error(400, "缺少 exerciseId");
        }
        long exerciseId;
        try {
            exerciseId = Long.parseLong(exerciseIdRaw.trim());
        } catch (NumberFormatException e) {
            return ApiResponse.error(400, "exerciseId 必须是数字");
        }

        Object uid = http.getAttribute("userId");
        long userId = uid instanceof Long ? (Long) uid : 0L;
        return ApiResponse.ok(judge.judge(userId, exerciseId, code));
    }

    /** 习题列表；带 lessonId 则只看该课时的习题 */
    @GetMapping("/code/exercises")
    public ApiResponse<List<Map<String, Object>>> exercises(
            @RequestParam(required = false) Long lessonId) {
        List<Map<String, Object>> list = repo.listExercises(lessonId);
        // 参考答案不下发给前端（教师视角数据）
        for (Map<String, Object> m : list) {
            m.remove("solutionCode");
        }
        return ApiResponse.ok(list);
    }

    /** 习题详情（同样不含参考答案） */
    @GetMapping("/code/exercises/{slug}")
    public ApiResponse<Map<String, Object>> exercise(@PathVariable String slug) {
        Map<String, Object> ex = repo.findExerciseBySlug(slug);
        if (ex == null) {
            return ApiResponse.error(404, "习题不存在");
        }
        ex.remove("solutionCode");
        return ApiResponse.ok(ex);
    }

    /** 我的提交记录 */
    @GetMapping("/code/submissions")
    public ApiResponse<List<Map<String, Object>>> submissions(
            @RequestParam(required = false) Long exerciseId,
            HttpServletRequest http) {
        Object uid = http.getAttribute("userId");
        long userId = uid instanceof Long ? (Long) uid : 0L;
        return ApiResponse.ok(repo.listSubmissions(userId, exerciseId));
    }
}
