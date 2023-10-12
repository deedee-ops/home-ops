variable "cluster" {
  type = object({
    name = string
    vip  = optional(string)
    machines = map(object({
      disk_filter = optional(map(string), {})
      patch       = optional(string, "")
      primary_ip  = optional(string, "")
      type        = string
    }))
  })
}

variable "cluster_endpoint" {
  type        = string
  description = "if set, overrides cluster.vip"
  default     = ""
}
