#!/usr/bin/env bash
# 桌宠动画素材预处理：裁掉左右透明边并重编码
#
# 为什么需要：dsh-pet 原始 webm 是 640x360，角色只占画面中央 33%x74%。
# 直接用 object-fit:contain 渲染，角色在 156px 容器里只有约 50px，几乎看不见。
# 裁切后角色占满容器，视觉大小提升近 3 倍，而总体积基本不变。
#
# 依赖：ffmpeg（需支持 libvpx-vp9）
#   Windows: 用 Playwright 自带的 ffmpeg
#     C:/Users/<you>/AppData/Local/ms-playwright/ffmpeg-*/ffmpeg-win64.exe
#   或从 ffmpeg.org 自行安装
#
# 用法: bash scripts/prep_pet_assets.sh [ffmpeg路径]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PET_DIR="$ROOT/frontend/public/pet"
SRC_DIR="${PET_SRC_DIR:-D:/dsh-pet/dsh-pet/assets/webm}"

# ---- 定位 ffmpeg ----
FFMPEG="${1:-}"
if [ -z "$FFMPEG" ]; then
  if command -v ffmpeg >/dev/null 2>&1; then
    FFMPEG="$(command -v ffmpeg)"
  else
    # 找 Playwright 自带的
    FFMPEG=$(ls -1 "$HOME/AppData/Local/ms-playwright"/ffmpeg-*/ffmpeg-win64.exe 2>/dev/null | head -1 || true)
  fi
fi
if [ -z "$FFMPEG" ] || [ ! -f "$FFMPEG" ]; then
  echo "错误：找不到 ffmpeg。请传入路径：bash scripts/prep_pet_assets.sh /path/to/ffmpeg" >&2
  exit 1
fi
echo "ffmpeg: $FFMPEG"

# ---- 源素材 → 输出名 的映射 ----
# 格式：源文件名|输出名
# 原始文件名是中文（dsh-pet 的资产命名），输出改成 ASCII：
#   避免各平台文件系统与 HTTP 层的 URL 编码差异（实测中文路径在部分客户端返回 400）
PAIRS=(
  "待机呼吸休闲|idle"
  "工作状态-思考冒泡|thinking"
  "深度思考碎碎念|talking"
  "被鼠标拖拽悬空反馈|dragging"
  "工作状态-雀跃庆祝|happy"
)

# ---- 裁切参数 ----
# crop=240:300:200:45  —— 覆盖 5 个动作的全部 alpha bbox（实测 213~426 × 63~331），留余量
# scale=280:350        —— 裁后 4:5 比例，容器用 aspect-ratio: 4/5 精确匹配
# crf=40               —— 视觉无损，体积与原片持平
CROP="crop=240:300:200:45,scale=280:350"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$PET_DIR"

for pair in "${PAIRS[@]}"; do
  src_name="${pair%%|*}"
  out_name="${pair##*|}"
  src="$SRC_DIR/$src_name.webm"
  dst="$PET_DIR/$out_name.webm"

  if [ ! -f "$src" ]; then
    echo "跳过（源文件不存在）: $src" >&2
    continue
  fi

  echo "处理 $src_name.webm → $out_name.webm"
  "$FFMPEG" -y -loglevel error -i "$src" \
    -vf "$CROP" \
    -c:v libvpx-vp9 -b:v 0 -crf 40 -row-mt 1 -cpu-used 4 -an \
    "$TMP/$out_name.webm"

  # 校验：输出必须存在且非空
  if [ ! -s "$TMP/$out_name.webm" ]; then
    echo "  失败：输出为空，保留原文件" >&2
    continue
  fi

  cp "$TMP/$out_name.webm" "$dst"
  printf "  %-12s %8d bytes\n" "$out_name.webm" "$(stat -c%s "$dst" 2>/dev/null || stat -f%z "$dst")"
done

echo
echo "完成。素材目录：$PET_DIR"
du -sh "$PET_DIR" 2>/dev/null || true
