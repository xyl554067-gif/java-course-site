# -*- coding: utf-8 -*-
"""
汇总所有 ima 检索落盘结果，产出一份「资料 × 命中知识点」索引。

每个资料条目记录：标题、所属目录、所有检索中命中的不同片段。
这份索引是撰写课时增强正文时的知识来源对照表。
"""
import glob, json, os, re

TOOL_DIR = r"C:\Users\lxy\.workbuddy\projects\d-code-PythonApplication1-2026-10-22-10-05-58\a9ce1ddb-c68f-4615-8058-0f1ef11f0f6f\tool-results"
OUT = r"D:\code\PythonApplication1\2026-10-22-10-05-58\docs\ima-material\_index.md"


def clean(s):
    return re.sub(r"\s+", " ", re.sub(r"</?em>", "", s or "")).strip()


def main():
    files = sorted(glob.glob(os.path.join(TOOL_DIR, "mcp-ima-mcp-search_knowledge-*.txt")))
    by_media = {}
    for p in files:
        with open(p, encoding="utf-8") as f:
            d = json.load(f)
        for x in d.get("searched_knowledge_list", []):
            k = x.get("knowledge") or {}
            mid = k.get("media_id")
            if not mid:
                continue
            rec = by_media.setdefault(mid, {
                "title": k.get("title") or "",
                "folder": x.get("parent_folder_name") or "",
                "intro": clean(k.get("introduction") or ""),
                "hls": [],
            })
            hl = clean(x.get("highlight_content") or "")
            if hl and hl not in rec["hls"]:
                rec["hls"].append(hl)

    lines = ["# ima 知识库检索索引（Java江湖）", ""]
    lines.append(f"检索次数：{len(files)}　命中资料数：{len(by_media)}")
    lines.append("")
    # 按目录分组
    by_folder = {}
    for mid, rec in by_media.items():
        by_folder.setdefault(rec["folder"] or "-", []).append((mid, rec))

    for folder in sorted(by_folder):
        items = sorted(by_folder[folder], key=lambda r: -len(r[1]["hls"]))
        lines.append(f"## 目录：{folder}（{len(items)} 份）")
        lines.append("")
        for mid, rec in items:
            lines.append(f"### {rec['title']}")
            lines.append(f"- media_id: `{mid}`")
            if rec["intro"]:
                lines.append(f"- 简介：{rec['intro'][:220]}")
            if rec["hls"]:
                lines.append(f"- 命中知识点（{len(rec['hls'])} 条）：")
                for h in rec["hls"][:12]:
                    lines.append(f"  - {h[:180]}")
            lines.append("")

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"写入 {OUT}（{len(lines)} 行）")
    print(f"资料总数 {len(by_media)}，目录 {list(by_folder)}")


if __name__ == "__main__":
    main()
