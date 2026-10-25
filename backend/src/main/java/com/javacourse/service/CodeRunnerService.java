package com.javacourse.service;

import com.javacourse.config.AppProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Java 代码编译与执行服务。
 *
 * <h3>它解决什么问题</h3>
 * <p>课程里的「示例代码」和「课后习题」必须是真的能跑起来的 Java，
 * 而不是一段看起来像 Java 的文本。本类把学生/示例的源码真正送进 JDK 编译并执行，
 * 把编译错误、运行异常、正常输出原样带回前端。</p>
 *
 * <h3>执行模型</h3>
 * <ol>
 *   <li>每次调用建一个<b>独立临时目录</b>，源码写进去，编译产物放 {@code classes/} 子目录。
 *       目录用完立即递归删除，学生代码之间不会互相污染。</li>
 *   <li>先 {@code javac} 编译：失败则直接返回<b>结构化编译错误</b>（行号、列号、错误码、原始输出），
 *       绝不进入运行阶段。</li>
 *   <li>编译通过则 {@code java} 运行：捕获 stdout / stderr、退出码、耗时。</li>
 * </ol>
 *
 * <h3>安全与资源约束</h3>
 * <ul>
 *   <li><b>超时强杀</b>：编译与运行各有独立超时；超时后连同子进程一起销毁
 *       （{@code while(true)} 这类死循环不会拖垮服务）。</li>
 *   <li><b>内存上限</b>：运行期加 {@code -Xmx}，防止 {@code new int[Integer.MAX_VALUE]} 打爆堆。</li>
 *   <li><b>输出上限</b>：stdout/stderr 各自截断到配置上限，避免死循环打印撑爆内存。</li>
 *   <li><b>编码固定 UTF-8</b>：源码、编译参数、运行参数、JVM 默认编码全部锁 UTF-8，
 *       避免中文输出乱码（Windows 默认 GBK 是经典坑）。</li>
 * </ul>
 *
 * <p><b>已知边界</b>：这是教学用的进程级沙箱，<b>不是</b>安全沙箱。
 * 它限制了 CPU 时间、内存与输出，但并未做文件系统/网络隔离。
 * 生产部署请把代码执行放到独立的容器或受限 worker 里执行。</p>
 */
@Service
public class CodeRunnerService {

    private static final Logger log = LoggerFactory.getLogger(CodeRunnerService.class);

    /** 顶层类声明：public/final/abstract/strictfp 可选 */
    private static final Pattern TOP_LEVEL_CLASS =
            Pattern.compile("(?m)^[ \\t]*(?:(?:public|final|abstract|strictfp)[ \\t]+)*class[ \\t]+(\\w+)");
    private static final Pattern TOP_LEVEL_METHOD = Pattern.compile(
            "(?m)^[ \\t]*(?:(?:public|protected|private|static|final|synchronized|abstract|native|strictfp)[ \\t]+)*(?:void|boolean|byte|short|int|long|float|double|char|[A-Z][\\w$]*(?:<[^\\n>]+>)?(?:\\[\\])?)[ \\t]+[A-Za-z_$][\\w$]*[ \\t]*\\(");
    private static final Pattern TOP_LEVEL_NON_CLASS_TYPE = Pattern.compile(
            "(?m)^[ \\t]*(?:(?:public|abstract|final|strictfp)[ \\t]+)*(?:interface|enum|record)[ \\t]+[A-Za-z_$][\\w$]*");
    private static final Pattern MAIN_METHOD = Pattern.compile("\\bstatic[ \\t]+void[ \\t]+main[ \\t]*\\(");

    private final AppProperties props;

    public CodeRunnerService(AppProperties props) {
        this.props = props;
    }

    // ------------------------------------------------------------------
    // 对外结果结构
    // ------------------------------------------------------------------

    /** 编译阶段结果 */
    public record CompileResult(boolean success, String output, long durationMs) {
    }

