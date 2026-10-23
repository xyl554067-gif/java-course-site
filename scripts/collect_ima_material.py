# -*- coding: utf-8 -*-
"""
批量检索 ima 知识库，为课时增强收集素材。

search_knowledge 返回约 10 万字符会触发工具落盘，本脚本读取落盘文件、
只保留与目标课时相关的条目片段，合并输出成一份素材 Markdown。

用法：python collect_ima_material.py <检索结果落盘文件...> --out docs/ima-material/xx.md --slug jvm-memory
"""
import argparse, glob, json, os, re, sys

TOOL_DIR = r"C:\Users\lxy\.workbuddy\projects\d-code-PythonApplication1-2026-10-22-10-05-58\a9ce1ddb-c68f-4615-8058-0f1ef11f0f6f\tool-results"


def clean(s):
    return re.sub(r"</?em>", "", s or "")


def collect(paths, slug, keywords, top=8, hl_chars=1400):
    """合并多次检索的落盘结果，按资料去重，保留命中片段"""
    by_media = {}
    for p in paths:
        with open(p, encoding="utf-8") as f:
            d = json.load(f)
        for x in d.get("searched_knowledge_list", []):
            k = x.get("knowledge") or {}
            mid = k.get("media_id")
            title = k.get("title") or ""
            folder = x.get("parent_folder_name") or ""
            hl = clean(x.get("highlight_content") or "")
            intro = clean(k.get("introduction") or "")
            if not mid:
                continue
            rec = by_media.setdefault(mid, {
                "title": title, "folder": folder, "intro": intro, "hls": [],
            })
            if hl and hl not in rec["hls"]:
                rec["hls"].append(hl)

    # 相关度：标题命中关键词 + 命中片段命中关键词
    scored = []
    for mid, rec in by_media.items():
        score = 0
        for kw in keywords:
            if kw in rec["title"]:
                score += 10
            if any(kw in h for h in rec["hls"]):
                score += 4
            if kw in rec["intro"]:
                score += 2
        scored.append((score, len(rec["hls"]), mid, rec))
    scored.sort(key=lambda r: (-r[0], -r[1]))

    lines = [f"# 课时素材：{slug}", ""]
    picked = 0
    for score, _, mid, rec in scored:
        if score <= 0:
            continue
        picked += 1
        if picked > top:
            break
        lines.append(f"## 资料：{rec['title']}（{rec['folder'] or '-'}）")
        lines.append(f"media_id: {mid}")
        lines.append("")
        if rec["intro"]:
            lines.append("**正文开头**")
            lines.append("")
            lines.append(rec["intro"][:600])
            lines.append("")
        for i, h in enumerate(rec["hls"][:3]):
            lines.append(f"**命中片段 {i+1}**")
            lines.append("")
            lines.append(h[:hl_chars])
            lines.append("")
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dumps", nargs="*", help="检索结果落盘文件（省略则取最新的全部）")
    ap.add_argument("--slug", required=True)
    ap.add_argument("--kw", required=True, help="关键词，逗号分隔")
    ap.add_argument("--out", required=True)
    ap.add_argument("--top", type=int, default=8)
    args = ap.parse_args()

    paths = args.dumps
    if not paths:
        paths = sorted(glob.glob(os.path.join(TOOL_DIR, "mcp-ima-mcp-search_knowledge-*.txt")))
    kws = [k.strip() for k in args.kw.split(",") if k.strip()]
    md = collect(paths, args.slug, kws, top=args.top)
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        f.write(md)
    print(f"写入 {args.out}  ({len(md)} 字符)")


if __name__ == "__main__":
    main()
