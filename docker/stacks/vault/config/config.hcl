ui = true
storage "file" {
  path = "/vault/file"
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"

  tls_disable = 1
}

listener "tcp" {
  address = "0.0.0.0:443"
  tls_cert_file = "/vault/file/cert.pem"
  tls_key_file  = "/vault/file/key.pem"
  tls_min_version = "tls13"
}

api_addr     = "http://127.0.0.1:8200"
cluster_addr = "http://127.0.0.1:8201"

log_level = "info"

telemetry {
  prometheus_retention_time = "24h"
  disable_hostname          = true
}
