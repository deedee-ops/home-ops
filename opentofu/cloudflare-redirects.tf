# Cloudflare allows only one http_request_dynamic_redirect ruleset per zone,
# so all redirects of a zone are rules in that single ruleset.
resource "cloudflare_ruleset" "redirect" {
  for_each = local.redirects

  zone_id = var.domains[each.key].zone_id
  name    = join(", ", [for redirect in each.value : redirect.redirect_name])
  kind    = "zone"
  phase   = "http_request_dynamic_redirect"

  rules = [for redirect in each.value : {
    description = redirect.redirect_name
    expression  = redirect.redirect_expression
    action      = "redirect"
    action_parameters = {
      from_value = {
        status_code = (redirect.redirect_permament ? 301 : 302)
        target_url = (redirect.redirect_to_expression == null ? {
          value = redirect.redirect_to
          } : {
          expression = redirect.redirect_to_expression
        })
        preserve_query_string = true
      }
    }
  }]

  lifecycle {
    precondition {
      condition     = alltrue([for redirect in each.value : (redirect.redirect_to == null) != (redirect.redirect_to_expression == null)])
      error_message = "Each redirect in domains[\"${each.key}\"] needs exactly one of `to` or `to_expression`."
    }
  }
}

# Rulesets used to be keyed per redirect; keep state instead of recreating them.
moved {
  from = cloudflare_ruleset.redirect["rzegocki.pl_Redirect to GitHub"]
  to   = cloudflare_ruleset.redirect["rzegocki.pl"]
}

moved {
  from = cloudflare_ruleset.redirect["irgon.com_Redirect to GitHub"]
  to   = cloudflare_ruleset.redirect["irgon.com"]
}

moved {
  from = cloudflare_ruleset.redirect["irgon.pl_Redirect to GitHub"]
  to   = cloudflare_ruleset.redirect["irgon.pl"]
}

moved {
  from = cloudflare_ruleset.redirect["rzegocki.dev_Redirect to GitHub"]
  to   = cloudflare_ruleset.redirect["rzegocki.dev"]
}
