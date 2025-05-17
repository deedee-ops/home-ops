data "cloudflare_zone" "root_domain" {
  zone_id = var.cloudflare_zone_id
}

resource "cloudflare_ruleset" "external_ingress" {
  kind    = "zone"
  name    = "default"
  phase   = "http_request_firewall_custom"
  zone_id = var.cloudflare_zone_id

  rules = [
    {
      action = "skip"
      action_parameters = {
        ruleset = "current"
      }
      description = "Allow access to ArgoCD webhook for GitHub"
      enabled     = true
      expression  = "(http.host eq \"argocd.${data.cloudflare_zone.root_domain.name}\") and (ip.geoip.asnum eq 36459) and (http.request.uri.path eq \"/api/webhook\")"

      logging = {
        enabled = true
      }
    },
    {
      action      = "block"
      description = "Block everything else"
      enabled     = true
      expression  = "true"
    }
  ]
}
