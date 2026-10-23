# -*- coding: utf-8 -*-
"""
校验库内课时正文与源文件是否逐字符一致。

读库走 KbQ64（base64 输出），比对前先对源文件做与写入器相同的字符净化。
"""
import base64, glob, os, subprocess, sys

JAR = r"C:\Users\lxy\.m2\repository\cn\com\kingbase\kingbase8\8.6.0\kingbase8-8.6.0.jar"
SQL = r"C:\Users\lxy\kbtmp\_verify.sql"
DUMP = r"D:\code\PythonApplication1\2026-10-22-10-05-58\docs\lesson-dump"

sys.path.insert(0, r"D:\code\PythonApplication1\2026-10-22-10-05-58\scripts")
from apply_lesson_content import sanitize  # noqa: E402


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
    ok = 0
    bad = []
    for f in sorted(glob.glob(os.path.join(DUMP, "_new-*.md"))):
        slug = os.path.basename(f)[len("_new-"):-len(".md")]
        src = sanitize(open(f, encoding="utf-8").read())
        got = db.get(slug, "")
        # 库里存的是 CRLF（与原始课程正文一致，前端 renderMarkdown 会归一），比对时忽略换行差异
        norm = lambda s: s.replace("\r\n", "\n")
        if norm(src) == norm(got):
            ok += 1
        else:
            ns, ng = norm(src), norm(got)
            i = next((k for k in range(min(len(ns), len(ng))) if ns[k] != ng[k]),
                     min(len(ns), len(ng)))
            bad.append((slug, len(ns), len(ng), i, ns[i:i + 16], ng[i:i + 16]))

    for slug, ls, lg, i, s, g in bad:
        print(f"  ✘ {slug:26s} 源={ls:6d} 库={lg:6d} 差异@{i} 源={s!r} 库={g!r}")
    print(f"\n逐字符一致: {ok}/{ok + len(bad)}")

    # 未增强的课时也应存在且非空
    missing = [k for k, v in db.items() if not v.strip()]
    print(f"空内容课时: {missing if missing else '无'}")


if __name__ == "__main__":
    main()
