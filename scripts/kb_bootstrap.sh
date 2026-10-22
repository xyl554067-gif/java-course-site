#!/usr/bin/env bash
# 一键重建应用库：建库 → 建账号 → 建表 → 灌种子数据 → 授权
#
# 前提：KingbaseES 实例必须已由【管理员权限】启动并监听 KB_PORT。
#      本项目不再自行 initdb/启停，原因是 License 共享内存是
#      Global\kingbase:* 内核对象，创建它需要 SeCreateGlobalPrivilege。
#
# ⚠ 本脚本会 DROP 已有的 javacourse 库及其中的全部数据
set -e
source "$(dirname "${BASH_SOURCE[0]}")/kb_env.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! kb_is_up; then
  echo "✗ 端口 ${KB_PORT} 未监听。请先以【管理员权限】启动 KingbaseES 实例。"
  exit 1
fi

echo "==> [1/5] 探测系统库"
kb_query "template1" "$KB_SYS_USER" "$KB_SYS_PW" "SELECT 1 AS ok"

echo "==> [2/5] 重建库 ${KB_DB} 与账号 ${KB_APP_USER}"
# 先踢掉残留连接，确保 DROP DATABASE 能成功
kb_exec "template1" "$KB_SYS_USER" "$KB_SYS_PW" \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${KB_DB}' AND pid <> pg_backend_pid();"
kb_exec "template1" "$KB_SYS_USER" "$KB_SYS_PW" "DROP DATABASE IF EXISTS ${KB_DB};"
kb_exec "template1" "$KB_SYS_USER" "$KB_SYS_PW" "CREATE DATABASE ${KB_DB} ENCODING 'UTF8';"
kb_exec "template1" "$KB_SYS_USER" "$KB_SYS_PW" "CREATE USER ${KB_APP_USER} WITH PASSWORD '${KB_APP_PW}';"
kb_exec "template1" "$KB_SYS_USER" "$KB_SYS_PW" "DROP ROLE IF EXISTS ${KB_APP_USER};"
kb_exec "template1" "$KB_SYS_USER" "$KB_SYS_PW" "CREATE USER ${KB_APP_USER} WITH PASSWORD '${KB_APP_PW}';"
kb_exec "${KB_DB}" "$KB_SYS_USER" "$KB_SYS_PW" "GRANT ALL ON SCHEMA public TO ${KB_APP_USER};"

echo "==> [3/5] 建表"
kb_run_sql "$KB_DB" "$KB_SYS_USER" "$KB_SYS_PW" "$ROOT/backend/src/main/resources/db/schema.sql"

echo "==> [4/5] 灌种子数据"
kb_run_sql "$KB_DB" "$KB_SYS_USER" "$KB_SYS_PW" "$ROOT/backend/src/main/resources/db/seed.sql"

echo "==> [5/5] 授权给应用账号"
kb_exec "$KB_DB" "$KB_SYS_USER" "$KB_SYS_PW" "GRANT ALL ON ALL TABLES IN SCHEMA public TO ${KB_APP_USER};"

echo
echo "✓ 重建完成"
echo "  库名: ${KB_DB}   应用账号: ${KB_APP_USER} / ${KB_APP_PW}"
echo "  演示账号: admin / demo，口令 123456"
echo "  注: 若登录提示口令错误，执行 scripts/reset_pw.sql 重置"