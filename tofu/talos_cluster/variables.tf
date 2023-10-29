variable "cluster" {
  type = object({
    name = string
    vip  = optional(string)
    machines = map(object({
      disk_filter = optional(map(string), {})
      patch       = optional(string, "")
      primary_ip  = optional(string, "")
      primary_mac = optional(string, "")
      type        = string
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
    vault_unseal                       = string
    volsync_access_key_id              = string
    volsync_secret_access_key          = string
    volsync_restic_password            = string
    volsync_restic_repository_template = string
  })
}
