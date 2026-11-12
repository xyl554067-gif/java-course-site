package com.javacourse.service;

import com.javacourse.config.AppProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.util.Collections;
import java.util.HexFormat;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

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

    private static final int MAX_CACHED_PROJECTS = 48;
    private static final int MAX_CACHED_PROJECT_BYTES = 256 * 1024;
    private static final int MAX_CACHED_PROJECT_FILES = 64;
    private static final boolean FAST_COMPILER = Boolean.getBoolean("javacourse.fastCompiler");
    private static final boolean DEFAULT_CLASSPATH = System.getenv("CLASSPATH") == null
            || System.getenv("CLASSPATH").isBlank() || System.getenv("CLASSPATH").equals(".");

    private record CompilationKey(String javac, String sourceHash) {}

    private final AppProperties props;
    private final Map<CompilationKey, Map<Path, byte[]>> compiledProjects = Collections.synchronizedMap(
            new LinkedHashMap<>(MAX_CACHED_PROJECTS, 0.75f, true) {
                @Override
                protected boolean removeEldestEntry(Map.Entry<CompilationKey, Map<Path, byte[]>> eldest) {
                    return size() > MAX_CACHED_PROJECTS;
                }
            });

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
                            int exitCode, long durationMs, String message,
                            Long compileMs, Long executionMs, boolean reusedCompilation) {

        public RunResult(String status, String output, String stdout, String stderr,
                         int exitCode, long durationMs, String message) {
            this(status, output, stdout, stderr, exitCode, durationMs, message, null, null, false);
        }

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
                    || Pattern.compile("(?m)^\\s*package\\s+").matcher(code).find()) {
                return new RunResult("COMPILE_ERROR",
                        "当前是方法、类型或 package 声明片段，不能直接作为语句运行",
                        "", "", -1, System.currentTimeMillis() - start,
                        "这段示例不是可直接运行的语句。请补充完整类与 main 方法后再运行");
            }
            code = wrapRunnableSnippet(code);
            className = "SnippetMain";
        }

        Path workDir = null;
        Long compileMs = null;
        Long executionMs = null;
        boolean reusedCompilation = false;
        try {
            workDir = Files.createTempDirectory("javacourse-code-");
            Path srcDir = Files.createDirectories(workDir.resolve("src"));
            Path clsDir = Files.createDirectories(workDir.resolve("classes"));
            Path srcFile = srcDir.resolve(className + ".java");
            Files.writeString(srcFile, code, StandardCharsets.UTF_8);

            // Keep cached bytecode in memory and copy it into a fresh execution directory.
            String javac = requireTool("javac");
            String hash = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(code.getBytes(StandardCharsets.UTF_8)));
            var key = new CompilationKey(javac, hash);
            Map<Path, byte[]> cached = DEFAULT_CLASSPATH ? compiledProjects.get(key) : null;
            if (cached != null) {
                for (var file : cached.entrySet()) {
                    Path target = clsDir.resolve(file.getKey());
                    Files.createDirectories(target.getParent());
                    Files.write(target, file.getValue());
                }
                reusedCompilation = true;
            } else {
                List<String> javacCmd = new ArrayList<>();
                javacCmd.add(javac);
                if (FAST_COMPILER) {
                    javacCmd.addAll(List.of("-J-XX:TieredStopAtLevel=1", "-J-XX:+UseSerialGC"));
                }
                javacCmd.addAll(List.of(
                        "-J-Dfile.encoding=UTF-8", "-J-Dstdout.encoding=UTF-8", "-J-Dstderr.encoding=UTF-8",
                        "-encoding", "UTF-8", "-proc:none", "-g:none", "-nowarn",
                        "-d", clsDir.toString(), srcFile.toString()));
                long compileStart = System.nanoTime();
                ExecOutcome compiled = exec(javacCmd, workDir, null, cfg.getCompileTimeoutMs());
                compileMs = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - compileStart);
                if (compiled.timedOut) {
                    return new RunResult("TIMEOUT", "编译超时", "", "", -1, System.currentTimeMillis() - start,
                            "编译超时（超过 " + cfg.getCompileTimeoutMs() + "ms），请检查是否有超大代码或死循环",
                            compileMs, null, false);
                }
                if (compiled.exitCode != 0) {
                    return new RunResult("COMPILE_ERROR", compiled.output, "", "", compiled.exitCode,
                            System.currentTimeMillis() - start, "编译失败，共 " + countErrors(compiled.output) + " 处错误",
                            compileMs, null, false);
                }
                if (DEFAULT_CLASSPATH) cacheCompiledProject(key, clsDir);
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

            long executionStart = System.nanoTime();
            ExecOutcome ran = exec(javaCmd, workDir, stdin, cfg.getTimeoutMs());
            executionMs = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - executionStart);
            if (ran.timedOut) {
                return new RunResult("TIMEOUT", "", ran.stdout, ran.stderr, -1,
                        System.currentTimeMillis() - start,
                        "运行超时（超过 " + cfg.getTimeoutMs() + "ms），可能有死循环或等待输入",
                        compileMs, executionMs, reusedCompilation);
            }
            if (ran.exitCode != 0) {
                return new RunResult("RUNTIME_ERROR", "", ran.stdout, ran.stderr, ran.exitCode,
                        System.currentTimeMillis() - start,
                        "运行异常，程序以退出码 " + ran.exitCode + " 结束",
                        compileMs, executionMs, reusedCompilation);
            }
            return new RunResult("SUCCESS", "", ran.stdout, ran.stderr, 0,
                    System.currentTimeMillis() - start, "运行成功", compileMs, executionMs, reusedCompilation);
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

    private void cacheCompiledProject(CompilationKey key, Path classes) {
        try (var stream = Files.walk(classes)) {
            var files = stream.filter(file -> Files.isRegularFile(file, LinkOption.NOFOLLOW_LINKS))
                    .filter(file -> file.getFileName().toString().endsWith(".class"))
                    .limit(MAX_CACHED_PROJECT_FILES + 1L)
                    .toList();
            if (files.isEmpty() || files.size() > MAX_CACHED_PROJECT_FILES) return;

            Map<Path, byte[]> entries = new LinkedHashMap<>();
            int remaining = MAX_CACHED_PROJECT_BYTES;
            for (Path file : files) {
                try (var input = Files.newInputStream(file)) {
                    byte[] bytes = input.readNBytes(remaining + 1);
                    if (bytes.length > remaining) return;
                    entries.put(classes.relativize(file), bytes);
                    remaining -= bytes.length;
                }
            }
            compiledProjects.put(key, Map.copyOf(entries));
        } catch (IOException e) {
            log.debug("[CodeRunner] 编译结果未缓存", e);
        }
    }

    private static final String JAVA_IDENTIFIER = "[\\p{javaJavaIdentifierStart}][\\p{javaJavaIdentifierPart}]*";
    private static final Pattern EXPORT_TYPE = Pattern.compile(
            "(?m)^\\h*(?:(public)\\h+)?(?:(?:abstract|final|sealed|non-sealed|strictfp)\\h+)*"
                    + "(?:class|record|enum|interface)\\h+(" + JAVA_IDENTIFIER + ")");
    private static final Pattern EXPORT_PACKAGE = Pattern.compile(
            "(?m)^\\h*package\\h+(" + JAVA_IDENTIFIER + "(?:\\." + JAVA_IDENTIFIER + ")*)\\h*;");

    public byte[] exportProject(String code, String stdin) throws IOException {
        if (code == null || code.isBlank()) throw new IllegalArgumentException("代码不能为空");
        if (code.length() > props.getCode().getMaxSourceChars() || (stdin != null && stdin.length() > 60_000))
            throw new IllegalArgumentException("代码或标准输入超过导出长度限制");

        String declarations = code.replaceAll("(?s)/\\*.*?\\*/", " ").replaceAll("(?m)//.*$", "");
        Matcher types = EXPORT_TYPE.matcher(declarations);
        String typeName = null;
        while (types.find()) {
            if (typeName == null || types.group(1) != null) typeName = types.group(2);
            if (types.group(1) != null) break;
        }

        Matcher packages = EXPORT_PACKAGE.matcher(declarations);
        String packageName = packages.find() ? packages.group(1) : "";
        boolean isFragment = typeName == null && (!packageName.isEmpty()
                || (!MAIN_METHOD.matcher(declarations).find() && TOP_LEVEL_METHOD.matcher(declarations).find()));
        if (typeName == null && !isFragment) {
            typeName = "SnippetMain";
            code = wrapRunnableSnippet(code);
        }

        String packagePath = packageName.isEmpty() ? "" : packageName.replace('.', '/') + "/";
        String sourcePath = isFragment ? "snippet.txt" : "src/main/java/" + packagePath + typeName + ".java";
        String runHint = isFragment ? "当前代码包含未封装的声明。请打开 snippet.txt，补齐类和 main 后移入 src/main/java。"
                : "打开 " + sourcePath + "。如果代码包含 main，可在 IDE 中直接运行或断点调试。";

        var bytes = new ByteArrayOutputStream();
        try (var zip = new ZipOutputStream(bytes, StandardCharsets.UTF_8)) {
            writeEntry(zip, "pom.xml", """
                    <project xmlns="http://maven.apache.org/POM/4.0.0">
                        <modelVersion>4.0.0</modelVersion>
                        <groupId>local.javacourse</groupId>
                        <artifactId>lesson-lab</artifactId>
                        <version>1.0.0</version>
                        <properties>
                            <maven.compiler.release>17</maven.compiler.release>
                            <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
                        </properties>
                        <build>
                            <plugins>
                                <plugin>
                                    <groupId>org.apache.maven.plugins</groupId>
                                    <artifactId>maven-compiler-plugin</artifactId>
                                    <version>3.13.0</version>
                                </plugin>
                            </plugins>
                        </build>
                    </project>
                    """);
            writeEntry(zip, sourcePath, code);
            writeEntry(zip, "stdin.txt", stdin == null ? "" : stdin);
            writeEntry(zip, "README.md", """
                    # Java 课程实验

                    解压后，在 IntelliJ IDEA 中打开 pom.xml 并作为项目导入，或在安装了 Java 扩展的 VS Code 中打开工程目录。
                    配置本机 JDK 17 或更新版本。如示例使用更新的 Java 特性，请调整 pom.xml 中的 Java 版本。
                    %s
                    stdin.txt 保存了导出时的标准输入。运行时可在终端粘贴，或在 IDEA 的运行配置中设置输入重定向。
                    需要第三方库的代码请在 pom.xml 中添加相应依赖。
                    """.formatted(runHint));
        }
        return bytes.toByteArray();
    }

    private static void writeEntry(ZipOutputStream zip, String name, String content) throws IOException {
        zip.putNextEntry(new ZipEntry(name));
        zip.write(content.getBytes(StandardCharsets.UTF_8));
        zip.closeEntry();
    }

    /** Make statement-only lesson examples executable without changing the text shown in the editor. */
    private String wrapRunnableSnippet(String snippet) {
        StringBuilder imports = new StringBuilder();
        StringBuilder body = new StringBuilder();
        for (String line : snippet.split("\\n", -1)) {
            String trimmed = line.trim();
            if (trimmed.startsWith("import ") && trimmed.endsWith(";")) {
                imports.append(line).append('\n');
            } else {
                body.append(line).append('\n');
            }
        }

        StringBuilder source = new StringBuilder(imports)
                .append("public class SnippetMain {\n");
        if (MAIN_METHOD.matcher(body).find()) {
            source.append(body).append("}\n");
        } else {
            source.append("    public static void main(String[] args) throws Exception {\n")
                    .append(body)
                    .append("    }\n}\n");
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
