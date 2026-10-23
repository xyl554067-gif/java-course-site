import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;

/**
 * 用与后端应用完全一致的 JDBC 链路写入课时正文。
 *
 * 为什么不直接用 SQL 字面量：
 *   该 KingbaseES 实例为 oracle 兼容模式，SQL 文本经过驱动/服务端转换时
 *   非 GBK 字符（如 U+2212、emoji）会被替换成 '?'。
 *   用 PreparedStatement 参数绑定 + 与 application.yml 相同的 URL，
 *   编码行为与 Spring JdbcTemplate 一致，中文与符号都能完整落库。
 *
 * 用法: KbWrite <host> <port> <db> <schema> <user> <pw> <slug> <contentFile>
 */
public class KbWrite {
    public static void main(String[] args) throws Exception {
        String content = new String(Files.readAllBytes(Paths.get(args[7])), StandardCharsets.UTF_8);
        // 与 application.yml 保持一致：characterEncoding=UTF-8 + currentSchema
        String url = "jdbc:kingbase8://" + args[0] + ":" + args[1] + "/" + args[2]
                + "?currentSchema=" + args[3] + "&characterEncoding=UTF-8";
        Class.forName("com.kingbase8.Driver");
        try (Connection c = DriverManager.getConnection(url, args[4], args[5]);
             PreparedStatement ps = c.prepareStatement(
                     "UPDATE lesson SET content = ? WHERE slug = ?")) {
            ps.setString(1, content);
            ps.setString(2, args[6]);
            System.out.println("updated=" + ps.executeUpdate() + " chars=" + content.length());
        }
    }
}
