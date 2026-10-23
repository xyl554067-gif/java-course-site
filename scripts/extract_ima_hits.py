# -*- coding: utf-8 -*-
"""
从 ima search_knowledge 的落盘结果里提取高相关条目，避免把 96 条全量读进上下文。

用法: python extract_hits.py <落盘json> [--titles 关键词1,关键词2] [--top N] [--chars M]
"""
import json, re, sys, os

TOOL_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "..", ".workbuddy", "projects")
PROJ = r"C:\Users\lxy\.workbuddy\projects\d-code-PythonApplication1-2026-10-22-10-05-58"


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def clean(s):
    return re.sub(r"</?em>", "", s or "")


def main():
    path = sys.argv[1]
    titles = []
    top = 6
    chars = 1200
    for i, a in enumerate(sys.argv):
        if a == "--titles" and i + 1 < len(sys.argv):
            titles = [t.strip() for t in sys.argv[i + 1].split(",") if t.strip()]
        if a == "--top" and i + 1 < len(sys.argv):
            top = int(sys.argv[i + 1])
        if a == "--chars" and i + 1 < len(sys.argv):
            chars = int(sys.argv[i + 1])

    d = load(path)
    items = d.get("searched_knowledge_list", [])
    scored = []
    for x in items:
        k = x.get("knowledge", {}) or {}
        title = k.get("title") or ""
        intro = clean(k.get("introduction") or "")
        hl = clean(x.get("highlight_content") or "")
        folder = x.get("parent_folder_name") or ""
        # 相关度打分：标题命中关键词权重最高，其次正文命中
        score = 0
        for t in titles:
            if t and t in title:
                score += 10
            if t and t in intro:
                score += 3
            if t and t in hl:
                score += 5
        scored.append((score, len(intro), title, folder, intro, hl, k.get("media_id")))

    # 有关键词过滤时按分数排序；否则按 introduction 长度（内容越丰富越优先）
    if titles:
        scored.sort(key=lambda r: (-r[0], -r[1]))
    else:
        scored.sort(key=lambda r: -r[1])

    picked = [r for r in scored if r[0] > 0] if titles else scored[:top]
    picked = picked[:top]
    for i, (score, ilen, title, folder, intro, hl, mid) in enumerate(picked):
        print(f"===== [{i}] {title}  ({folder or '-'}) =====")
        print(f"  media_id: {mid}")
        if hl:
            print(f"  [命中片段] {hl[:600]}")
        print(f"  [正文开头] {intro[:chars]}")
        print()


if __name__ == "__main__":
    main()
