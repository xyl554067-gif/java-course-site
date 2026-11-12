import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.InvalidPathException;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;
import java.util.zip.ZipInputStream;

public class JavaCourseIdeBridge {
    private static final int PORT = 18763;
    private static final String ORIGIN = "https://xyl554067-gif.github.io";
    private static final String PROJECT_POM_SHA256 = "1c19957ec4e1d6def05de67dae63cd7291d62cf9906f78380c2a869abd5203ac";
    private static final int MAX_ARCHIVE = 512 * 1024;
    private static final int MAX_PROJECT = 1024 * 1024;
    private static final Set<String> PROJECT_FILES = Set.of("pom.xml", "README.md", "stdin.txt", "snippet.txt");
    private static final String IDENTIFIER = "[\\p{javaJavaIdentifierStart}][\\p{javaJavaIdentifierPart}]*";
    private static final Pattern JAVA_FILE =
            Pattern.compile("src/main/java/(?:" + IDENTIFIER + "/)*" + IDENTIFIER + "\\.java");

    public static void main(String[] args) throws IOException {
        Map<String, Path> launchers = new LinkedHashMap<>();
        for (int i = 0; i < args.length; i += 2) {
            String flag = args[i];
            if (i + 1 >= args.length || (!flag.equals("--idea") && !flag.equals("--vscode"))) {
                throw new IllegalArgumentException("Usage: java JavaCourseIdeBridge.java [--idea <idea64.exe>] [--vscode <Code.exe>]");
            }
            String ide = flag.substring(2);
            Path executable = Path.of(args[i + 1]).toAbsolutePath();
            if (!isLauncher(executable, ide)) {
                throw new IllegalArgumentException("Invalid " + flag + " path: " + executable);
            }
            launchers.put(ide, executable);
        }

        HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", PORT), 8);
        server.createContext("/v1/", exchange -> {
            try (exchange) {
                handle(exchange, launchers);
            }
        });
        server.start();
        System.out.println("Java Course IDE bridge ready at 127.0.0.1:" + PORT + ". Press Ctrl+C to stop.");
    }

    private static void handle(HttpExchange exchange, Map<String, Path> launchers) throws IOException {
        var headers = exchange.getRequestHeaders();
        if (!ORIGIN.equals(headers.getFirst("Origin")) || !("127.0.0.1:" + PORT).equals(headers.getFirst("Host"))) {
            reply(exchange, 403, "来源未获授权。");
            return;
        }
        var response = exchange.getResponseHeaders();
        response.set("Access-Control-Allow-Origin", ORIGIN);
        response.set("Vary", "Origin");
        response.set("Cache-Control", "no-store");

        String path = exchange.getRequestURI().getPath();
        String method = exchange.getRequestMethod();
        boolean status = path.equals("/v1/status");
        String ide = switch (path) {
            case "/v1/open/idea" -> "idea";
            case "/v1/open/vscode" -> "vscode";
            default -> null;
        };
        if (!status && ide == null) {
            reply(exchange, 404, "找不到此入口。");
            return;
        }
        if ("OPTIONS".equals(method)) {
            response.set("Access-Control-Allow-Methods", status ? "GET" : "POST");
            response.set("Access-Control-Allow-Headers", "Content-Type");
            exchange.sendResponseHeaders(204, -1);
            return;
        }
        if (status && "GET".equals(method)) {
            reply(exchange, 200, "JavaCourseIdeBridge/v1");
            return;
        }
        if (status || !"POST".equals(method) || !"application/zip".equals(headers.getFirst("Content-Type"))) {
            reply(exchange, 400, "请求格式不正确。");
            return;
        }

        Path launcher = launchers.get(ide);
        if (launcher == null) launcher = findLauncher(ide);
        if (launcher == null) {
            String flag = ide.equals("idea") ? "--idea" : "--vscode";
            reply(exchange, 422, "找不到所选 IDE。请用 " + flag + " 指定 IDE 程序的完整路径后重启助手。");
            return;
        }
        byte[] archive = exchange.getRequestBody().readNBytes(MAX_ARCHIVE + 1);
        if (archive.length > MAX_ARCHIVE) {
            reply(exchange, 413, "工程文件过大。");
            return;
        }
        Map<String, byte[]> files;
        try {
            files = readProject(archive);
        } catch (IOException | IllegalArgumentException error) {
            reply(exchange, 400, "无法读取 Java 课程工程。");
            return;
        }

        try {
            Path project = Files.createTempDirectory("javacourse-lesson-");
            for (var file : files.entrySet()) {
                Path target = project.resolve(file.getKey());
                Files.createDirectories(target.getParent());
                Files.write(target, file.getValue());
            }
            new ProcessBuilder(launcher.toString(), project.toString()).start();
            System.out.println("Project opened: " + project);
            reply(exchange, 200, "已在本机 IDE 打开工程。");
        } catch (IOException error) {
            System.err.println("Unable to open the project: " + error.getMessage());
            reply(exchange, 500, "本机无法打开工程，请查看助手窗口中的提示。");
        }
    }

