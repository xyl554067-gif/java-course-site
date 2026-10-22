"""Java 练习模块 + AI 助教桌宠 端到端验证（Playwright）。

验证项：
  A. Java 练习模块
    1. 登录后进入「代码练习」页，习题列表加载
    2. 编辑器可输入代码（行号同步）
    3. 「▶ 运行」返回真实 stdout
    4. 故意写错代码 → 显示编译错误
    5. 制造运行异常 → 显示异常栈
    6. 「✓ 提交判题」返回逐条用例结果（正确答案 PASSED）
    7. 历史提交记录出现
    8. 课时页示例代码「▶ 运行」返回真实输出
    9. 「✎ 在编辑器中打开」跳转到练习页并带上代码
  B. AI 助教桌宠
    10. 桌宠常驻页面
    11. 点击唤起气泡 → 关闭 → 再次点击仍能唤起（生命周期修复）
    12. 关闭后历史对话保留（localStorage 持久化）
    13. 状态机不再卡在 dragging
    14. ⚙ 设置面板可打开，三种模式可切换
    15. 未配置直连时给出明确提示
    16. 刷新页面后历史仍在

用法: python scripts/verify_code_lab.py
"""
import json
import re
import os
import sys

from playwright.sync_api import sync_playwright

BASE = "http://127.0.0.1:5173"
SHOT_DIR = "docs/screenshots"
os.makedirs(SHOT_DIR, exist_ok=True)

results = []


def check(name, ok, detail=""):
    results.append((name, ok, detail))
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f"  — {detail}" if detail else ""), flush=True)
    return ok


def login(page):
    page.goto(BASE, wait_until="networkidle")
    page.wait_for_timeout(1200)
    if page.locator("#pet-ask-input").count() == 0:
        page.fill('input[placeholder="3~32 个字符"]', "demo")
        pwd = page.locator('input[placeholder*="密码"]')
        if pwd.count() == 0:
            pwd = page.locator('input[type="password"]')
        pwd.fill("123456")
        page.click('button[type="submit"]')
        page.wait_for_timeout(2500)
    return page.locator(".nav__user").count() > 0


