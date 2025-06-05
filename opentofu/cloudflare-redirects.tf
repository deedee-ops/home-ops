resource "cloudflare_ruleset" "redirect" {
  for_each = {
    for redirect in local.redirects : redirect.key => redirect
  }

  zone_id = var.domains[each.value.domain_name].zone_id
  name    = each.value.redirect_name
  kind    = "zone"
  phase   = "http_request_dynamic_redirect"

  rules = [{
    expression = "(http.request.full_uri wildcard \"${each.value.redirect_from}\")"
    action     = "redirect"
    action_parameters = {
      from_value = {
        status_code = (each.value.redirect_permament ? 301 : 302)
        target_url = {
          value = each.value.redirect_to
        }
        preserve_query_string = true
      }
    }
  }]
}