    private static Map<String, byte[]> readProject(byte[] archive) throws IOException {
        Map<String, byte[]> files = new LinkedHashMap<>();
        int remaining = MAX_PROJECT;
        int sources = 0;
        try (var zip = new ZipInputStream(new ByteArrayInputStream(archive), StandardCharsets.UTF_8)) {
            for (var entry = zip.getNextEntry(); entry != null; entry = zip.getNextEntry()) {
                String name = entry.getName();
                boolean source = JAVA_FILE.matcher(name).matches();
                if ((!source && !PROJECT_FILES.contains(name)) || files.containsKey(name) || entry.isDirectory()) {
                    throw new IllegalArgumentException("Unexpected project file");
                }
                if ((source || name.equals("snippet.txt")) && ++sources > 1) {
                    throw new IllegalArgumentException("Too many source files");
                }
                byte[] bytes = zip.readNBytes(remaining + 1);
                if (bytes.length > remaining) throw new IllegalArgumentException("Project exceeds size limit");
                files.put(name, bytes);
                remaining -= bytes.length;
            }
        }
        if (sources != 1 || !files.keySet().containsAll(Set.of("pom.xml", "README.md", "stdin.txt"))) {
            throw new IllegalArgumentException("Missing project files");
        }
        try {
            String pomHash = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(files.get("pom.xml")));
            if (!PROJECT_POM_SHA256.equals(pomHash)) throw new IllegalArgumentException("Unexpected Maven configuration");
        } catch (NoSuchAlgorithmException error) {
            throw new IllegalStateException(error);
        }
        return files;
    }

    private static Path findLauncher(String ide) {
        String executable = ide.equals("idea") ? "idea64.exe" : "Code.exe";
        String path = System.getenv("PATH");
        if (path != null) {
            for (String directory : path.split(Pattern.quote(java.io.File.pathSeparator))) {
                try {
                    Path folder = Path.of(directory);
                    Path candidate = folder.resolve(executable).toAbsolutePath();
                    if (isLauncher(candidate, ide)) return candidate;
                    if (ide.equals("vscode") && folder.getParent() != null) {
                        Path app = folder.getParent().resolve(executable).toAbsolutePath();
                        if (isLauncher(app, ide)) return app;
                    }
                } catch (InvalidPathException ignored) {
                    // Ignore malformed PATH entries.
                }
            }
        }
        String userData = System.getenv("LOCALAPPDATA");
        String programFiles = System.getenv("ProgramFiles");
        if (ide.equals("vscode")) {
            for (Path base : new Path[] { userData == null ? null : Path.of(userData, "Programs"),
                    programFiles == null ? null : Path.of(programFiles) }) {
                if (base == null) continue;
                Path app = base.resolve("Microsoft VS Code").resolve(executable);
                if (isLauncher(app, ide)) return app;
            }
        } else {
            for (Path base : new Path[] { userData == null ? null : Path.of(userData, "Programs"),
                    programFiles == null ? null : Path.of(programFiles, "JetBrains") }) {
                if (base == null || !Files.isDirectory(base)) continue;
                try (var installations = Files.newDirectoryStream(base, "IntelliJ IDEA*")) {
                    for (Path installation : installations) {
                        Path app = installation.resolve("bin").resolve(executable);
                        if (isLauncher(app, ide)) return app;
                    }
                } catch (IOException ignored) {
                    // A custom installation can still be provided with --idea.
                }
            }
        }
        return null;
    }

    private static boolean isLauncher(Path path, String ide) {
        String expected = ide.equals("idea") ? "idea64.exe" : "Code.exe";
        return path.getFileName() != null && expected.equalsIgnoreCase(path.getFileName().toString()) && Files.isRegularFile(path);
    }

    private static void reply(HttpExchange exchange, int status, String message) throws IOException {
        byte[] body = message.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "text/plain; charset=utf-8");
        exchange.sendResponseHeaders(status, body.length);
        exchange.getResponseBody().write(body);
    }
}
