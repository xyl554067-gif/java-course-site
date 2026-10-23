import java.sql.*; import java.nio.charset.StandardCharsets; import java.nio.file.*;
import java.util.*; import java.security.MessageDigest;

/**
 * 在一个事务里执行 seed 脚本，读回比对，最后 ROLLBACK —— 验证脚本可用且不改变现状。
 * 用法: KbSeedTest <host> <port> <db> <seedFile> <user> <pw>
 */
public class KbSeedTest {
  public static void main(String[] a) throws Exception {
    String sql=new String(Files.readAllBytes(Paths.get(a[3])), StandardCharsets.UTF_8);
    String url="jdbc:kingbase8://"+a[0]+":"+a[1]+"/"+a[2]+"?currentSchema=public&characterEncoding=UTF-8";
    try(Connection c=DriverManager.getConnection(url,a[4],a[5])){
      c.setAutoCommit(false);
      Map<String,String> before=new LinkedHashMap<>();
      try(Statement st=c.createStatement(); ResultSet rs=st.executeQuery("SELECT slug, content FROM lesson ORDER BY id")){
        while(rs.next()) before.put(rs.getString(1), rs.getString(2));
      }
      int n = 0;
      try (Statement st = c.createStatement()) {
        // 去掉 BEGIN/COMMIT：JDBC 已开启事务，连接关闭会自动回滚；
        // 而 BEGIN/COMMIT 走 Statement.execute，在本实例上会触发参数绑定误判。
        String body = sql.replaceAll("(?im)^\\s*BEGIN\\s*;", "")
                          .replaceAll("(?im)^\\s*COMMIT\\s*;", "");
        // 正文里含分号（如 System.out.println("...");），不能按分号切分。
        // 脚本里每条 UPDATE 前都有「-- slug」注释行，按它切分最可靠。
        java.util.regex.Pattern stmtSplit =
            java.util.regex.Pattern.compile("(?m)^-- [a-z0-9-]+\\s*$");
        for (String one : stmtSplit.split(body)) {
          String s = one.trim();
          if (s.isEmpty()) continue;
          if (s.endsWith(";")) s = s.substring(0, s.length() - 1).trim();
          // 必须用 executeUpdate：Statement.execute 会把字面量里的 ? 当参数标记报绑定错误
          st.executeUpdate(s);
          n++;
        }
      }
      System.out.println("statements_executed="+n);
      Map<String,String> after=new LinkedHashMap<>();
      try(Statement st=c.createStatement(); ResultSet rs=st.executeQuery("SELECT slug, content FROM lesson ORDER BY id")){
        while(rs.next()) after.put(rs.getString(1), rs.getString(2));
      }
      int same=0; List<String> diff=new ArrayList<>();
      for(Map.Entry<String,String> e: before.entrySet()){
        String x=e.getValue()==null?"":e.getValue().replace("\r\n","\n");
        String y=(after.get(e.getKey())==null?"":after.get(e.getKey())).replace("\r\n","\n");
        if(x.equals(y)) same++; else diff.add(e.getKey());
      }
      System.out.println("identical="+same+"/"+before.size());
      if(!diff.isEmpty()) System.out.println("diff="+diff.subList(0, Math.min(10,diff.size())));
    } finally {
      // 上面 try-with-resources 已关闭连接，事务随连接关闭自动回滚
    }
  }
}
