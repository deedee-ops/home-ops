import json, os, logging
from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.request, urllib.error

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
log = logging.getLogger("lang-proxy")

VOICE_BACKEND_URL = os.getenv("VOICE_BACKEND_URL", "http://localhost:8000")
VOICE_EN     = os.getenv("VOICE_EN", "en_US-lessac-medium")
VOICE_PL     = os.getenv("VOICE_PL", "pl_PL-gosia-medium")
VOICE_MAP    = {"pl": VOICE_PL}

def detect_lang(text):
    try:
        from langdetect import detect
        return detect(text)
    except Exception as e:
        log.warning("Language detection failed: %s", e)
        return "en"

class ProxyHandler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _proxy(self, body=None):
        url = f"{VOICE_BACKEND_URL}{self.path}"
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
                log.info("%s %s -> %s", self.command, self.path, resp.status)
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            self.end_headers()
            self.wfile.write(e.read())
            log.warning("%s %s -> %s", self.command, self.path, e.code)

    def do_GET(self):
        self._proxy()

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length)

        if self.path == "/v1/audio/speech":
            try:
                body = json.loads(raw)
                text = body.get("input", "")
                original_voice = body.get("voice", "<unset>")
                lang = detect_lang(text)
                new_voice = VOICE_MAP.get(lang, VOICE_EN)
                body["voice"] = new_voice
                raw = json.dumps(body).encode()
                log.info(
                    "POST /v1/audio/speech | detected=%s | voice %s -> %s | text=%r",
                    lang, original_voice, new_voice, text[:80]
                )
            except Exception as e:
                log.warning("Failed to process speech request: %s", e)
        else:
            log.info("%s %s", self.command, self.path)

        self._proxy(raw)

if __name__ == "__main__":
    port = int(os.getenv("PROXY_PORT", "8080"))
    log.info("Starting lang-proxy on port %d (EN=%s, PL=%s)", port, VOICE_EN, VOICE_PL)
    HTTPServer(("0.0.0.0", port), ProxyHandler).serve_forever()
