"""
GitHub Pages 线上站点验证脚本（子路径部署专用）。

与 verify_pet.py 的差异：
  * 目标是线上 https://<user>.github.io/<repo>/ ，不是本地 dev server
  * 重点验证「子路径部署」容易出错的点：静态资源相对路径、webm 动画加载、
    图片资源加载、控制台无 404/报错
  * 不做登录（线上环境 API 未部署，登录会失败）——改为验证公开可访问的路由

用法：
  python scripts/verify_pages.py
  python scripts/verify_pages.py --url https://xxx.github.io/yyy/
"""

import argparse
import sys

from playwright.sync_api import sync_playwright

PASS, FAIL = "\033[92m✔ PASS\033[0m", "\033[91m�’ FAIL\033[0m"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--url",
        default="https://xyl554067-gif.github.io/java-course-site/",
        help="GitHub Pages 地址",
    )
    ap.add_argument("--headful", action="store_true")
    args = ap.parse_args()

    base = args.url.rstrip("/") + "/"
    results: list[tuple[str, bool, str]] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        results.append((name, ok, detail))
        print(f"  {PASS if ok else FAIL}  {name}" + (f"  — {detail}" if detail else ""))

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=not args.headful)
        page = browser.new_page(viewport={"width": 1440, "height": 900})

        console_errors: list[str] = []
        failed_requests: list[str] = []
        page.on("console", lambda m: console_errors.append(m.text) if m.type == "error" else None)
        page.on("requestfailed", lambda r: failed_requests.append(f"{r.url} :: {r.failure}"))
        page.on(
            "response",
            lambda r: failed_requests.append(f"{r.url} :: HTTP {r.status}")
            if r.status >= 400
            else None,
        )

        print(f"\n▶ 打开 {base}")
        resp = page.goto(base, wait_until="networkidle", timeout=60000)
        check("首页 HTTP 200", resp is not None and resp.status == 200,
              f"status={resp.status if resp else 'N/A'}")

        # 1. 应用已挂载
        check("Vue 应用已挂载", page.locator("#app").count() > 0
              and page.evaluate("document.querySelector('#app').children.length") > 0)

        # 2. 标题
        title = page.title()
        check("页面标题正确", "Java" in title, title)

        # 3. JS/CSS 资源加载成功（子路径相对路径的核心验证点）
        js_ok = page.evaluate("""() => {
            const s = document.querySelector('script[src*="assets/"]');
            return !!s && s.src.startsWith(location.origin);
        }""")
        check("JS 以相对路径加载", js_ok)

        css_ok = page.evaluate("""() => {
            const l = document.querySelector('link[rel="stylesheet"][href*="assets/"]');
            return !!l && l.href.startsWith(location.origin);
        }""")
        check("CSS 以相对路径加载", css_ok)

        # 4. 没有 404 资源
        http_404 = [u for u in failed_requests if "HTTP 404" in u]
        check("无 404 资源", len(http_404) == 0, "; ".join(http_404[:3]))

        # 5. 登录页可达（hash 路由）
        page.goto(base + "#/login", wait_until="networkidle", timeout=40000)
        check("hash 路由跳转 /login", "login" in page.url, page.url)
        login_img = page.evaluate("""() => {
            const imgs = Array.from(document.querySelectorAll('img'));
            return imgs.every(i => i.complete && i.naturalWidth > 0);
        }""")
        check("登录页图片全部加载", login_img)

        # 6. 鲸鲸助手图片（assets/agent 相对路径）
        agent_ok = page.evaluate("""async () => {
            const r = await fetch(new URL('assets/agent/agent-idle.png', location.href).href);
            return r.ok;
        }""")
        check("agent 图片相对路径可取", agent_ok)

        # 7. webm 桌宠素材相对路径可取
        pet_ok = page.evaluate("""async () => {
            const r = await fetch(new URL('pet/idle.webm', location.href).href);
            return r.ok;
        }""")
        check("桌宠 webm 相对路径可取", pet_ok)

        # 8. 路由守卫会跳登录（未登录）
        page.goto(base + "#/course/java-core", wait_until="networkidle", timeout=40000)
        check("未登录访问课程页重定向", "login" in page.url, page.url)

        # 9. 控制台无 JS 错误
        real_errors = [e for e in console_errors if "favicon" not in e.lower()]
        check("控制台无 JS 报错", len(real_errors) == 0, "; ".join(real_errors[:3]))

        # 10. 截图存档
        shot = "docs/screenshots/pages-deploy.png"
        page.goto(base + "#/login", wait_until="networkidle", timeout=40000)
        page.screenshot(path=shot, full_page=False)
        check("截图已保存", True, shot)

        browser.close()

    ok = sum(1 for _, o, _ in results if o)
    total = len(results)
    print(f"\n{'=' * 56}")
    print(f"  结果：{ok}/{total} 项通过")
    print(f"{'=' * 56}")
    if ok != total:
        print("\n失败项：")
        for n, o, d in results:
            if not o:
                print(f"  - {n}  {d}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
