# -*- coding: utf-8 -*-
"""
把课时正文写回 KingbaseES。

编码说明（重要）：
  该 KingbaseES 实例为 oracle 兼容模式，JDBC 驱动用 GBK 转换字符串，
  GBK 不含的少数字符（U+2212 −、U+2714 ✔、U+2718 ✘、U+21D2 ⇒、U+1F600 😀）
  会被替换成 '?'。因此写入前统一做一次字符净化，替换成语义等价的 ASCII/GBK 字符。

写入链路：Java + PreparedStatement 参数绑定（与后端 Spring JdbcTemplate 一致），
不经过 SQL 字面量与控制台，避免二次编码损坏。

用法：python apply_lesson_content.py <slug> <正文文件>
"""
import os, re, subprocess, sys

BACKEND = r"D:\code\PythonApplication1\2026-10-22-10-05-58\backend"
TARGET = os.path.join(BACKEND, "target")
JAR_DIR = os.path.join(TARGET, "applibs")
SCRIPTS = r"D:\code\PythonApplication1\2026-10-22-10-05-58\scripts"
SRC = os.path.join(SCRIPTS, "KbWrite.java")

# GBK 不含的字符 -> 等价替换
SANITIZE = {
    "\u2212": "-",     # − 真减号 -> ASCII 连字符
    "\u2714": "[OK]",  # ✔ 重勾 -> 文本
    "\u2718": "[X]",   # ✘ 叉 -> 文本
    "\u21d2": "=>",    # ⇒ 双箭头 -> ASCII
    "\U0001F600": "",  # 😀 emoji（示例用表情，去掉更稳）
}


def sanitize(text):
    for src, dst in SANITIZE.items():
        text = text.replace(src, dst)
    return text


def write(slug, content_file):
    """调用 Java 写入器（单文件源码模式，需在 scripts 目录下执行）"""
    r = subprocess.run(
        [r"D:\develop\Java\jdk-21\bin\java.exe", "-cp", f"{JAR_DIR}/*", "KbWrite.java",
         "127.0.0.1", "54321", "javacourse", "public",
         "javacourse_app", "App@Course2026", slug, content_file],
        cwd=SCRIPTS, capture_output=True)
    out = r.stdout.decode("utf-8", errors="replace").strip()
    err = r.stderr.decode("utf-8", errors="replace").strip()
    if r.returncode != 0:
        raise RuntimeError(err[-400:])
    return out


def main():
    slug = sys.argv[1]
    path = sys.argv[2]
    with open(path, encoding="utf-8") as f:
        content = f.read()
    if not content.strip():
        print("正文为空，拒绝写入")
        sys.exit(1)

    # 净化不可编码字符
    cleaned = sanitize(content)
    tmp = os.path.join(TARGET, "_content_tmp.txt")
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(cleaned)

    out = write(slug, tmp)
    print(f"ROW\t{slug}\t{out}")


if __name__ == "__main__":
    main()
