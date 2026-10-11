"""Upsert the SATOSA bridge as GoTrue's SAML SSO provider for SSO_DOMAIN.

Runs as an init container of the shelf-sso pod, so every rollout (config or
cert change) re-syncs the IdP metadata and attribute mapping stored in GoTrue.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

GOTRUE = os.environ["GOTRUE_URL"].rstrip("/")
DOMAIN = os.environ["SSO_DOMAIN"]
TOKEN = os.environ["SERVICE_ROLE_KEY"]
METADATA = os.environ.get("METADATA_FILE", "/tmp/metadata/frontend.xml")

# SAML attribute (FriendlyName) -> GoTrue claim. Unknown claim names end up in
# identity_data.custom_claims, which is where Shelf reads firstname/lastname/groups.
ATTRIBUTE_MAPPING = {
    "keys": {
        "email": {"name": "mail"},
        "firstname": {"name": "givenName"},
        "lastname": {"name": "sn"},
        "groups": {"name": "isMemberOf", "array": True},
    }
}


def call(method, path, body=None):
    req = urllib.request.Request(
        GOTRUE + path,
        method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.load(resp)


def main():
    with open(METADATA, encoding="utf-8") as f:
        metadata_xml = f.read()

    for attempt in range(60):
        try:
            providers = call("GET", "/admin/sso/providers")["items"] or []
            break
        except (urllib.error.URLError, OSError) as err:
            print(f"waiting for GoTrue ({err})", flush=True)
            time.sleep(5)
    else:
        sys.exit("GoTrue admin API unreachable")

    body = {"metadata_xml": metadata_xml, "domains": [DOMAIN], "attribute_mapping": ATTRIBUTE_MAPPING}
    existing = next(
        (p for p in providers if any(d.get("domain") == DOMAIN for d in p.get("domains") or [])),
        None,
    )
    try:
        if existing:
            result = call("PUT", f"/admin/sso/providers/{existing['id']}", body)
            print(f"updated SSO provider {result['id']} for {DOMAIN}")
        else:
            result = call("POST", "/admin/sso/providers", {"type": "saml", **body})
            print(f"created SSO provider {result['id']} for {DOMAIN}")
    except urllib.error.HTTPError as err:
        sys.exit(f"GoTrue rejected the provider: {err.code} {err.read().decode()}")


if __name__ == "__main__":
    main()
