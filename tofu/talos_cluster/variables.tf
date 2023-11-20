variable "cluster" {
  type = object({
    name        = string
    vip         = optional(string)
    nameservers = list(string)
    machines = map(object({
      disk_filter = optional(map(string), {})
      patch       = optional(string, "")
      primary_ip  = optional(string, "")
      type        = string
      interfaces = list(object({
        interface      = optional(string)
        deviceSelector = optional(map(string))
        dhcp           = optional(bool)
        addresses      = optional(list(string))
        routes = optional(list(object({
          network = optional(string)
          gateway = optional(string)
        })))
        vip = optional(object({
          ip = optional(string)
        }))
        bridge = optional(object({
          interfaces = list(string)
          stp = object({
            enabled = bool
          })
        }))
      }))
    }))
    ceph = object({
      public_network  = string
      cluster_network = string
      storage_nodes = list(object({
        name = string
        devices = list(object({
          name = string
        }))
      }))
    })
  })
}

variable "cluster_endpoint" {
  type        = string
  description = "if set, overrides cluster.vip"
  default     = ""
}

variable "initial_secrets" {
  type = object({
    s3_access_key_id        = string
    s3_bucket               = string
    s3_secret_access_key    = string
    s3_url                  = string
    vault_unseal            = string
    volsync_restic_password = string
  })
}
