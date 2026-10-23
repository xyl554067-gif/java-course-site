# -*- coding: utf-8 -*-
"""导出全部课时正文到本地文件，便于统一分析与增强"""
import os, subprocess, sys

KBTMP = r"C:\Users\lxy\kbtmp"
OUT = r"D:\code\PythonApplication1\2026-10-22-10-05-58\docs\lesson-dump"
JAR = r"C:\Users\lxy\.m2\repository\cn\com\kingbase\kingbase8\8.6.0\kingbase8-8.6.0.jar"


def query(sql):
    sql_file = os.path.join(KBTMP, "_q.sql")
    with open(sql_file, "w", encoding="utf-8") as f:
        f.write(sql)
    r = subprocess.run(
        ["java", "-Dstdout.encoding=UTF-8", "-cp", JAR, "KbQ.java",
         "127.0.0.1", "54321", "javacourse", sql_file, "javacourse_app", "App@Course2026"],
        cwd=KBTMP, capture_output=True)
    return r.stdout.decode("utf-8", errors="replace")


def main():
    os.makedirs(OUT, exist_ok=True)
    data = query("SELECT slug, content FROM lesson ORDER BY id;")
    # 解析 ROW<TAB>slug<TAB>content
    cur_slug, buf = None, []
    lessons = {}
    for line in data.splitlines():
        if line.startswith("ROW\t"):
            parts = line.split("\t", 2)
            if len(parts) >= 3:
                if cur_slug:
                    lessons[cur_slug] = "\n".join(buf)
                cur_slug = parts[1]
                buf = [parts[2]]
            elif len(parts) == 2 and cur_slug:
                buf.append(parts[1])
    if cur_slug:
        lessons[cur_slug] = "\n".join(buf)

    for slug, content in lessons.items():
        # 去掉 KbQ 压平掉的制表符，保留内容
        with open(os.path.join(OUT, f"{slug}.md"), "w", encoding="utf-8") as f:
            f.write(content)
    print(f"导出 {len(lessons)} 个课时正文到 {OUT}")
    for slug, c in sorted(lessons.items(), key=lambda kv: -len(kv[1]))[:5]:
        print(f"  {slug}: {len(c)} 字符")


if __name__ == "__main__":
    main()
