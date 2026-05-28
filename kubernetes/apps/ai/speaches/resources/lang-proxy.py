import json, os
from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.request, urllib.error

SPEACHES_URL = os.getenv("SPEACHES_URL", "http://localhost:8000")
VOICE_EN    = os.getenv("VOICE_EN", "en_US-lessac-medium")
VOICE_PL    = os.getenv("VOICE_PL", "pl_PL-gosia-medium")
VOICE_MAP   = {"pl": VOICE_PL}

def detect_lang(text):
    try:
        from langdetect import detect
        return detect(text)
    except Exception:
        return "en"

class ProxyHandler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _proxy(self, body=None):
        url = f"{SPEACHES_URL}{self.path}"
        headers = {k: v for k, v in self.headers.items()
                   if k.lower() not in ("host", "content-length")}
        if body:
            headers["Content-Length"] = str(len(body))
        req = urllib.request.Request(url, data=body, headers=headers, method=self.command)
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                self.send_response(resp.status)
                for k, v in resp.headers.items():
                    if k.lower() != "transfer-encoding":
                        self.send_header(k, v)
                self.end_headers()
                self.wfile.write(resp.read())
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            self.end_headers()
            self.wfile.write(e.read())

    def do_GET(self):
        self._proxy()

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length)
        if self.path == "/v1/audio/speech":
            try:
                body = json.loads(raw)
                lang = detect_lang(body.get("input", ""))
                body["voice"] = VOICE_MAP.get(lang, VOICE_EN)
                raw = json.dumps(body).encode()
            except Exception:
                pass
        self._proxy(raw)

if __name__ == "__main__":
    HTTPServer(("0.0.0.0", int(os.getenv("PROXY_PORT", "8080"))), ProxyHandler).serve_forever()