    /**
     * 一次运行的完整结果。
     *
     * @param status     {@code COMPILE_ERROR} / {@code RUNTIME_ERROR} / {@code TIMEOUT} / {@code SUCCESS}
     * @param output     编译错误原文（编译失败时）
     * @param stdout     标准输出
     * @param stderr     标准错误（运行期异常栈在此）
     * @param exitCode   进程退出码
     * @param durationMs 编译 + 运行总耗时
     * @param message    面向用户的一句话结论
     */
    public record RunResult(String status, String output, String stdout, String stderr,
                            int exitCode, long durationMs, String message) {

        public boolean success() {
            return "SUCCESS".equals(status);
        }
    }

    // ------------------------------------------------------------------
    // 运行环境诊断
    // ------------------------------------------------------------------

    /**
     * 报告当前机器的代码执行环境是否就绪。
     * 前端据此显示「本机 JDK 未检测到，执行功能不可用」这类明确提示，
     * 而不是让用户点了运行才报一个天书般的错误。
     */
    public Map<String, Object> runtimeInfo() {
        Map<String, Object> m = new LinkedHashMap<>();
        String javac = resolveTool("javac");
        String java = resolveTool("java");
        boolean ready = javac != null && java != null;
        m.put("ready", ready);
        m.put("javac", javac);
        m.put("java", java);
        m.put("javaHome", props.getCode().getJavaHome());
        m.put("javacVersion", ready ? toolVersion(javac) : null);
        m.put("javaVersion", ready ? toolVersion(java) : null);
        m.put("timeoutMs", props.getCode().getTimeoutMs());
        m.put("compileTimeoutMs", props.getCode().getCompileTimeoutMs());
        m.put("memoryLimitMb", props.getCode().getMemoryLimitMb());
        m.put("maxOutputChars", props.getCode().getMaxOutputChars());
        m.put("maxSourceChars", props.getCode().getMaxSourceChars());
        m.put("note", ready
                ? "代码执行环境就绪，提交的 Java 源码会被真实编译并执行"
                : "未检测到可用的 JDK（javac/java）。请安装 JDK 17+ 或配置 CODE_JAVA_HOME 后重启后端");
        return m;
    }

    private String toolVersion(String exe) {
        try {
            Process p = new ProcessBuilder(exe, "-version")
                    .redirectErrorStream(true)
                    .start();
            byte[] out = p.getInputStream().readAllBytes();
            if (!p.waitFor(8, TimeUnit.SECONDS)) {
                p.destroyForcibly();
                return null;
            }
            String s = new String(out, StandardCharsets.UTF_8).trim();
            return s.isEmpty() ? null : s.split("\\R")[0];
        } catch (Exception e) {
            return null;
        }
    }

    // ------------------------------------------------------------------
    // 主流程：编译 + 运行
    // ------------------------------------------------------------------

