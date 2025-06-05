resource "cloudflare_ruleset" "external_ingress" {
  for_each = {
    for name, opts in var.domains : name => opts
    if(opts.tunneled == null ? false : opts.tunneled)
  }

  kind    = "zone"
  name    = "default"
  phase   = "http_request_firewall_custom"
  zone_id = each.value.zone_id

  rules = [
    {
      action = "skip"
      action_parameters = {
        ruleset = "current"
      }
      description = "Allow access to ArgoCD webhook for GitHub"
      enabled     = true
      expression  = "(http.host eq \"argocd.${each.key}\") and (ip.geoip.asnum eq 36459) and (http.request.uri.path eq \"/api/webhook\")"

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
