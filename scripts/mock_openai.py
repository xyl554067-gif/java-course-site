"""假 OpenAI 兼容服务端 —— 用于验证 openai 通道的成功路径（不消耗真实额度）。

用法: python mock_openai.py 19999
提供: GET /v1/models, POST /v1/chat/completions
"""
import json
import time
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print("[mock-openai] " + fmt % args, flush=True)

    def _json(self, code, obj):
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.startswith("/v1/models"):
            self._json(200, {"object": "list", "data": [{"id": "mock-model"}]})
        else:
            self._json(404, {"error": "not found"})

    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(n).decode("utf-8")
        print("[mock-openai] 收到请求 auth=%r" % self.headers.get("Authorization"), flush=True)
        print("[mock-openai] 原始 body: %r" % raw[:600], flush=True)
        try:
            req = json.loads(raw)
        except Exception:
            req = {}
        # 模拟真实推理延迟
        time.sleep(0.4)
        user_content = ""
        for m in req.get("messages", []):
            if m.get("role") == "user":
                user_content = m.get("content", "")
        answer = (
            "【MOCK 模型回答】\n"
            "这是来自 mock OpenAI 兼容服务的响应，用于验证 openai 通道。\n"
            "收到的用户问题前 80 字：" + user_content[:80] + "\n"
            "系统提示词长度：%d 字" % len(req.get("messages", [{}])[0].get("content", ""))
        )
        self._json(200, {
            "id": "chatcmpl-mock",
            "object": "chat.completion",
            "model": req.get("model", "mock"),
            "choices": [{
                "index": 0,
                "message": {"role": "assistant", "content": answer},
                "finish_reason": "stop",
            }],
            "usage": {"prompt_tokens": 100, "completion_tokens": 50, "total_tokens": 150},
        })


if __name__ == "__main__":
    port = int(__import__("sys").argv[1] if len(__import__("sys").argv) > 1 else 19999)
    print("[mock-openai] listening on %d" % port, flush=True)
    HTTPServer(("127.0.0.1", port), Handler).serve_forever()
