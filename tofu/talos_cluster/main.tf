terraform {
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.3.4"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "4.0.5"
    }
  }

  required_version = "~> 1.6"
}

data "talos_machine_configuration" "this" {
  for_each = var.cluster.machines

  cluster_endpoint   = "https://${local.cluster_endpoint}:6443"
  cluster_name       = var.cluster.name
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  machine_type       = each.value.type
  docs               = false
  examples           = false
  kubernetes_version = "1.27.6"
  talos_version      = "v1.5.3"
}

data "talos_client_configuration" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  cluster_name         = var.cluster.name
  endpoints            = local.endpoints
  nodes                = local.nodes
}

data "talos_cluster_kubeconfig" "this" {
  depends_on = [
    talos_machine_bootstrap.controlplanes
  ]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = values(local.controlplanes)[0].primary_ip
}

data "talos_machine_disks" "this" {
  for_each = var.cluster.machines

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = each.value.primary_ip == "" ? local.cluster_endpoint : each.value.primary_ip
  filters = {
    bus_path = lookup(each.value.disk_filter, "bus_path", null)
    modalias = lookup(each.value.disk_filter, "modalias", null)
    model    = lookup(each.value.disk_filter, "model", null)
    name     = lookup(each.value.disk_filter, "name", null)
    serial   = lookup(each.value.disk_filter, "serial", null)
    size     = lookup(each.value.disk_filter, "size", null)
    type     = lookup(each.value.disk_filter, "type", null)
    uuid     = lookup(each.value.disk_filter, "uuid", null)
    wwid     = lookup(each.value.disk_filter, "wwid", null)
  }
}

locals {
  cluster_endpoint = var.cluster_endpoint == "" ? var.cluster.vip : var.cluster_endpoint
  controlplanes    = merge([for name, node in var.cluster.machines : { (name) = node } if node.type == "controlplane"]...)
  workers          = merge([for name, node in var.cluster.machines : { (name) = node } if node.type == "worker"]...)
  endpoints        = compact([for name, node in var.cluster.machines : node.type == "controlplane" ? (node.primary_ip == "" ? local.cluster_endpoint : node.primary_ip) : ""])
  nodes            = compact([for name, node in var.cluster.machines : (node.primary_ip == "" ? local.cluster_endpoint : node.primary_ip)])
}

output "kubeconfig" {
  value     = data.talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}

output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}
