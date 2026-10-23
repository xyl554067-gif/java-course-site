# -*- coding: utf-8 -*-
"""
导出增强后的课时正文，生成可版本管理的 SQL 更新脚本。

读取走 KbQ64（base64 输出），避免 Windows 控制台编码损坏中文；
写入端做与 apply_lesson_content.py 相同的字符净化，保证 SQL 在任何环境都能正确执行。

用法：python export_content_seed.py
输出：backend/src/main/resources/db/seed-content-enhanced.sql
"""
import base64, os, subprocess, sys

JAR = r"C:\Users\lxy\.m2\repository\cn\com\kingbase\kingbase8\8.6.0\kingbase8-8.6.0.jar"
SQL = r"C:\Users\lxy\kbtmp\_export.sql"
OUT = r"D:\code\PythonApplication1\2026-10-22-10-05-58\backend\src\main\resources\db\seed-content-enhanced.sql"

sys.path.insert(0, r"D:\code\PythonApplication1\2026-10-22-10-05-58\scripts")
from apply_lesson_content import sanitize  # noqa: E402

HEADER = """-- ============================================================================
-- Java 课程介绍网站 — 课时正文增强内容（基于 ima「Java江湖」知识库校准）
-- ----------------------------------------------------------------------------
-- 说明：
--   本脚本只更新 lesson.content，不改动表结构与其他字段。
--   原始 seed.sql 保留初始内容，两者可叠加执行（后者覆盖正文）。
--
--   正文结构：
--     ## 本节要点 / ## 核心概念 / ## 关键代码 / ## 常见误区 /
--     ## 动手练习 / ## 延伸阅读（来自「Java江湖」知识库）
--   「延伸阅读」段落标注了每个知识点对应的知识库资料，便于溯源与后续更新。
--
--   字符说明：GBK 字符集不含少数字符（如 U+2212 −、U+2714 ✔、emoji），
--   已统一替换为语义等价的 ASCII/GBK 字符，保证在 oracle 兼容模式下也能完整落库。
--
-- 生成方式：scripts/export_content_seed.py（从运行中的库导出）
-- ============================================================================

BEGIN;

"""


def esc(s):
    return s.replace("'", "''")


def fetch():
    with open(SQL, "w", encoding="utf-8") as f:
        f.write("SELECT slug, content FROM lesson ORDER BY id;")
    r = subprocess.run(
        ["java", "-cp", JAR, "KbQ64.java", "127.0.0.1", "54321", "javacourse",
         SQL, "javacourse_app", "App@Course2026"],
        cwd=r"C:\Users\lxy\kbtmp", capture_output=True)
    lessons = []
    for line in r.stdout.decode("utf-8", errors="replace").splitlines():
        if not line.startswith("ROW"):
            continue
        p = base64.b64decode(line[3:]).decode("utf-8").split("\t")
        lessons.append((p[1], "\t".join(p[2:])))
    return lessons


def main():
    lessons = fetch()
    lines = [HEADER]
    for slug, content in lessons:
        if not content.strip():
            continue
        # 库里的内容已是净化后的版本，这里再净化一次保证幂等
        content = sanitize(content.replace("\r\n", "\n"))
        lines.append(f"-- {slug}\nUPDATE lesson SET content = '{esc(content)}' WHERE slug = '{esc(slug)}';\n")
    lines.append("COMMIT;\n")

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"导出 {len(lessons)} 个课时正文 -> {OUT}")
    print(f"文件大小 {os.path.getsize(OUT)} 字节")


if __name__ == "__main__":
    main()
