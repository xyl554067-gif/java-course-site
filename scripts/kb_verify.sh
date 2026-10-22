#!/usr/bin/env bash
# 校验运行中的 KingBase 实例与本项目数据是否完好（只读，不改任何东西）
source "$(dirname "${BASH_SOURCE[0]}")/kb_env.sh"

if ! kb_is_up; then
  echo "✗ 端口 ${KB_PORT} 未监听"
  exit 1
fi

echo "==> 连接检查"
kb_query "$KB_DB" "$KB_APP_USER" "$KB_APP_PW" "SELECT 1 AS ok"

echo
echo "==> 各表行数"
for t in app_user user_session course course_module lesson code_snippet \
         knowledge_point lesson_knowledge qa_item resource_file search_index \
         learning_progress user_favorite ai_chat_session ai_chat_message generation_log; do
  kb_query "$KB_DB" "$KB_APP_USER" "$KB_APP_PW" "SELECT '$t' AS table_name, COUNT(*) AS rows FROM $t"
done

echo
echo "==> 课程结构"
kb_query "$KB_DB" "$KB_APP_USER" "$KB_APP_PW" \
  "SELECT c.title AS course, m.title AS module, m.lesson_count AS planned, COUNT(l.id) AS actual
   FROM course c
   JOIN course_module m ON m.course_id = c.id
   LEFT JOIN lesson l ON l.module_id = m.id
   GROUP BY c.title, m.title, m.sort_order, m.lesson_count
   ORDER BY m.sort_order"

echo
echo "==> 中文编码抽样"
kb_query "$KB_DB" "$KB_APP_USER" "$KB_APP_PW" \
  "SELECT title FROM lesson ORDER BY id LIMIT 5"

echo
echo "✓ 校验完成"