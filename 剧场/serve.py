#!/usr/bin/env python3
"""台面剧场本地服务：静态托管 + 划线收藏落盘（POST /save → 划线集.js）。"""
import json
import os
import http.server
import socketserver

BASE = os.path.dirname(os.path.abspath(__file__))
os.chdir(BASE)
HL_FILE = "划线集.js"
PORT = 8767


def load_highlights():
    if not os.path.exists(HL_FILE):
        return []
    s = open(HL_FILE, encoding="utf-8").read()
    start, end = s.find("["), s.rfind("]")
    if start == -1 or end == -1:
        return []
    return json.loads(s[start:end + 1])


class Handler(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/save":
            self.send_response(404)
            self.end_headers()
            return
        n = int(self.headers.get("Content-Length", 0))
        item = json.loads(self.rfile.read(n))
        items = load_highlights()
        items.append(item)
        with open(HL_FILE, "w", encoding="utf-8") as f:
            f.write("window.HIGHLIGHTS = " + json.dumps(items, ensure_ascii=False, indent=2) + ";\n")
        body = json.dumps({"ok": True, "count": len(items)}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


class Server(socketserver.TCPServer):
    allow_reuse_address = True


if __name__ == "__main__":
    with Server(("127.0.0.1", PORT), Handler) as s:
        print(f"台面剧场已开张：http://localhost:{PORT}")
        s.serve_forever()
