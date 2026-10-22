#!/usr/bin/env bash
# 优雅停止 KingBase 实例（必须用sys_ctl，勿用 taskkill）
#
# 原因（实测）: 强杀进程不会释放 License 共享内存
#   (Global\kingbase:*)，导致下次启动报 openfilemapping error。
# 另外 sys_ctl 需要与 kingbase.exe 同权限（本项目要求管理员），若报
#   Operation not permitted，请改用管理员 PowerShell 手动执行。
source "$(dirname "${BASH_SOURCE[0]}")/kb_env.sh"

DATA_DIR="${1:-D:/Kingbase/data}"
KB_BIN="D:/Kingbase/KESRealPro/V008R006C009B0014/Server/bin"

if ! kb_is_up; then
  echo "端口 ${KB_PORT} 未监听，无需停库"
  exit 0
fi

echo "==> 优雅停库（$DATA_DIR）"
cd "$KB_BIN"
if ./sys_ctl.exe -D "$DATA_DIR" -m fast -t 40 stop 2>&1 | tail -2; then
  sleep 3
  if kb_is_up; then
    echo "!! 端口仍在监听，停库未成功。请用管理员 PowerShell 手动执行 sys_ctl stop"
    exit 1
  fi
  echo "✓ 已停止，License 共享内存已释放"
else
  echo "!! 停库失败。通常是权限不足（服务属主不可读）。"
  echo "   请用【管理员 PowerShell】执行："
  echo "   cd $KB_BIN; .\sys_ctl.exe -D $DATA_DIR -m fast stop"
  exit 1
fi