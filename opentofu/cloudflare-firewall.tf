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
      description = "Allow access to kromgo API"
      enabled     = true
      expression  = "(http.host eq \"kromgo.${each.key}\")"

      logging = {
        enabled = true
      }
    },
    {
      action = "skip"
      action_parameters = {
        ruleset = "current"
      }
      description = "Allow GitHub (36459) and myself (12887) access to flux webhook"
      enabled     = true
      expression  = "(http.host eq \"flux-webhook.${each.key}\") and (ip.geoip.asnum in {12887 36459}) and starts_with(http.request.uri.path, \"/hook\")"

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
