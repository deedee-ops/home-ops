locals {
  extra_dns_records = flatten([
    for domain_name, domain_opts in var.domains : [
      for record_name, record_opts in(domain_opts.records == null ? {} : domain_opts.records) : {
        key            = "${domain_name}_${record_name}"
        domain_name    = domain_name
        record_name    = record_name
        record_type    = record_opts.type
        record_content = record_opts.content
        record_proxied = (record_opts.proxied == null ? false : record_opts.proxied)
      }
    ]
  ])

  mail_domains = {
    for domain_name, domain_opts in var.domains : domain_name => (domain_opts.mail == null ? {
      spam                     = false
      migadu_verification_code = null
      alias                    = null
    } : domain_opts.mail)
  }

  redirects = flatten([
    for domain_name, domain_opts in var.domains : [
      for redirect_name, redirect_opts in(domain_opts.redirects == null ? {} : domain_opts.redirects) : {
        key                = "${domain_name}_${redirect_name}"
        domain_name        = domain_name
        redirect_name      = redirect_name
        redirect_from      = redirect_opts.from
        redirect_to        = redirect_opts.to
        redirect_permament = redirect_opts.permament
      }
    ]
  ])
}