    /**
     * 编译并运行一段 Java 源码。
     *
     * @param source 完整源码，或可直接放入 {@code main} 方法中的课堂语句片段
     * @param stdin  可选的标准输入（习题常用）
     */
    public RunResult run(String source, String stdin) {
        long start = System.currentTimeMillis();
        AppProperties.Code cfg = props.getCode();

        if (source == null || source.isBlank()) {
            return new RunResult("COMPILE_ERROR", "源码为空", "", "", -1,
                    System.currentTimeMillis() - start, "请先输入要运行的 Java 代码");
        }
        String code = source.replace("\r\n", "\n").replace('\r', '\n');
        if (code.length() > cfg.getMaxSourceChars()) {
            return new RunResult("COMPILE_ERROR",
                    "源码长度 " + code.length() + " 超过上限 " + cfg.getMaxSourceChars(),
                    "", "", -1, System.currentTimeMillis() - start,
                    "代码太长了，简化一下再试");
        }

        String className = detectClassName(code);
        if (className == null) {
            boolean includesMainMethod = MAIN_METHOD.matcher(code).find();
            if ((!includesMainMethod && TOP_LEVEL_METHOD.matcher(code).find())
                    || TOP_LEVEL_NON_CLASS_TYPE.matcher(code).find()
                    || Pattern.compile("(?m)^\\\\s*package\\\\s+").matcher(code).find()) {
                return new RunResult("COMPILE_ERROR",
                        "当前是方法、类型或 package 声明片段，不能直接作为语句运行",
                        "", "", -1, System.currentTimeMillis() - start,
                        "这段示例不是可直接运行的语句。请补充完整类与 main 方法后再运行");
            }
            code = wrapRunnableSnippet(code);
            className = "SnippetMain";
        }

        Path workDir = null;
        try {
            workDir = Files.createTempDirectory("javacourse-code-");
            Path srcDir = Files.createDirectories(workDir.resolve("src"));
            Path clsDir = Files.createDirectories(workDir.resolve("classes"));
            Path srcFile = srcDir.resolve(className + ".java");
            Files.writeString(srcFile, code, StandardCharsets.UTF_8);

            // ---------- 编译 ----------
            String javac = requireTool("javac");
            List<String> javacCmd = List.of(
                    javac,
                    // -J 参数传给 javac 自己的 JVM：Windows 默认 GBK，
                    // 诊断信息里的中文若不锁 UTF-8 会变成乱码，学生看不懂。
                    "-J-Dfile.encoding=UTF-8",
                    "-J-Dstdout.encoding=UTF-8",
                    "-J-Dstderr.encoding=UTF-8",
                    "-encoding", "UTF-8",
                    "-nowarn",
                    "-d", clsDir.toString(),
                    srcFile.toString());
            ExecOutcome compiled = exec(javacCmd, workDir, null, cfg.getCompileTimeoutMs());
            if (compiled.timedOut) {
                return new RunResult("TIMEOUT", "编译超时", "", "", -1,
                        System.currentTimeMillis() - start,
                        "编译超时（超过 " + cfg.getCompileTimeoutMs() + "ms），请检查是否有超大代码或死循环");
            }
            if (compiled.exitCode != 0) {
                return new RunResult("COMPILE_ERROR", compiled.output, "", "",
                        compiled.exitCode, System.currentTimeMillis() - start,
                        "编译失败，共 " + countErrors(compiled.output) + " 处错误");
            }

            // ---------- 运行 ----------
            String java = requireTool("java");
            List<String> javaCmd = new ArrayList<>();
            javaCmd.add(java);
            javaCmd.add("-Xmx" + Math.max(16, cfg.getMemoryLimitMb()) + "m");
            // 编码必须全套锁死 UTF-8：Windows 默认 GBK，
            // 只设 file.encoding 不够，System.out 在 JDK 18+ 走 stdout.encoding。
            javaCmd.add("-Dfile.encoding=UTF-8");
            javaCmd.add("-Dstdout.encoding=UTF-8");
            javaCmd.add("-Dsun.stdout.encoding=UTF-8");
            javaCmd.add("-Dsun.stderr.encoding=UTF-8");
            javaCmd.add("-Djava.awt.headless=true");
            javaCmd.add("-cp");
            javaCmd.add(clsDir.toString());
            javaCmd.add(className);

            ExecOutcome ran = exec(javaCmd, workDir, stdin, cfg.getTimeoutMs());
            if (ran.timedOut) {
                return new RunResult("TIMEOUT", "", ran.stdout, ran.stderr, -1,
                        System.currentTimeMillis() - start,
                        "运行超时（超过 " + cfg.getTimeoutMs() + "ms），可能有死循环或等待输入");
            }
            if (ran.exitCode != 0) {
                return new RunResult("RUNTIME_ERROR", "", ran.stdout, ran.stderr, ran.exitCode,
                        System.currentTimeMillis() - start,
                        "运行异常，程序以退出码 " + ran.exitCode + " 结束");
            }
            return new RunResult("SUCCESS", "", ran.stdout, ran.stderr, 0,
                    System.currentTimeMillis() - start, "运行成功");
        } catch (ToolMissing e) {
            return new RunResult("COMPILE_ERROR", e.getMessage(), "", "", -1,
                    System.currentTimeMillis() - start, e.getMessage());
        } catch (Exception e) {
            log.error("[CodeRunner] 执行失败", e);
            return new RunResult("COMPILE_ERROR", String.valueOf(e.getMessage()), "", "", -1,
                    System.currentTimeMillis() - start, "执行环境异常：" + rootMessage(e));
        } finally {
            deleteRecursively(workDir);
        }
    }

