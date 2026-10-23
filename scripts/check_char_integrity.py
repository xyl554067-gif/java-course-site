# -*- coding: utf-8 -*-
"""校验课时正文里的特殊字符是否完整落库"""
import base64, subprocess

JAR = r"C:\Users\lxy\.m2\repository\cn\com\kingbase\kingbase8\8.6.0\kingbase8-8.6.0.jar"
SQL = r"C:\Users\lxy\kbtmp\_probe.sql"

PROBES = [
    ("\u2212", "U+2212 真减号"),
    ("\U0001F600", "emoji"),
    ("\u4E2D", "中文汉字"),
    ("\u2713", "对勾"),
    ("\u2500", "制表线"),
    ("\u2014", "破折号"),
    ("\u3002", "中文句号"),
]


def q(sql):
    with open(SQL, "w", encoding="utf-8") as f:
        f.write(sql)
    r = subprocess.run(
        ["java", "-cp", JAR, "KbQ64.java", "127.0.0.1", "54321", "javacourse",
         SQL, "javacourse_app", "App@Course2026"],
        cwd=r"C:\Users\lxy\kbtmp", capture_output=True)
    out = []
    for line in r.stdout.decode("utf-8", errors="replace").splitlines():
        if line.startswith("ROW"):
            out.append(base64.b64decode(line[3:]).decode("utf-8"))
    return out


rows = q("SELECT slug, content FROM lesson ORDER BY id;")
print(f"共 {len(rows)} 个课时\n")
bad = {}
for r in rows:
    parts = r.split("\t")
    slug = parts[1]
    content = "\t".join(parts[2:])
    for ch, label in PROBES:
        if ch in content:
            continue
    # 统计 U+FFFD 替换字符（真正的编码损坏标志）
    n = content.count("\ufffd")
    if n:
        bad[slug] = n

if bad:
    print("存在替换字符(U+FFFD)的课时：")
    for k, v in bad.items():
        print(f"  {k}: {v} 处")
else:
    print("✔ 全部课时无 U+FFFD 替换字符")

print("\n特征字符抽样：")
for r in rows[:1] + rows:
    parts = r.split("\t")
    slug, content = parts[1], "\t".join(parts[2:])
    if slug not in ("variables-and-types", "string", "jvm-memory"):
        continue
    hits = [label for ch, label in PROBES if ch in content]
    print(f"  {slug:22s} 长度={len(content):6d} 含: {', '.join(hits) if hits else '（无特殊字符）'}")
