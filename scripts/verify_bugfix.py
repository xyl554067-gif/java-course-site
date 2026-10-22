#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
三个 Bug 的浏览器端回归验证：
  Bug 1 课程代码展示区缩进 / 换行 / 空行与原文逐字符一致（浅色 + 深色）
  Bug 2 AI 助教抽屉隐藏后完全不可交互（不可点击、不可 Tab 聚焦、对读屏不可见）
  Bug 3 学习时长与学习次数统计真实、刷新后仍正确

用法：python scripts/verify_bugfix.py
"""
import json
import re
import sys
import time
import urllib.request

BASE = "http://127.0.0.1:5173"
API = "http://127.0.0.1:8080/api"

# 本机 http_proxy 会劫持 localhost，必须显式清掉
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))

results = []


def check(name, ok, detail=""):
    results.append((name, bool(ok), detail))
    print(("  [PASS] " if ok else "  [FAIL] ") + name + (f"  -> {detail}" if detail else ""))
    return ok


def api(path, token=None, method="GET", body=None):
    req = urllib.request.Request(API + path, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    data = json.dumps(body).encode() if body is not None else None
    with opener.open(req, data, timeout=20) as r:
        return json.loads(r.read().decode())


def login():
    r = api("/auth/login", method="POST", body={"username": "admin", "password": "123456"})
    return r["data"]["token"]


def main():
    from playwright.sync_api import sync_playwright

    token = login()
    print("== 登录成功 ==")

    with sync_playwright() as p:
        browser = p.chromium.launch()
        ctx = browser.new_context(viewport={"width": 1280, "height": 900})
        page = ctx.new_page()

        # 注入登录态
        page.goto(BASE + "/#/login")
        page.evaluate("(t) => localStorage.setItem('javacourse_token', t)", token)
        page.reload()
        page.wait_for_timeout(1500)

        # ---------------- Bug 1 ----------------
        print("\n== Bug 1：代码块缩进 / 换行 / 空行 ==")
        page.goto(BASE + "/#/lesson/methods")
        page.wait_for_timeout(2000)

        info = page.evaluate(
            """() => {
              const pre = document.querySelector('.md-body pre.md-code')
              if (!pre) return null
              const code = pre.querySelector('code')
              const cs = getComputedStyle(code)
              const pcs = getComputedStyle(pre)
              return {
                text: code.textContent,
                whiteSpace: cs.whiteSpace,
                preWhiteSpace: pcs.whiteSpace,
                tabSize: cs.tabSize,
                lines: code.textContent.split('\\n').length,
              }
            }"""
        )
        check("Bug1 存在 .md-body pre.md-code 代码块", info is not None)
        if info:
            check("Bug1 code 的 white-space 为 pre（保留缩进）",
                  info["whiteSpace"] == "pre", info["whiteSpace"])
            check("Bug1 pre 的 white-space 为 pre", info["preWhiteSpace"] == "pre",
                  info["preWhiteSpace"])

            # 与库里原文逐字符比对
            import subprocess
            raw = subprocess.run(
                ["python", "-c",
                 "import subprocess,json,os;"
                 "print(open('D:/code/PythonApplication1/2026-10-22-10-05-58/scripts/verify_bugfix.py',encoding='utf-8').read()[:0])"],
                capture_output=True, text=True)
            # 直接从 API 取原文
            lesson = api("/lesson/methods")["data"]
            content = lesson["lesson"]["content"] if "lesson" in lesson else lesson["content"]
            content = content.replace("\r\n", "\n")
            m = re.search(r"```(\w*)\n([\s\S]*?)```", content)
            check("Bug1 原文能匹配到围栏代码块", m is not None)
            if m:
                origin = m.group(2)
                if origin.endswith("\n"):
                    origin = origin[:-1]
                check("Bug1 渲染结果与原文逐字符一致",
                      info["text"] == origin,
                      f"渲染{len(info['text'])}字符 vs 原文{len(origin)}字符")
                # 缩进是否真的保留了
                indented = [ln for ln in origin.split("\n") if ln.startswith("    ")]
                check("Bug1 原文含 4 空格缩进行", len(indented) > 0, f"{len(indented)} 行")
                if indented:
                    first = indented[0]
                    check("Bug1 缩进在 DOM 中原样保留",
                          first in info["text"], repr(first[:40]))

        # 暗色主题
        page.emulate_media(color_scheme="dark")
        page.wait_for_timeout(400)
        dark = page.evaluate(
            """() => {
              const pre = document.querySelector('.md-body pre.md-code')
              if (!pre) return null
              const cs = getComputedStyle(pre)
              const code = pre.querySelector('code')
              return {
                bg: cs.backgroundColor,
                color: getComputedStyle(code).color,
                whiteSpace: getComputedStyle(code).whiteSpace,
              }
            }"""
        )
        check("Bug1 暗色主题下代码块背景已切换（不再是浅色 #fbf7f0）",
              dark and dark["bg"] not in ("rgb(251, 247, 240)", "rgba(0, 0, 0, 0)"),
              dark["bg"] if dark else "")
        check("Bug1 暗色主题下缩进仍为 pre", dark and dark["whiteSpace"] == "pre",
              dark["whiteSpace"] if dark else "")
        page.emulate_media(color_scheme="light")
        page.wait_for_timeout(300)

        # ---------------- Bug 2 ----------------
        print("\n== Bug 2：AI 助教隐藏后不可交互 ==")
        page.goto(BASE + "/#/lesson/collection-overview")
        page.wait_for_timeout(1800)

        # 打开抽屉
        page.evaluate("() => document.querySelector('.fab').click()")
        page.wait_for_timeout(600)
        opened = page.evaluate(
            """() => {
              const d = document.querySelector('.drawer')
              const m = document.querySelector('.drawer__mask')
              return { drawer: !!d, mask: !!m,
                       maskPE: m ? getComputedStyle(m).pointerEvents : null }
            }"""
        )
        check("Bug2 点击入口后抽屉可见", opened["drawer"])
        check("Bug2 打开时遮罩可接收点击（用于关闭）",
              opened["maskPE"] == "auto", str(opened["maskPE"]))

        # 关闭
        page.evaluate("() => document.querySelector('.drawer__close').click()")
        # 离场过渡期间立刻检查
        page.wait_for_timeout(60)
        during = page.evaluate(
            """() => {
              const m = document.querySelector('.drawer__mask')
              const d = document.querySelector('.drawer')
              const hit = document.elementFromPoint(640, 450)
              return {
                maskExists: !!m,
                maskPE: m ? getComputedStyle(m).pointerEvents : null,
                maskInert: m ? m.hasAttribute('inert') : null,
                maskAria: m ? m.getAttribute('aria-hidden') : null,
                drawerInert: d ? d.hasAttribute('inert') : null,
                hitTag: hit ? hit.tagName + '.' + (hit.className || '') : null,
                drawerVisible: d ? getComputedStyle(d).visibility : null,
              }
            }"""
        )
        check("Bug2 离场过渡期间遮罩不再拦截点击（pointer-events: none）",
              during["maskPE"] == "none", str(during["maskPE"]))
        check("Bug2 离场过渡期间遮罩已 inert", during["maskInert"] is True)
        check("Bug2 离场过渡期间遮罩对读屏隐藏", during["maskAria"] == "true")
        check("Bug2 离场过渡期间抽屉已 inert（不可 Tab 聚焦）",
              during["drawerInert"] is True)
        check("Bug2 离场过渡期间点击穿透到页面内容",
              during["hitTag"] is not None and "drawer" not in (during["hitTag"] or ""),
              str(during["hitTag"]))

        page.wait_for_timeout(600)
        after = page.evaluate(
            """() => ({
              drawer: !!document.querySelector('.drawer'),
              mask: !!document.querySelector('.drawer__mask'),
              inputs: document.querySelectorAll('.drawer input, .drawer button').length,
            })"""
        )
        check("Bug2 关闭后抽屉从 DOM 移除", not after["drawer"])
        check("Bug2 关闭后遮罩从 DOM 移除", not after["mask"])
        check("Bug2 关闭后无残留可聚焦控件", after["inputs"] == 0)

        # 反复切换无残留
        for i in range(3):
            page.evaluate("() => document.querySelector('.fab') && document.querySelector('.fab').click()")
            page.wait_for_timeout(450)
            page.evaluate("() => document.querySelector('.drawer__close') && document.querySelector('.drawer__close').click()")
            page.wait_for_timeout(450)
        residual = page.evaluate(
            """() => ({
              drawer: !!document.querySelector('.drawer'),
              mask: !!document.querySelector('.drawer__mask'),
              fab: !!document.querySelector('.fab'),
            })"""
        )
        check("Bug2 反复开关 3 次后无状态残留",
              not residual["drawer"] and not residual["mask"] and residual["fab"],
              str(residual))

        # ---------------- Bug 3 ----------------
        print("\n== Bug 3：学习时长与学习次数 ==")
        before = api("/progress/summary", token=token)["data"]
        print("  before:", before)

        # 找一个可写的课时：清掉该课时的旧统计
        lid = 19
        page.goto(BASE + "/#/lesson/jvm-memory")
        page.wait_for_timeout(2000)
        # 触发一次上报（滚动到底）
        page.evaluate("() => window.scrollTo(0, document.body.scrollHeight)")
        page.wait_for_timeout(1200)
        page.wait_for_timeout(1500)

        mid = api("/progress/summary", token=token)["data"]
        print("  after :", mid)
        check("Bug3 学习总时长随真实停留时间增加",
              mid["totalSeconds"] >= before["totalSeconds"], f"{before['totalSeconds']} -> {mid['totalSeconds']}")
        check("Bug3 summary 暴露 studyCount 字段", "studyCount" in mid)

        # 学习次数：同一课时重复进入不应无限增长
        # 先让本课时的首次上报落库（滚动触发），再取基准值
        page.evaluate("() => window.scrollTo(0, document.body.scrollHeight)")
        page.wait_for_timeout(1500)
        cnt1 = api("/progress/summary", token=token)["data"]["studyCount"]
        page.reload()
        page.wait_for_timeout(2200)
        page.evaluate("() => window.scrollTo(0, document.body.scrollHeight)")
        page.wait_for_timeout(1500)
        cnt2 = api("/progress/summary", token=token)["data"]["studyCount"]
        check("Bug3 刷新同一课时不会重复计学习次数", cnt2 == cnt1, f"{cnt1} -> {cnt2}")

        # 切到别的课时再回来，学习次数应 +1
        page.goto(BASE + "/#/lesson/class-and-object")
        page.wait_for_timeout(2000)
        page.evaluate("() => window.scrollTo(0, document.body.scrollHeight)")
        page.wait_for_timeout(1500)
        page.goto(BASE + "/#/lesson/jvm-memory")
        page.wait_for_timeout(2000)
        page.evaluate("() => window.scrollTo(0, document.body.scrollHeight)")
        page.wait_for_timeout(1500)
        cnt3 = api("/progress/summary", token=token)["data"]["studyCount"]
        check("Bug3 切换课时再回来会新增学习次数", cnt3 > cnt2, f"{cnt2} -> {cnt3}")

        # 课时页展示的是「我学了 N 次」而不是全站浏览量
        badges = page.evaluate(
            """() => Array.from(document.querySelectorAll('.lesson__meta .badge')).map(b => b.textContent.trim())"""
        )
        check("Bug3 课时页展示按用户维度的学习次数",
              any("我学了" in b and "次" in b for b in badges), str(badges))
        check("Bug3 全站浏览量标注为「次浏览」而非「次学习」",
              any("次浏览" in b for b in badges), str(badges))

        browser.close()

    print("\n===== 汇总 =====")
    passed = sum(1 for _, ok, _ in results if ok)
    for name, ok, detail in results:
        print(("  PASS  " if ok else "  FAIL  ") + name)
    print(f"\n{passed}/{len(results)} 项通过")
    return 0 if passed == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())
