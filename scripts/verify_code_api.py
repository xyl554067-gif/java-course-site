#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""后端代码实验室接口端到端验证：登录 -> 环境自检 -> 运行/编译错误/异常/超时 -> 判题"""
import json
import urllib.request
import urllib.error

# 本机有http_proxy 环境变量会劫持 localhost 请求，这里强制直连
for _k in ("http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY", "all_proxy", "ALL_PROXY"):
    urllib.request.getproxies_environment = urllib.request.getproxies_environment
    import os
    os.environ.pop(_k, None)
_opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
urllib.request.install_opener(_opener)

BASE = "http://127.0.0.1:8080/api"
TOKEN = ""


def call(method, path, body=None, timeout=180):
    global TOKEN
    url = BASE + path
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if TOKEN:
        req.add_header("Authorization", "Bearer " + TOKEN)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            raw = r.read().decode("utf-8", "replace")
            return r.status, json.loads(raw)
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", "replace")
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, {"raw": raw[:400]}


def check(name, cond, detail=""):
    print(("  [PASS] " if cond else "  [FAIL] ") + name + (" | " + detail if detail else ""))
    if not cond:
        FAILURES.append(name)
    return cond


FAILURES = []


def fetch_solution(slug):
    """从数据库取参考答案（不下发前端的字段），用于验证判题能判 PASSED"""
    try:
        import importlib.util
        import os
        here = os.path.dirname(os.path.abspath(__file__))
        seed_path = os.path.join(os.path.dirname(here), "scripts", "seed_code_lab.py")
        if not os.path.exists(seed_path):
            seed_path = os.path.join(here, "seed_code_lab.py")
        spec = importlib.util.spec_from_file_location("seed_code_lab", seed_path)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        rows = mod.kb_query(
            "SELECT replace(replace(solution_code, chr(13), ''), chr(10), '<NL>') "
            "FROM code_exercise WHERE slug = '%s'" % slug)
        if not rows or not rows[0]:
            return None
        return "\n".join(rows[0]).replace("<NL>", "\n")
    except Exception as e:
        print("     (取参考答案失败：%s)" % e)
        return None

print("== 1. 登录")
st, r = call("POST", "/auth/login", {"username": "admin", "password": "123456"})
TOKEN = (r.get("data") or {}).get("token", "")
check("登录成功并取得 token", st == 200 and bool(TOKEN), f"status={st} token={TOKEN[:24]}...")

print("== 2. GET /code/runtime")
st, r = call("GET", "/code/runtime")
data = r.get("data", r)
ok = st == 200 and data.get("javac") and data.get("ready") is not False
check("环境自检返回 javac 路径", ok, json.dumps(data, ensure_ascii=False)[:260])

print("== 3. POST /code/run 成功路径（含中文输出）")
code_ok = """public class Main {
    public static void main(String[] args) {
        System.out.println("你好，Java 课程平台");
        int sum = 0;
        for (int i = 1; i <= 100; i++) sum += i;
        System.out.println("1..100 之和 = " + sum);
    }
}
"""
st, r = call("POST", "/code/run", {"code": code_ok})
d = r.get("data", r)
check("运行成功", d.get("status") == "SUCCESS", str(d.get("status")))
check("中文输出未乱码", "你好，Java 课程平台" in (d.get("stdout") or ""), repr((d.get("stdout") or "")[:60]))
check("求和结果正确 5050", "5050" in (d.get("stdout") or ""))

print("== 4. POST /code/run 编译错误路径")
st, r = call("POST", "/code/run", {"code": "public class Main { public static void main(String[] a) { int x = \"oops\"; } }"})
d = r.get("data", r)
check("状态为 COMPILE_ERROR", d.get("status") == "COMPILE_ERROR", str(d.get("status")))
check("返回编译错误文本", "错误" in (d.get("output") or "") or "error" in (d.get("output") or "").lower(),
      repr((d.get("output") or "")[:120]))

