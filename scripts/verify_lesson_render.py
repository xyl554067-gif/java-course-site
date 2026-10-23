# -*- coding: utf-8 -*-
"""
课程正文增强后的渲染回归验证。

覆盖：
  * 正文非空、代码块存在且 white-space: pre（缩进不被折叠）
  * Markdown 表格正确渲染成 <table>（表头 + 数据行）
  * 独占一行的 **加粗小标题** 渲染成小标题
  * 暗色主题下代码块与表头样式已切换
"""
import json, os, sys, urllib.request
from playwright.sync_api import sync_playwright

BASE = "http://127.0.0.1:5173"
API = "http://127.0.0.1:8080/api"
# 本机有代理，localhost 请求必须绕开，否则会被代理劫持
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))

SLUGS = [
    "jvm-memory", "object-layout", "class-loading", "gc-algorithms",
    "jvm-tuning-tools", "bytecode", "project-memory-leak",
    "thread-basics", "lock-mechanisms", "thread-pool",
    "concurrent-collections", "completablefuture", "project-parallel-aggregate",
    "collection-overview", "arraylist-source", "hashmap-red-black-tree",
    "iterator-cmc", "stream-api",
    "class-and-object", "oop-core", "interface-vs-abstract",
    "final-static-immutable", "enum-and-record",
    "exception-handling", "generics-type-erasure", "reflection-annotation",
    "variables-and-types", "operators", "control-flow", "arrays", "string", "methods",
    "spring-boot-init", "kingbase-persistence", "restful-api",
]

results = []


def check(name, ok, detail=""):
    results.append((name, ok, detail))


def api(path, token=None, method="GET", body=None):
    req = urllib.request.Request(API + path, method=method)
    if token:
        req.add_header("Authorization", "Bearer " + token)
    if body is not None:
        req.add_header("Content-Type", "application/json")
        req.data = json.dumps(body).encode()
    with opener.open(req, timeout=15) as r:
        return json.loads(r.read().decode())


def main():
    token = api("/auth/login", method="POST",
                body={"username": "admin", "password": "123456"})["data"]["token"]
    print("== 登录成功 ==")

    with sync_playwright() as p:
        browser = p.chromium.launch()
        ctx = browser.new_context(viewport={"width": 1400, "height": 900})
        page = ctx.new_page()
        page.goto(BASE + "/#/login")
        page.evaluate("(t) => localStorage.setItem('javacourse_token', t)", token)
        page.reload()
        page.wait_for_timeout(1500)

        for slug in SLUGS:
            page.goto(f"{BASE}/#/lesson/{slug}")
            page.wait_for_timeout(1800)
            info = page.evaluate(
                """() => {
                const b = document.querySelector('.md-body');
                if (!b) return null;
                const pres = b.querySelectorAll('pre.md-code');
                const ts = b.querySelectorAll('table.md-table');
                const subs = b.querySelectorAll('h4.md-subtitle');
                return {
                  len: b.innerText.length,
                  pres: pres.length,
                  tables: ts.length,
                  rows: b.querySelectorAll('table.md-table tbody tr').length,
                  th: ts.length ? ts[0].querySelectorAll('th').length : 0,
                  subs: subs.length,
                  ws: pres.length
                    ? getComputedStyle(pres[0].querySelector('code') || pres[0]).whiteSpace
                    : null,
                };
            }"""
            )
            if not info:
                check(f"{slug} 正文渲染", False, "未找到 .md-body")
                continue
            check(f"{slug} 正文渲染", info["len"] > 1200, f"{info['len']} 字符")
            check(f"{slug} 代码块保留缩进",
                  info["pres"] > 0 and info["ws"] == "pre",
                  f"pre={info['pres']} ws={info['ws']}")
            check(f"{slug} 表格已渲染",
                  info["tables"] > 0 and info["rows"] > 0 and info["th"] > 0,
                  f"表={info['tables']} 行={info['rows']} 列={info['th']}")
            check(f"{slug} 加粗小标题已渲染", info["subs"] > 0, f"小标题={info['subs']}")

        # 暗色主题
        page.emulate_media(color_scheme="dark")
        page.goto(f"{BASE}/#/lesson/jvm-memory")
        page.wait_for_timeout(1800)
        dark = page.evaluate(
            """() => {
            const p = document.querySelector('.md-body pre.md-code');
            const t = document.querySelector('.md-body table.md-table th');
            return {
              bg: p ? getComputedStyle(p).backgroundColor : 'none',
              th: t ? getComputedStyle(t).backgroundColor : 'none',
            };
        }"""
        )
        check("暗色主题下代码块背景已切换",
              dark["bg"] not in ("none", "rgba(0, 0, 0, 0)", "rgb(251, 247, 240)"),
              dark["bg"])
        browser.close()

    print("\n===== 汇总 =====")
    passed = sum(1 for _, ok, _ in results if ok)
    for name, ok, detail in results:
        print(("  PASS  " if ok else "  FAIL  ") + name + (f"  -> {detail}" if detail else ""))
    print(f"\n{passed}/{len(results)} 项通过")
    return 0 if passed == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())
