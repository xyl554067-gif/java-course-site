#!/usr/bin/env bash
# ============================================================================
# GitHub Pages 部署脚本
#
# 做的事：把 frontend/dist 推到 gh-pages 分支并启用 GitHub Pages。
#
# 为什么不直接用 git push：
#   本机 git 走 https 到 github.com 会被代理阻断（CONNECT tunnel failed 502），
#   但 api.github.com 通畅。所以这里走 GitHub Git Data API 建 blob/tree/commit/ref。
#
# 用法：
#   bash scripts/deploy_pages.sh                    # 构建 + 部署
#   bash scripts/deploy_pages.sh --skip-build       # 跳过构建，用现有 dist/
#   bash scripts/deploy_pages.sh --no-activate      # 只推分支，不启用 Pages
#
# 前置：
#   gh auth login（需 repo 权限）
#   前端依赖已安装（frontend/node_modules）
# ============================================================================
set -euo pipefail

REPO="${GITHUB_REPO:-xyl554067-gif/java-course-site}"
BRANCH="gh-pages"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
DIST="$ROOT/frontend/dist"

SKIP_BUILD=0
ACTIVATE=1
for arg in "$@"; do
  case "$arg" in
    --skip-build)  SKIP_BUILD=1 ;;
    --no-activate) ACTIVATE=0 ;;
    *) echo "未知参数: $arg" >&2; exit 1 ;;
  esac
done

command -v gh >/dev/null || { echo "❌ 需要 gh CLI（gh auth login）" >&2; exit 1; }

# ---------- 1. 构建 ----------
if [ "$SKIP_BUILD" -eq 0 ]; then
  echo "▶ 构建前端（--mode pages，相对基址 ./）..."
  ( cd "$ROOT/frontend" && npm run build -- --mode pages )
fi

[ -f "$DIST/index.html" ] || { echo "❌ 未找到 $DIST/index.html" >&2; exit 1; }

# Pages 的 Jekyll 会忽略下划线开头的目录，加 .nojekyll 保留原样
touch "$DIST/.nojekyll"

# ---------- 2. 收集文件清单 ----------
echo "▶ 收集产物文件..."
mapfile -t FILES < <(cd "$DIST" && find . -type f ! -name '.nojekyll' | sed 's|^\./||' | sort)
echo "  共 ${#FILES[@]} 个文件"

# ---------- 3. 通过 GitHub API 推送 ----------
echo "▶ 推送到 $BRANCH ..."
python - "$REPO" "$BRANCH" "$DIST" "${FILES[@]}" <<'PY'
import base64, json, os, subprocess, sys, time

repo, branch, dist = sys.argv[1], sys.argv[2], sys.argv[3]
files = sys.argv[4:]

def gh(args, data=None, allow_404=False):
    cmd = ["gh", "api"] + args + (["--input", "-"] if data is not None else [])
    last = None
    for attempt in range(4):
        p = subprocess.run(cmd, input=json.dumps(data) if data else None,
                           capture_output=True, text=True, encoding="utf-8")
        if p.returncode == 0:
            break
        last = p
        # 网络抖动（EOF / timeout / 5xx）重试；4xx 不重试
        if not any(k in (p.stderr or "") for k in ("EOF", "timeout", "502", "503", "504", "TLS")):
            break
        time.sleep(2 * (attempt + 1))
    else:
        p = last
    if p.returncode != 0:
        if allow_404 and ("404" in (p.stderr or "") or "422" in (p.stderr or "")):
            return None
        raise SystemExit("❌ gh api 失败: " + " ".join(args) + "\n" + p.stderr[:600])
    return json.loads(p.stdout) if p.stdout.strip() else {}

# 找到基线 ref（分支不存在则基于默认分支）
ref = gh([f"repos/{repo}/git/ref/heads/{branch}"], allow_404=True)
if ref:
    base = ref["object"]["sha"]
else:
    default = gh([f"repos/{repo}"])["default_branch"]
    base = gh([f"repos/{repo}/git/ref/heads/{default}"])["object"]["sha"]
base_tree = gh([f"repos/{repo}/git/commits/{base}"])["tree"]["sha"]

items = []
for f in files:
    blob = gh([f"repos/{repo}/git/blobs"], {
        "content": base64.b64encode(open(os.path.join(dist, f), "rb").read()).decode(),
        "encoding": "base64"})
    items.append({"path": f, "mode": "100644", "type": "blob", "sha": blob["sha"]})
# .nojekyll 标记文件
blob = gh([f"repos/{repo}/git/blobs"], {
    "content": base64.b64encode(b"").decode(), "encoding": "base64"})
items.append({"path": ".nojekyll", "mode": "100644", "type": "blob", "sha": blob["sha"]})

tree = gh([f"repos/{repo}/git/trees"], {"base_tree": base_tree, "tree": items})
commit = gh([f"repos/{repo}/git/commits"], {
    "message": "chore: 部署 GitHub Pages 产物",
    "tree": tree["sha"], "parents": [base],
    "author": {"name": "xyl554067-gif", "email": "xyl554067-gif@users.noreply.github.com"},
    "committer": {"name": "xyl554067-gif", "email": "xyl554067-gif@users.noreply.github.com"}})

updated = gh([f"repos/{repo}/git/refs/heads/{branch}", "-X", "PATCH",
              "-f", f"sha={commit['sha']}"], allow_404=True)
if updated is None:
    gh([f"repos/{repo}/git/refs", "-X", "POST", "-f", f"ref=refs/heads/{branch}",
        "-f", f"sha={commit['sha']}"])
    print(f"  ✅ 已创建分支 {branch}")
else:
    print(f"  ✅ 已更新分支 {branch}")
print("✅ 已推送 commit", commit["sha"][:7])
PY

# ---------- 4. 启用 Pages ----------
if [ "$ACTIVATE" -eq 1 ]; then
  echo "▶ 启用 GitHub Pages..."
  if gh api "repos/$REPO/pages" >/dev/null 2>&1; then
    gh api "repos/$REPO/pages" -X PUT -f "source[branch]=$BRANCH" -f "source[path]=/" >/dev/null && echo "  ✅ Pages 已配置为 $BRANCH 分支"
  else
    gh api "repos/$REPO/pages" -X POST -f "source[branch]=$BRANCH" -f "source[path]=/" >/dev/null && echo "  ✅ Pages 已创建"
  fi
fi

echo
echo "▶ 当前 Pages 状态："
gh api "repos/$REPO/pages" --jq '"  url: \(.html_url)\n  status: \(.status)\n  cname: \(.cname // "(未绑定自定义域名)")\n  https: \(.https_enforced)"' || echo "  (尚未启用)"