def main():
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(viewport={"width": 1440, "height": 900})
        errors = []
        page.on("console", lambda m: errors.append(m.text) if m.type == "error" else None)
        page.on("pageerror", lambda e: errors.append(str(e)))

        # ================= 登录 =================
        check("登录成功（顶栏出现用户区）", login(page))

        # ================= A. Java 练习模块 =================
        print("\n--- A. Java 练习模块 ---", flush=True)
        page.goto(BASE + "/#/exercises", wait_until="networkidle")
        page.wait_for_timeout(2000)

        check("练习页加载", page.locator(".ex").count() > 0)
        items = page.locator(".ex__item")
        check("习题列表非空", items.count() > 0, f"习题数={items.count()}")

        env_ok = page.locator(".ex__alert--ok").count() > 0
        check("环境自检显示就绪", env_ok,
              page.locator(".ex__alert").first.inner_text()[:80] if page.locator(".ex__alert").count() else "")

        # 选中第一道题
        items.first.click()
        page.wait_for_timeout(1200)
        check("题面渲染", page.locator(".ex__title").count() > 0,
              page.locator(".ex__title").inner_text() if page.locator(".ex__title").count() else "")

        editor = page.locator(".ex__editor textarea")
        check("编辑器存在", editor.count() > 0)
        lines = page.locator(".editor__gutter .editor__ln")
        check("行号列存在", lines.count() > 0, f"行号数={lines.count()}")

        # --- 3. 写入正确代码并运行 ---
        good = """import java.util.Scanner;

public class Main {
    public static void main(String[] args) {
        Scanner sc = new Scanner(System.in);
        int n = sc.nextInt();
        int sum = 0;
        for (int i = 1; i <= n; i += 2) {
            sum += i;
        }
        System.out.println(sum);
    }
}
"""
        editor.fill(good)
        page.wait_for_timeout(300)
        # 填入 stdin（题目要求读入 n）
        stdin_box = page.locator(".ex__stdin-box")
        if stdin_box.count():
            stdin_box.fill("10")
        page.locator(".ex__toolbar button.btn--primary").click()
        page.wait_for_timeout(6000)
        out = page.locator(".ex__pre--out")
        out_text = out.first.inner_text() if out.count() else ""
        check("运行返回真实 stdout", "25" in out_text, f"输出={out_text.strip()[:60]!r}")
        check("显示成功状态", page.locator(".ex__status.is-pass").count() > 0,
              page.locator(".ex__status").first.inner_text() if page.locator(".ex__status").count() else "")
        page.screenshot(path=f"{SHOT_DIR}/lab-run-success.png")

        # --- 4. 编译错误 ---
        editor.fill('public class Main { public static void main(String[] a) { int x = "oops"; } }')
        page.wait_for_timeout(200)
        page.locator(".ex__toolbar button.btn--primary").click()
        page.wait_for_timeout(4000)
        err_pre = page.locator(".ex__pre--err")
        err_text = err_pre.first.inner_text() if err_pre.count() else ""
        check("编译错误可见", ("错误" in err_text) or ("error" in err_text.lower()),
              err_text.strip()[:90].replace("\n", " "))
        check("编译错误无乱码", "�" not in err_text, "含替换字符" if "�" in err_text else "干净")
        page.screenshot(path=f"{SHOT_DIR}/lab-compile-error.png")

        # --- 5. 运行异常 ---
        editor.fill("""public class Main {
    public static void main(String[] args) {
        String s = null;
        System.out.println(s.length());
    }
}
""")
        page.wait_for_timeout(200)
        page.locator(".ex__toolbar button.btn--primary").click()
        page.wait_for_timeout(4000)
        err_text = ""
        if page.locator(".ex__pre--err").count():
            err_text = page.locator(".ex__pre--err").first.inner_text()
        check("异常栈可见", "NullPointerException" in err_text,
              err_text.strip()[:90].replace("\n", " "))

        # --- 6. 提交判题（正确答案） ---
        editor.fill(good)
        page.wait_for_timeout(200)
        if stdin_box.count():
            stdin_box.fill("10")
        page.locator(".ex__toolbar button.btn--sun").click()
        page.wait_for_timeout(12000)
        cases = page.locator(".ex__case")
        check("判题返回逐条用例", cases.count() > 0, f"用例数={cases.count()}")
        # 判题结果块是带 .ex__score 的那个（运行结果块没有）
        judge_block = page.locator(".ex__result").filter(has=page.locator(".ex__score"))
        check("判题结果块渲染", judge_block.count() > 0)
        judge_text = judge_block.first.inner_text() if judge_block.count() else ""
        check("判题结果为通过", "判题通过" in judge_text, judge_text.replace("\n", " ")[:90])
        check("显示用例通过比例", re.search(r"\d+\s*/\s*\d+\s*用例通过", judge_text) is not None,
              (re.search(r"\d+\s*/\s*\d+\s*用例通过", judge_text) or [""])[0])
        page.screenshot(path=f"{SHOT_DIR}/lab-judge-passed.png")

        # --- 7. 历史提交 ---
        hist = page.locator(".ex__hist, .ex__submissions, .ex__history")
        check("历史提交区域存在", hist.count() > 0,
              f"匹配到 {hist.count()} 个历史区块")
        page.screenshot(path=f"{SHOT_DIR}/lab-history.png", full_page=True)

        # --- 8. 课时页示例运行 ---
        page.goto(BASE + "/", wait_until="networkidle")
        page.wait_for_timeout(1500)
        lesson_link = page.locator("a[href*='/lesson/']").first
        if lesson_link.count():
            lesson_link.click()
            page.wait_for_timeout(2500)
        snip_run = page.locator(".snip__actions button", has_text="运行").first
        check("课时页示例有运行按钮", snip_run.count() > 0)
        if snip_run.count():
            snip_run.click()
            page.wait_for_timeout(6000)
            snip_out = page.locator(".snip__pre--out")
            snip_text = snip_out.first.inner_text() if snip_out.count() else ""
            check("示例代码真实运行出结果", len(snip_text.strip()) > 0, f"输出={snip_text.strip()[:60]!r}")
            page.screenshot(path=f"{SHOT_DIR}/lesson-snippet-run.png")

        # --- 9. 在编辑器中打开 ---
        open_btn = page.locator(".snip__actions button", has_text="在编辑器中打开").first
        if open_btn.count():
            open_btn.click()
            page.wait_for_timeout(2500)
            check("跳转到练习页", "/exercise" in page.url, page.url)
            ed = page.locator(".ex__editor textarea")
            val = ed.input_value() if ed.count() else ""
            check("代码已带入编辑器", len(val.strip()) > 20, f"{len(val)} 字符")

        # ================= B. AI 助教桌宠 =================
        print("\n--- B. AI 助教桌宠 ---", flush=True)
        page.goto(BASE + "/#/exercises", wait_until="networkidle")
        page.wait_for_timeout(2000)

        pet = page.locator(".pet-body")
        check("桌宠常驻页面", pet.count() > 0)
        box = pet.bounding_box() if pet.count() else None
        check("桌宠在视口内", box is not None and box["x"] >= 0 and box["y"] >= 0)

        # 清空历史，保证第 12 步能观察到「保留」
        page.evaluate("() => localStorage.removeItem('javacourse.pet.history')")
        page.reload(wait_until="networkidle")
        page.wait_for_timeout(2000)

        # --- 11. 点击 → 关闭 → 再点击 ---
        pet.click()
        page.wait_for_timeout(900)
        check("第一次点击弹出气泡", page.locator(".pet-bubble").count() > 0
              and page.locator(".pet-bubble").is_visible())

        # 发一条消息
        page.fill("#pet-ask-input", "int和long有什么区别")
        page.press("#pet-ask-input", "Enter")
        page.wait_for_timeout(5000)
        msgs = page.locator(".pet-msg--ai .pet-msg__body")
        check("桌宠回复了", msgs.count() > 0,
              msgs.first.inner_text()[:60].replace("\n", " ") if msgs.count() else "")

        # 关闭
        page.locator(".pet-bubble__close").click()
        page.wait_for_timeout(800)
        check("关闭后气泡隐藏", not page.locator(".pet-bubble").is_visible())

        # 再次点击
        pet.click()
        page.wait_for_timeout(900)
        check("关闭后可再次唤起", page.locator(".pet-bubble").count() > 0
              and page.locator(".pet-bubble").is_visible())

        # --- 12. 历史保留 ---
        kept = page.locator(".pet-msg").count()
        check("再次打开历史对话仍在", kept >= 2, f"消息数={kept}")
        ls = page.evaluate("() => localStorage.getItem('javacourse.pet.history') || ''")
        check("历史已写入 localStorage", len(ls) > 20, f"{len(ls)} 字符")
        page.screenshot(path=f"{SHOT_DIR}/pet-reopen-history.png")

        # --- 13. 状态机不再卡 dragging ---
        state = pet.get_attribute("class") or ""
        check("状态机回到 idle（未卡 dragging）", "dragging" not in state, state[:90])

        # --- 14/15. 设置面板 ---
        page.locator(".pet-bubble__icon").click()
        page.wait_for_timeout(700)
        check("设置面板打开", page.locator(".pet-settings").count() > 0
              and page.locator(".pet-settings").is_visible())
        sel = page.locator(".pet-settings__select")
        opts = sel.locator("option").all_text_contents() if sel.count() else []
        check("三种接入模式可切换", len(opts) == 3, f"选项={opts}")
        # 切到 direct 模式，看未配置时的提示
        sel.select_option(index=1)
        page.wait_for_timeout(500)
        warn = page.locator(".pet-settings__warn")
        warn_text = warn.inner_text() if warn.count() else ""
        check("直连未配置有明确提示", len(warn_text.strip()) > 10, warn_text.strip()[:80])
        # 切到 local 模式保存
        sel.select_option(index=2)
        page.locator(".pet-btn--primary").click()
        page.wait_for_timeout(600)
        cfg = page.evaluate("() => localStorage.getItem('javacourse.pet.aiConfig') || ''")
        check("配置已持久化", "local" in cfg, cfg[:100])
        page.screenshot(path=f"{SHOT_DIR}/pet-settings.png")

        # --- 16. 刷新后历史仍在 ---
        page.reload(wait_until="networkidle")
        page.wait_for_timeout(2000)
        pet.click()
        page.wait_for_timeout(900)
        after = page.locator(".pet-msg").count()
        check("刷新后历史仍保留", after >= 2, f"消息数={after}")
        page.screenshot(path=f"{SHOT_DIR}/pet-after-reload.png")

        # --- 17. direct 模式未配置 API Key → 明确提示 ---
        page.locator(".pet-bubble__icon").click()
        page.wait_for_timeout(600)
        sel.select_option(index=1)
        page.wait_for_timeout(300)
        # 清空地址与 Key
        for cls in (".pet-settings__input",):
            fields = page.locator(cls)
            for i in range(fields.count()):
                fields.nth(i).fill("")
        page.locator(".pet-btn--primary").click()
        page.wait_for_timeout(600)
        page.fill("#pet-ask-input", "测试未配置直连时的提示")
        page.press("#pet-ask-input", "Enter")
        page.wait_for_timeout(5000)
        ai_body = page.locator(".pet-msg--ai .pet-msg__body")
        last_text = ai_body.last.inner_text() if ai_body.count() else ""
        check("未配置直连时给出明确引导", ("还没接上" in last_text) or ("API Key" in last_text),
              last_text.replace("\n", " ")[:100])
        page.screenshot(path=f"{SHOT_DIR}/pet-direct-unconfigured.png")
        # 恢复默认
        page.locator(".pet-bubble__icon").click()
        page.wait_for_timeout(500)
        page.locator(".pet-btn--ghost").first.click()
        page.wait_for_timeout(500)
        cfg2 = page.evaluate("() => localStorage.getItem('javacourse.pet.aiConfig') || ''")
        check("恢复默认可用", "backend" in cfg2, cfg2[:100])

        # --- 控制台错误 ---
        real_errors = [e for e in errors if "favicon" not in e.lower() and "404" not in e]
        check("控制台无严重报错", len(real_errors) == 0, "; ".join(real_errors[:3]))

        browser.close()

    print()
    failed = [r for r in results if not r[1]]
    if failed:
        print(f"✗ 失败 {len(failed)}/{len(results)} 项:")
        for name, _, detail in failed:
            print(f"    - {name}  {detail}")
        sys.exit(1)
    print(f"✓ 全部通过（{len(results)} 项）")


if __name__ == "__main__":
    main()