resource "cloudflare_workers_script" "static_site" {
  for_each = local.static_sites

  account_id         = var.cloudflare_account_id
  script_name        = each.value.worker_name
  main_module        = "worker.js"
  compatibility_date = "2026-01-01"

  content = <<-JS
    const body = ${jsonencode(each.value.content)};

    export default {
      fetch() {
        return new Response(body, {
          headers: {
            "content-type": "text/html; charset=utf-8",
            "cache-control": "no-store",
          },
        });
      },
    };
  JS

  lifecycle {
    precondition {
      condition     = each.value.zone_id != null
      error_message = "static_sites[\"${each.key}\"] must sit under exactly one zone declared in var.domains."
    }
  }
}

resource "cloudflare_workers_custom_domain" "static_site" {
  for_each = local.static_sites

  account_id = var.cloudflare_account_id
  zone_id    = each.value.zone_id
  hostname   = each.value.hostname
  service    = cloudflare_workers_script.static_site[each.key].script_name
}
