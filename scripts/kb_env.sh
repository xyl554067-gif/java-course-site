#!/usr/bin/env bash
# ============================================================================
# KingBase 连接配置（唯一事实来源）
#
# 实测结论（2026-10-22）：
#   * 本机 KingbaseES V8R6C009B0014 全局只允许一个实例运行。
#     License 共享内存是 Global\kingbase:* 内核命名对象，创建它需要
#     SeCreateGlobalPrivilege —— 普通权限进程无法创建/附加，会报:
#       FATAL: XX000: attach License shared memory error: openfilemapping error
#     因此实例必须由【管理员权限】的进程启动，本项目不再自行拉起。
#   * 正在运行的实例数据目录: D:\Kingbase\data
#   * 端口 54321，系统账号 system / 123456（该实例无 system 库，连template1）
#   * 本项目应用库: javacourse，账号 javacourse_app / App@Course2026
#   * 演示账号：admin / demo，口令 123456
# ============================================================================

KB_HOST="127.0.0.1"
KB_PORT="54321"
KB_DB="javacourse"
KB_APP_USER="javacourse_app"
KB_APP_PW="App@Course2026"
KB_SYS_USER="system"
KB_SYS_PW="123456"

KB_JDBC_URL="jdbc:kingbase8://${KB_HOST}:${KB_PORT}/${KB_DB}?currentSchema=public&characterEncoding=UTF-8"
KB_JDBC_DRIVER="com.kingbase8.Driver"
KB_JDBC_JAR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/backend/lib/kingbase8-8.6.0.jar"

# Java 单文件源码模式下无法读取带中文的 Windows 路径，
# 所有 SQL 文件必须先拷到纯 ASCII 路径（如 /c/Users/<user>/）再执行。
KB_TMP_DIR="/c/Users/$USERNAME/kbtmp"
mkdir -p "$KB_TMP_DIR" 2>/dev/null

# 判断数据库端口是否在监听
kb_is_up() {
  netstat -ano 2>/dev/null | grep -q ":${KB_PORT} "
}

# 把 SQL 文件复制到可执行路径，返回 Windows 风格的绝对路径
kb_stage_sql() {
  local src="$1"
  local base
  base="$(basename "$src")"
  cp -f "$src" "$KB_TMP_DIR/$base" || return 1
  echo "C:/Users/$USERNAME/kbtmp/$base"
}

# 执行 SQL 文件（SQL 感知分割，正确处理字符串中的分号）
# 用法: kb_run_sql <db> <user> <pw> <sql文件>
kb_run_sql() {
  local db="$1" user="$2" pw="$3" file="$4"
  local staged
  staged="$(kb_stage_sql "$file")" || { echo "   拷贝 SQL 文件失败: $file"; return 1; }

  local jf="$KB_TMP_DIR/KbRunSql.java"
  cat > "$jf" <<'JAVA'
import java.sql.*; import java.nio.file.*; import java.nio.charset.StandardCharsets; import java.util.*;
public class KbRunSql {
  static List<String> split(String sql){
    List<String> out=new ArrayList<>(); StringBuilder cur=new StringBuilder();
    int i=0,n=sql.length();
    while(i<n){
      char c=sql.charAt(i);
      if(c=='-' && i+1<n && sql.charAt(i+1)=='-'){ while(i<n && sql.charAt(i)!='\n') i++; continue; }
      if(c=='/' && i+1<n && sql.charAt(i+1)=='*'){ i+=2; while(i+1<n && !(sql.charAt(i)=='*'&&sql.charAt(i+1)=='/')) i++; i+=2; continue; }
      if(c=='\''){ cur.append(c); i++; while(i<n){ char q=sql.charAt(i); cur.append(q); i++; if(q=='\''){ if(i<n && sql.charAt(i)=='\''){ cur.append('\''); i++; } else break; } } continue; }
      if(c=='"'){ cur.append(c); i++; while(i<n){ char q=sql.charAt(i); cur.append(q); i++; if(q=='"'){ if(i<n && sql.charAt(i)=='"'){ cur.append('"'); i++; } else break; } } continue; }
      if(c==';'){ String s=cur.toString().trim(); if(!s.isEmpty()) out.add(s); cur.setLength(0); i++; continue; }
      cur.append(c); i++;
    }
    String s=cur.toString().trim(); if(!s.isEmpty()) out.add(s);
    return out;
  }
  public static void main(String[] a) throws Exception {
    String content=new String(Files.readAllBytes(Paths.get(a[3])),StandardCharsets.UTF_8);
    List<String> stmts=split(content);
    try(Connection c=DriverManager.getConnection("jdbc:kingbase8://"+a[0]+":"+a[1]+"/"+a[2]+"?characterEncoding=UTF-8",a[4],a[5]);
        Statement s=c.createStatement()){
      int ok=0,fail=0;
      for(String st: stmts){
        try{ s.execute(st); ok++; }
        catch(Exception e){ fail++; System.out.println("   FAIL: "+st.substring(0,Math.min(120,st.length())).replace("\n"," ")+" -> "+e.getMessage()); }
      }
      System.out.println("   applied="+ok+" failed="+fail+" total="+stmts.size());
    }
  }
}
JAVA

  java -cp "$KB_JDBC_JAR" "$jf" "$KB_HOST" "$KB_PORT" "$db" "$staged" "$user" "$pw"
  rm -f "$jf"
}

