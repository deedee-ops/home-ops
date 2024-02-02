resource "cloudflare_ruleset" "external_ingress" {
  kind    = "zone"
  name    = "default"
  phase   = "http_request_firewall_custom"
  zone_id = "6289b16b682490ce40503a80b9210319"

  rules {
    action = "skip"
    action_parameters {
      ruleset = "current"
    }
    description = "Allow GitHub to ArgoCD API"
    enabled     = true
    expression  = "(http.host eq \"argocd.${var.base_domain}\" and ip.geoip.asnum eq 36459)"
    logging {
      enabled = true
    }
  }

  rules {
    action      = "block"
    description = "Firewall rule to block countries"
    enabled     = true
    expression  = "(ip.geoip.country in {\"RU\" \"CN\"})"
  }

  rules {
    action      = "block"
    description = "Firewall rule to block bots determined by CF"
    enabled     = true
    expression  = "(cf.client.bot) or (cf.threat_score gt 14)"
  }
}
