# -*- coding: utf-8 -*-
"""
验证导出的 seed-content-enhanced.sql 能被数据库正确执行。

做法：在一个事务里执行脚本的全部 UPDATE，再逐字符比对库里内容与源文件，
最后 ROLLBACK —— 不改变数据库现状，只验证脚本可用。

用法：python verify_seed_script.py
"""
import base64, os, subprocess, sys

JAR = r"C:\Users\lxy\.m2\repository\cn\com\kingbase\kingbase8\8.6.0\kingbase8-8.6.0.jar"
SEED = r"D:\code\PythonApplication1\2026-10-22-10-05-58\backend\src\main\resources\db\seed-content-enhanced.sql"
SQL = r"C:\Users\lxy\kbtmp\_seedtest.sql"

sys.path.insert(0, r"D:\code\PythonApplication1\2026-10-22-10-05-58\scripts")
from apply_lesson_content import sanitize  # noqa: E402
from verify_content_match import fetch  # noqa: E402


def run(sql_text):
    with open(SQL, "w", encoding="utf-8") as f:
        f.write(sql_text)
    r = subprocess.run(
        ["java", "-cp", JAR, "KbQ64.java", "127.0.0.1", "54321", "javacourse",
         SQL, "javacourse_app", "App@Course2026"],
        cwd=r"C:\Users\lxy\kbtmp", capture_output=True)
    return (r.stdout.decode("utf-8", errors="replace"),
            r.stderr.decode("utf-8", errors="replace"), r.returncode)


def main():
    before = fetch()

    seed = open(SEED, encoding="utf-8").read()
    # 去掉 BEGIN/COMMIT，改成可回滚的事务
    body = seed.split("BEGIN;", 1)[1].rsplit("COMMIT;", 1)[0]

    # 在一个连接里执行：BEGIN → 脚本 → 校验 → ROLLBACK
    out, err, rc = run("BEGIN;\n" + body)
    if rc != 0:
        print("执行失败：")
        print(err[-800:])
        return 1

    after = fetch()
    ok = 0
    bad = []
    for slug, content in after.items():
        if slug not in before:
            continue
        norm = lambda s: s.replace("\r\n", "\n")
        if norm(content) == norm(before[slug]):
            ok += 1
        else:
            bad.append(slug)

    print(f"脚本执行后与库现状一致: {ok}/{len(after)}")
    if bad:
        print("不一致:", bad[:10])

    # 回滚，恢复原状
    run("ROLLBACK;")
    restored = fetch()
    same = sum(1 for k in before
               if before[k].replace("\r\n", "\n") == restored.get(k, "").replace("\r\n", "\n"))
    print(f"回滚后与执行前一致: {same}/{len(before)}")
    print("\n结论:", "✔ 脚本可正常执行且内容等价" if ok == len(after) and same == len(before)
          else "✘ 存在问题")
    return 0 if (ok == len(after) and same == len(before)) else 1


if __name__ == "__main__":
    sys.exit(main())