# 执行任意 SQL 字符串
kb_exec() {
  local db="$1" user="$2" pw="$3" sql="$4"
  local f="$KB_TMP_DIR/kb_exec.sql"
  printf '%s\n' "$sql" > "$f"
  kb_run_sql "$db" "$user" "$pw" "$f"
}

# 用系统账号执行（DDL / 建库等需要高权限的操作）
kb_sys() {
  kb_exec "$KB_DB" "$KB_SYS_USER" "$KB_SYS_PW" "$1"
}

# 用应用账号执行（日常 DML）
kb_app() {
  kb_exec "$KB_DB" "$KB_APP_USER" "$KB_APP_PW" "$1"
}

# 查询并以竖线分隔输出
kb_query() {
  local db="$1" user="$2" pw="$3" sql="$4"
  local f="$KB_TMP_DIR/kb_query.sql"
  local jf="$KB_TMP_DIR/KbQuery.java"
  printf '%s\n' "$sql" > "$f"
  cat > "$jf" <<'JAVA'
import java.sql.*; import java.nio.charset.StandardCharsets;
public class KbQuery {
  public static void main(String[] a) throws Exception {
    String sql=new String(java.nio.file.Files.readAllBytes(java.nio.file.Paths.get(a[3])),StandardCharsets.UTF_8).trim();
    if(sql.endsWith(";")) sql=sql.substring(0,sql.length()-1);
    try(Connection c=DriverManager.getConnection("jdbc:kingbase8://"+a[0]+":"+a[1]+"/"+a[2]+"?characterEncoding=UTF-8",a[4],a[5]);
        Statement s=c.createStatement(); ResultSet rs=s.executeQuery(sql)){
      ResultSetMetaData md=rs.getMetaData(); int n=md.getColumnCount();
      for(int i=1;i<=n;i++){ if(i>1) System.out.print(" | "); System.out.print(md.getColumnLabel(i)); }
      System.out.println();
      while(rs.next()){ for(int i=1;i<=n;i++){ if(i>1) System.out.print(" | "); System.out.print(rs.getString(i)); } System.out.println(); }
    }
  }
}
JAVA
  java -cp "$KB_JDBC_JAR" "$jf" "$KB_HOST" "$KB_PORT" "$db" "C:/Users/$USERNAME/kbtmp/kb_query.sql" "$user" "$pw"
  rm -f "$jf"
}