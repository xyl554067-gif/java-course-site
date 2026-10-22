"""桌宠端到端验证脚本（Playwright）。

验证项：
  1. 登录页 → 登录成功
  2. 桌宠出现在页面上，位置在视口内
  3. 待机动画 webm 实际加载并播放（currentTime > 0）
  4. 点击桌宠 → 对话气泡弹出
  5. 输入问题并发送 → 收到回答
  6. 拖拽桌宠 → 位置改变
  7. 刷新后位置被持久化
  8. 控制台无报错

用法: python scripts/verify_pet.py
"""
import json
import sys
import time

from playwright.sync_api import sync_playwright

BASE = "http://127.0.0.1:5173"
SHOT_DIR = "docs/screenshots"

results = []


def check(name, ok, detail=""):
    results.append((name, ok, detail))
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f"  — {detail}" if detail else ""), flush=True)
    return ok


def main():
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(viewport={"width": 1440, "height": 900})

        errors = []
        page.on("console", lambda m: errors.append(m.text) if m.type == "error" else None)
        page.on("pageerror", lambda e: errors.append(str(e)))

        # ---- 1. 登录 ----
        page.goto(BASE, wait_until="networkidle")
        page.wait_for_timeout(1200)
        if page.locator("#pet-ask-input").count() == 0:
            # 还在登录页
            inputs = page.locator("input")
            check("登录页渲染", inputs.count() > 0, f"input 数量 {inputs.count()}")
            # 登录表单没写 type 属性，按 placeholder 定位更稳
            page.fill('input[placeholder="3~32 个字符"]', "demo")
            pwd = page.locator('input[placeholder*="密码"]')
            if pwd.count() == 0:
                pwd = page.locator('input[type="password"]')
            pwd.fill("123456")
            page.click('button[type="submit"]')
            page.wait_for_timeout(2500)

        logged = page.locator(".nav__user").count() > 0
        check("登录成功（顶栏出现用户区）", logged)

        # ---- 2. 桌宠存在 ----
        pet = page.locator(".pet-body")
        check("桌宠元素存在", pet.count() > 0)

        if pet.count() == 0:
            page.screenshot(path=f"{SHOT_DIR}/pet-missing.png")
            browser.close()
            summarize()
            return

        box = pet.bounding_box()
        check("桌宠在视口内", box is not None and box["x"] >= 0
              and box["y"] >= 0 and box["x"] + box["width"] <= 1440
              and box["y"] + box["height"] <= 900,
              f"x={box['x']:.0f} y={box['y']:.0f} w={box['width']:.0f} h={box['height']:.0f}")
        check("桌宠在最上层（z-index 9999）",
              page.locator(".pet-layer").evaluate("el => getComputedStyle(el).zIndex") == "9999",
              page.locator(".pet-layer").evaluate("el => getComputedStyle(el).zIndex"))

        # ---- 3. 待机动画在播 ----
        page.wait_for_timeout(2500)
        vids = page.locator(".pet-video")
        playing = vids.evaluate_all(
            "els => els.map(v => ({src: v.currentSrc.split('/').pop(), t: v.currentTime, "
            "ready: v.readyState, paused: v.paused}))")
        active = [v for v in playing if not v["paused"] and v["t"] > 0]
        check("webm 动画实际播放中", len(active) > 0, json.dumps(playing, ensure_ascii=False))
        check("A/B 双缓冲（两个 video）", vids.count() == 2, f"video 数量 {vids.count()}")

        page.screenshot(path=f"{SHOT_DIR}/pet-idle.png")

        # ---- 4. 点击唤出气泡 ----
        pet.click()
        page.wait_for_timeout(800)
        bubble = page.locator(".pet-bubble")
        check("点击后气泡弹出", bubble.count() > 0 and bubble.is_visible())
        page.screenshot(path=f"{SHOT_DIR}/pet-bubble.png")

        # ---- 5. 提问 ----
        page.fill("#pet-ask-input", "int和long有什么区别")
        page.press("#pet-ask-input", "Enter")
        page.wait_for_timeout(4000)
        msgs = page.locator(".pet-msg--ai .pet-msg__body")
        answer = msgs.first.inner_text() if msgs.count() else ""
        check("收到回答", len(answer.strip()) > 10, f"{len(answer)} 字符: {answer[:90]}")

        tag = page.locator(".pet-bubble__tag")
        tag_text = tag.inner_text() if tag.count() else ""
        check("通道标识显示", tag_text in ("大模型", "本地兜底"), tag_text)

        cites = page.locator(".pet-cite")
        check("引用课时可点击", cites.count() > 0, f"{cites.count()} 条引用")

        page.screenshot(path=f"{SHOT_DIR}/pet-answer.png")

        # ---- 6. 拖拽 ----
        before = pet.bounding_box()
        page.mouse.move(before["x"] + before["width"] / 2, before["y"] + before["height"] / 2)
        page.mouse.down()
        for i in range(1, 11):
            page.mouse.move(before["x"] + before["width"] / 2 - i * 30,
                            before["y"] + before["height"] / 2 - i * 20)
            page.wait_for_timeout(30)
        page.mouse.up()
        page.wait_for_timeout(900)
        after = pet.bounding_box()
        moved = abs(after["x"] - before["x"]) > 50 or abs(after["y"] - before["y"]) > 50
        check("拖拽改变位置", moved,
              f"({before['x']:.0f},{before['y']:.0f}) → ({after['x']:.0f},{after['y']:.0f})")
        check("拖拽后仍在视口内",
              after["x"] >= 0 and after["y"] >= 0
              and after["x"] + after["width"] <= 1440 + 1
              and after["y"] + after["height"] <= 900 + 1,
              f"x={after['x']:.0f} y={after['y']:.0f}")

        page.screenshot(path=f"{SHOT_DIR}/pet-dragged.png")

        # ---- 7. 位置持久化 ----
        page.reload(wait_until="networkidle")
        page.wait_for_timeout(2000)
        pet2 = page.locator(".pet-body")
        check("刷新后仍在（已登录）", pet2.count() > 0)
        if pet2.count():
            b2 = pet2.bounding_box()
            same = abs(b2["x"] - after["x"]) < 30 and abs(b2["y"] - after["y"]) < 30
            check("位置已持久化", same,
                  f"存 ({after['x']:.0f},{after['y']:.0f}) vs 读 ({b2['x']:.0f},{b2['y']:.0f})")

        # ---- 8. 控制台无报错 ----
        real = [e for e in errors if "favicon" not in e.lower() and "404" not in e]
        check("控制台无 JS 报错", len(real) == 0, "; ".join(real[:3]))

        browser.close()
    summarize()


def summarize():
    print("\n" + "=" * 56)
    passed = sum(1 for _, ok, _ in results if ok)
    total = len(results)
    print(f"结果：{passed}/{total} 项通过")
    for name, ok, detail in results:
        if not ok:
            print(f"  ✗ {name}  {detail}")
    print("=" * 56)
    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