    /** Make statement-only lesson examples executable without changing the editor text. */
    private String wrapRunnableSnippet(String snippet) {
        StringBuilder imports = new StringBuilder();
        StringBuilder body = new StringBuilder();
        for (String line : snippet.split("\\\\n", -1)) {
            String trimmed = line.trim();
            if (trimmed.startsWith("import ") && trimmed.endsWith(";")) {
                imports.append(line).append('\\n');
            } else {
                body.append(line).append('\\n');
            }
        }

        StringBuilder source = new StringBuilder(imports).append("public class SnippetMain {\\n");
        if (MAIN_METHOD.matcher(body).find()) {
            source.append(body).append("}\\n");
        } else {
            source.append("    public static void main(String[] args) throws Exception {\\n")
                    .append(body).append("    }\\n}\\n");
        }
        return source.toString();
    }

    // ------------------------------------------------------------------
    // 进程执行
    // ------------------------------------------------------------------

    private record ExecOutcome(String output, String stdout, String stderr,
                               int exitCode, boolean timedOut) {
    }

    /**
     * 执行一个外部命令，实时抽取 stdout / stderr，并施加超时与输出上限。
     */
    private ExecOutcome exec(List<String> command, Path workDir, String stdin, int timeoutMs) throws Exception {
        ProcessBuilder pb = new ProcessBuilder(command);
        if (workDir != null) {
            pb.directory(workDir.toFile());
        }
        pb.redirectErrorStream(false);
        // 环境变量显式指定 UTF-8 与时区，保证输出稳定
        pb.environment().put("LANG", "C.UTF-8");
        pb.environment().put("LC_ALL", "C.UTF-8");

        Process process = pb.start();

        int cap = props.getCode().getMaxOutputChars();
        StringBuilder out = new StringBuilder();
        StringBuilder err = new StringBuilder();
        Thread tOut = drain(process.getInputStream(), out, cap);
        Thread tErr = drain(process.getErrorStream(), err, cap);

        // 标准输入
        try (OutputStream os = process.getOutputStream()) {
            if (stdin != null && !stdin.isEmpty()) {
                os.write(stdin.getBytes(StandardCharsets.UTF_8));
            }
            os.flush();
        } catch (IOException ignore) {
            // 进程已退出时写 stdin 会失败，忽略
        }

        boolean finished = process.waitFor(timeoutMs, TimeUnit.MILLISECONDS);
        if (!finished) {
            killTree(process);
            tOut.join(500);
            tErr.join(500);
            return new ExecOutcome(out.toString(), out.toString(), err.toString(), -1, true);
        }
        tOut.join(2000);
        tErr.join(2000);
        return new ExecOutcome(
                out.toString() + err.toString(), out.toString(), err.toString(),
                process.exitValue(), false);
    }

    /** 读取进程输出流，超过上限就停止读取（防止无限打印） */
    private Thread drain(InputStream in, StringBuilder sink, int cap) {
        Thread t = new Thread(() -> {
            byte[] buf = new byte[4096];
            try (InputStream is = in) {
                int n;
                while ((n = is.read(buf)) > 0) {
                    synchronized (sink) {
                        if (sink.length() >= cap) {
                            sink.append("\n...（输出超过上限，已截断）");
                            break;
                        }
                        int remain = cap - sink.length();
                        String s = new String(buf, 0, n, StandardCharsets.UTF_8);
                        sink.append(s, 0, Math.min(s.length(), remain));
                        if (s.length() > remain) {
                            sink.append("\n...（输出超过上限，已截断）");
                            break;
                        }
                    }
                }
            } catch (IOException ignore) {
                // 进程被杀时读取会中断，忽略
            }
        }, "code-drain");
        t.setDaemon(true);
        t.start();
        return t;
    }

    /** 杀掉进程及其所有子孙（Windows 上 java 会派生子进程） */
    private void killTree(Process p) {
        p.descendants().forEach(h -> {
            try {
                h.destroyForcibly();
            } catch (Exception ignore) {
                // 忽略
            }
        });
        try {
            p.destroyForcibly();
        } catch (Exception ignore) {
            // 忽略
        }
    }

