"""桌宠移动端适配验证（Playwright，iPhone 视口）。

验证项：
  1. 小屏下桌宠自动缩小（104px）
  2. 气泡改为 fixed 贴底全宽，不跟随桌宠
  3. 触摸拖拽可用
  4. 边界约束生效（拖不出视口）
  5. 无横向滚动条

用法: python scripts/verify_pet_mobile.py
"""
import json
import sys

from playwright.sync_api import sync_playwright

BASE = "http://127.0.0.1:5173"
SHOT = "docs/screenshots"

results = []


def check(name, ok, detail=""):
    results.append((name, ok, detail))
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f"  — {detail}" if detail else ""), flush=True)


def main():
    with sync_playwright() as p:
        browser = p.chromium.launch()
        # iPhone 13 尺寸
        page = browser.new_page(viewport={"width": 390, "height": 844},
                                is_mobile=True, has_touch=True,
                                user_agent="Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) "
                                           "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile Safari/604.1")
        errors = []
        page.on("pageerror", lambda e: errors.append(str(e)))

        page.goto(BASE, wait_until="networkidle")
        page.wait_for_timeout(1500)

        if page.locator("#pet-ask-input").count() == 0:
            page.fill('input[placeholder="3~32 个字符"]', "demo")
            pwd = page.locator('input[placeholder*="密码"]')
            if pwd.count() == 0:
                pwd = page.locator('input[type="password"]')
            pwd.fill("123456")
            page.click('button[type="submit"]')
            page.wait_for_timeout(2500)

        pet = page.locator(".pet-body")
        check("移动端桌宠存在", pet.count() > 0)
        if pet.count() == 0:
            browser.close()
            summarize()
            return

        box = pet.bounding_box()
        check("小屏自动缩小到 ~116px", 105 <= box["width"] <= 128, f"width={box['width']:.0f}")

        # 点击 → 气泡应 fixed 贴底
        pet.tap()
        page.wait_for_timeout(700)
        bubble = page.locator(".pet-bubble")
        check("气泡弹出", bubble.count() > 0 and bubble.is_visible())

        style = page.locator(".pet-bubble").evaluate(
            "el => { const s = getComputedStyle(el); const r = el.getBoundingClientRect();"
            " return { position: s.position, left: r.left, right: r.right, w: r.width }; }")
        check("气泡为 fixed 定位", style["position"] == "fixed", style["position"])
        check("气泡贴底全宽", style["left"] <= 13 and style["w"] >= 360,
              f"left={style['left']:.0f} width={style['w']:.0f}")

        page.screenshot(path=f"{SHOT}/pet-mobile-bubble.png")

        # 触摸拖拽
        before = pet.bounding_box()
        page.touchscreen.tap(before["x"] + before["width"] / 2,
                             before["y"] + before["height"] / 2)
        # 用 mouse 事件模拟 pointer 拖拽（Playwright 触摸拖拽需 dispatch）
        page.mouse.move(before["x"] + before["width"] / 2, before["y"] + before["height"] / 2)
        page.mouse.down()
        for i in range(1, 8):
            page.mouse.move(before["x"] + before["width"] / 2 - i * 20,
                            before["y"] + before["height"] / 2 - i * 25)
            page.wait_for_timeout(30)
        page.mouse.up()
        page.wait_for_timeout(700)
        after = pet.bounding_box()
        check("拖拽在移动端可用",
              abs(after["x"] - before["x"]) > 30 or abs(after["y"] - before["y"]) > 30,
              f"({before['x']:.0f},{before['y']:.0f}) → ({after['x']:.0f},{after['y']:.0f})")
        check("移动端也在视口内",
              after["x"] >= -1 and after["y"] >= -1
              and after["x"] + after["width"] <= 391 and after["y"] + after["height"] <= 845,
              f"x={after['x']:.0f} y={after['y']:.0f}")

        # 边界约束：拖到左上角外
        page.mouse.move(after["x"] + after["width"] / 2, after["y"] + after["height"] / 2)
        page.mouse.down()
        for i in range(1, 15):
            page.mouse.move(after["x"] + after["width"] / 2 - i * 60,
                            after["y"] + after["height"] / 2 - i * 60)
            page.wait_for_timeout(20)
        page.mouse.up()
        page.wait_for_timeout(900)
        clamped = pet.bounding_box()
        check("边界约束生效（拖不出视口）",
              clamped["x"] >= -1 and clamped["y"] >= 70,
              f"x={clamped['x']:.0f} y={clamped['y']:.0f}")

        # 无横向滚动
        hscroll = page.evaluate(
            "() => document.documentElement.scrollWidth - document.documentElement.clientWidth")
        check("无横向滚动条", hscroll <= 1, f"溢出 {hscroll}px")

        check("无 JS 报错", len(errors) == 0, "; ".join(errors[:2]))

        page.screenshot(path=f"{SHOT}/pet-mobile.png")
        browser.close()
    summarize()


def summarize():
    print("\n" + "=" * 56)
    passed = sum(1 for _, ok, _ in results if ok)
    print(f"结果：{passed}/{len(results)} 项通过")
    for name, ok, detail in results:
        if not ok:
            print(f"  ✗ {name}  {detail}")
    print("=" * 56)
    sys.exit(0 if passed == len(results) else 1)


if __name__ == "__main__":
    main()
