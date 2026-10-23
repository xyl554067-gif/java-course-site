# -*- coding: utf-8 -*-
"""对比源文件与库内内容，定位写回过程中被替换的字符"""
import base64, glob, os, re, subprocess

JAR = r"C:\Users\lxy\.m2\repository\cn\com\kingbase\kingbase8\8.6.0\kingbase8-8.6.0.jar"
SQL = r"C:\Users\lxy\kbtmp\_cmp.sql"
DUMP = r"D:\code\PythonApplication1\2026-10-22-10-05-58\docs\lesson-dump"


def fetch():
    with open(SQL, "w", encoding="utf-8") as f:
        f.write("SELECT slug, content FROM lesson ORDER BY id;")
    r = subprocess.run(
        ["java", "-cp", JAR, "KbQ64.java", "127.0.0.1", "54321", "javacourse",
         SQL, "javacourse_app", "App@Course2026"],
        cwd=r"C:\Users\lxy\kbtmp", capture_output=True)
    out = {}
    for line in r.stdout.decode("utf-8", errors="replace").splitlines():
        if not line.startswith("ROW"):
            continue
        p = base64.b64decode(line[3:]).decode("utf-8").split("\t")
        out[p[1]] = "\t".join(p[2:])
    return out


def main():
    db = fetch()
    print(f"库内 {len(db)} 个课时\n")
    for f in sorted(glob.glob(os.path.join(DUMP, "_new-*.md"))):
        slug = os.path.basename(f)[len("_new-"):-len(".md")]
        src = open(f, encoding="utf-8").read()
        got = db.get(slug, "")
        # 找出源文件里变成 ? 的位置
        lost = []
        for i, ch in enumerate(src):
            if ord(ch) > 127 and ch in got:
                continue
            if ord(ch) > 127:
                lost.append((i, ch))
        if lost:
            uniq = sorted(set(c for _, c in lost))
            print(f"{slug:26s} 丢失 {len(lost)} 个非 ASCII 字符: "
                  + " ".join(f"U+{ord(c):04X}" for c in uniq))
    print("\n（未列出的课时内容完整）")


if __name__ == "__main__":
    main()
