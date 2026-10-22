from mitmproxy import ctx, http
from mitmproxy.net.http import url


def running() -> None:
    # mitmweb has no switch to disable its token auth; the UI is protected by OIDC at Envoy instead
    ctx.master.app.settings["is_valid_password"] = lambda _: True


def requestheaders(flow: http.HTTPFlow) -> None:
    try:
        host, _ = url.parse_authority(flow.request.host_header or "", check=True)
    except ValueError:
        flow.response = http.Response.make(400, b"missing or invalid Host header\n")
        return
    tls = flow.client_conn.tls_established
    flow.request.scheme = "https" if tls else "http"
    flow.request.port = 443 if tls else 80
    flow.request.host = host
