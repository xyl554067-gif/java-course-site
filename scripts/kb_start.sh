#!/usr/bin/env bash
# 检查 KingBase 实例状态
#
# 重要约束（实测结论）:
#   KingbaseES V8 的 License 共享内存是Global\kingbase:* 内核命名对象，
#   创建它需要 SeCreateGlobalPrivilege —— 普通权限进程无法启动实例，
#   会报: FATAL: XX000: attach License shared memory error: openfilemapping error
#   因此本项目【不提供自启脚本】，只负责检查状态并给出正确提示。
set -e
source "$(dirname "${BASH_SOURCE[0]}")/kb_env.sh"

if kb_is_up; then
  echo "✓ 端口 ${KB_PORT} 正在监听"
  kb_query "$KB_DB" "$KB_APP_USER" "$KB_APP_PW" "SELECT current_database() AS db, 1 AS reachable"
  exit 0
fi

echo "✗ 端口 ${KB_PORT} 未监听，数据库未运行。"
echo
echo "  请【以管理员身份】打开 PowerShell，执行："
echo "    cd D:\Kingbase\KESRealPro\V008R006C009B0014\Server\bin"
echo "    .\sys_ctl.exe -D D:\Kingbase\data start"
echo
echo "  注意：不要用 taskkill 强杀kingbase.exe，"
echo "  否则 License 共享内存不会及时释放，再次启动会失败。"