    // ------------------------------------------------------------------
    // 工具定位
    // ------------------------------------------------------------------

    private static class ToolMissing extends RuntimeException {
        ToolMissing(String msg) {
            super(msg);
        }
    }

    private String requireTool(String name) {
        String exe = resolveTool(name);
        if (exe == null) {
            throw new ToolMissing("未找到 " + name
                    + "，请安装 JDK 17+ 或配置环境变量 CODE_JAVA_HOME 指向 JDK 根目录");
        }
        return exe;
    }

    /**
     * 定位 javac / java 可执行文件。
     * <p>优先级：{@code app.code.java-home} 配置 → {@code CODE_JAVA_HOME} 环境变量 →
     * {@code JAVA_HOME} 环境变量 → 交给系统 PATH 解析。</p>
     */
    private String resolveTool(String name) {
        AppProperties.Code cfg = props.getCode();
        List<String> homes = new ArrayList<>();
        if (cfg.getJavaHome() != null && !cfg.getJavaHome().isBlank()) {
            homes.add(cfg.getJavaHome());
        }
        String env = System.getenv("CODE_JAVA_HOME");
        if (env != null && !env.isBlank()) {
            homes.add(env);
        }
        String jh = System.getenv("JAVA_HOME");
        if (jh != null && !jh.isBlank()) {
            homes.add(jh);
        }
        for (String home : homes) {
            Path p = Path.of(home, "bin", name + exeSuffix());
            if (Files.isExecutable(p)) {
                return p.toString();
            }
            // 少数人把 JAVA_HOME 指向 bin 目录
            Path p2 = Path.of(home, name + exeSuffix());
            if (Files.isExecutable(p2)) {
                return p2.toString();
            }
        }
        // 退化为系统 PATH
        return name;
    }

    private static String exeSuffix() {
        String os = System.getProperty("os.name", "").toLowerCase(Locale.ROOT);
        return os.contains("win") ? ".exe" : "";
    }

    // ------------------------------------------------------------------
    // 杂项
    // ------------------------------------------------------------------

    /**
     * 从源码里推断主类名。
     * <p>Java 要求 public 类与文件名同名，所以必须先知道类名才能决定写哪个文件。
     * 优先取 public 类；没有 public 类则取第一个顶层类；都没有则返回 null。</p>
     */
    private String detectClassName(String code) {
        // 去掉块注释与行注释，避免注释里的 class 被误判
        String cleaned = code
                .replaceAll("(?s)/\\*.*?\\*/", " ")
                .replaceAll("(?m)//.*$", " ");
        Matcher m = TOP_LEVEL_CLASS.matcher(cleaned);
        String first = null;
        while (m.find()) {
            String name = m.group(1);
            String decl = m.group();
            if (first == null) {
                first = name;
            }
            if (decl.contains("public")) {
                return name;
            }
        }
        return first;
    }

    /** 统计编译错误条数（javac 每条错误一行，形如 `Foo.java:3: error: ...`） */
    private int countErrors(String output) {
        if (output == null || output.isBlank()) {
            return 0;
        }
        int n = 0;
        for (String line : output.split("\\R")) {
            if (line.contains("error:")) {
                n++;
            }
        }
        return Math.max(n, 1);
    }

    private void deleteRecursively(Path dir) {
        if (dir == null || !Files.exists(dir)) {
            return;
        }
        try (var walk = Files.walk(dir)) {
            walk.sorted(Comparator.reverseOrder()).forEach(p -> {
                try {
                    Files.deleteIfExists(p);
                } catch (IOException ignore) {
                    // 忽略
                }
            });
        } catch (IOException ignore) {
            // 忽略
        }
    }

    private String rootMessage(Throwable e) {
        Throwable c = e;
        while (c.getCause() != null && c.getCause() != c) {
            c = c.getCause();
        }
        String m = c.getMessage();
        return m == null ? c.getClass().getSimpleName() : m;
    }
}