print("== 5. POST /code/run 运行异常路径")
st, r = call("POST", "/code/run", {"code": """public class Main {
    public static void main(String[] args) {
        String s = null;
        System.out.println(s.length());
    }
}
"""})
d = r.get("data", r)
check("状态为 RUNTIME_ERROR", d.get("status") == "RUNTIME_ERROR", str(d.get("status")))
check("stderr 含异常名", "NullPointerException" in (d.get("stderr") or ""), repr((d.get("stderr") or "")[:120]))

print("== 6. POST /code/run 标准输入")
st, r = call("POST", "/code/run", {
    "code": """import java.util.Scanner;
public class Main {
    public static void main(String[] args) {
        Scanner sc = new Scanner(System.in);
        System.out.println("收到: " + sc.nextLine().toUpperCase());
    }
}
""", "stdin": "hello code lab"})
d = r.get("data", r)
check("stdin 生效", d.get("status") == "SUCCESS" and "收到: HELLO CODE LAB" in (d.get("stdout") or ""),
      repr((d.get("stdout") or "")[:80]))

print("== 7. POST /code/run 超时路径")
st, r = call("POST", "/code/run", {
    "code": "public class Main { public static void main(String[] a) throws Exception { while(true) Thread.sleep(50); } }"})
d = r.get("data", r)
check("状态为 TIMEOUT", d.get("status") == "TIMEOUT", str(d.get("status")))

print("== 8. GET /code/exercises")
st, r = call("GET", "/code/exercises")
data = r.get("data", r)
items = data if isinstance(data, list) else data.get("items", [])
check("习题列表非空", len(items) > 0, f"count={len(items)}")
ex = None
for it in items:
    if it.get("slug"):
        ex = it
        break
exid = ex.get("id") if ex else None
print("     首个习题:", ex.get("title") if ex else None, "id=", exid)

print("== 9. GET /code/exercises/{slug} 不泄露答案")
if ex:
    st, r = call("GET", "/code/exercises/" + ex["slug"])
    d = r.get("data", r)
    check("返回题面与起始代码", bool(d.get("starterCode")) or bool(d.get("title")))
    check("参考答案未下发", "solutionCode" not in d, str(list(d.keys()))[:200])
    try:
        tc = json.loads(d.get("testCases") or "[]")
    except Exception:
        tc = []
    check("测试用例可解析", isinstance(tc, list) and len(tc) > 0, f"用例数={len(tc)}")
    print("     用例数:", len(tc), "首条:", (tc[0].get("name") if tc else None))

print("== 10. POST /code/submit 判题——错误答案（应 FAILED）")
if exid:
    st, r = call("POST", "/code/submit", {
        "exerciseId": exid,
        "code": "public class Main { public static void main(String[] a){ System.out.println(999); } }"})
    d = r.get("data", r)
    check("状态为 FAILED", d.get("status") == "FAILED", f"{d.get('status')} | {d.get('message')}")
    check("返回逐条用例结果", len(d.get("cases") or []) > 0, f"cases={len(d.get('cases') or [])}")
    check("落库通过数为 0", d.get("passedCount") == 0, str(d.get("passedCount")))

print("== 11. POST /code/submit 判题——参考答案（应 PASSED）")
if ex:
    # 参考答案存在数据库中、不下发前端；这里直接查库取来做判题验证
    sol = fetch_solution(ex["slug"])
    if sol:
        st, r = call("POST", "/code/submit", {"exerciseId": ex["id"], "code": sol})
        d = r.get("data", r)
        check("参考答案判题通过", d.get("status") == "PASSED", f"{d.get('status')} | {d.get('message')}")
    else:
        check("取到参考答案", False, "数据库中未取到 solution_code")

print("== 12. GET /code/submissions 历史提交")
st, r = call("GET", "/code/submissions")
data = r.get("data", r)
subs = data if isinstance(data, list) else data.get("items", [])
check("有提交记录", len(subs) > 0, f"count={len(subs)}")
if subs:
    print("     最近一条:", subs[0].get("status"), subs[0].get("exerciseTitle"))

print()
if FAILURES:
    print(f"✗ 失败 {len(FAILURES)} 项: " + "; ".join(FAILURES))
else:
    print("✓ 全部通过")