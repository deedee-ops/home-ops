resource "cloudflare_workers_script" "webfinger" {
  for_each = var.webfinger

  account_id         = var.cloudflare_account_id
  script_name        = "webfinger-${replace(each.key, ".", "-")}"
  main_module        = "worker.js"
  compatibility_date = "2026-01-01"

  content = <<-JS
    const domain = ${jsonencode(each.key)};
    const issuer = ${jsonencode(each.value)};

    export default {
      fetch(request) {
        const url = new URL(request.url);
        const resource = url.searchParams.get("resource") || "";

        if (url.pathname !== "/.well-known/webfinger" || !resource.toLowerCase().endsWith("@" + domain)) {
          return new Response("Not found", { status: 404 });
        }

        return new Response(JSON.stringify({
          subject: resource,
          links: [{ rel: "http://openid.net/specs/connect/1.0/issuer", href: issuer }],
        }), {
          headers: {
            "content-type": "application/jrd+json",
            "access-control-allow-origin": "*",
            "cache-control": "no-store",
          },
        });
      },
    };
  JS

  lifecycle {
    precondition {
      condition     = contains(keys(var.domains), each.key)
      error_message = "webfinger[\"${each.key}\"] must be a zone declared in var.domains."
    }
  }
}

resource "cloudflare_workers_custom_domain" "webfinger" {
  for_each = var.webfinger

  account_id = var.cloudflare_account_id
  zone_id    = var.domains[each.key].zone_id
  hostname   = each.key
  service    = cloudflare_workers_script.webfinger[each.key].script_name
}
