resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name  = "vault"
    organization = "homelab"
  }

  allowed_uses = [
    "key_encipherment",
    "cert_signing",
    "server_auth",
    "client_auth",
  ]

  validity_period_hours = 876000
  early_renewal_hours   = 720
  is_ca_certificate     = true
}

resource "tls_private_key" "vault" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_cert_request" "vault" {
  private_key_pem = tls_private_key.vault.private_key_pem

  dns_names = [
    "vault", "vault.vault", "vault.vault.svc", "vault.vault.svc.cluster.local",
    "*.vault-internal", "*.vault-internal.vault", "*.vault-internal.vault.svc", "*.vault-internal.vault.svc.cluster.local"
  ]

  ip_addresses = [
    "127.0.0.1"
  ]

  subject {
    common_name  = "vault"
    organization = "homelab"
  }
}

resource "tls_locally_signed_cert" "vault" {
  cert_request_pem   = tls_cert_request.vault.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 876000

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}
