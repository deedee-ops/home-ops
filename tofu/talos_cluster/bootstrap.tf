resource "talos_machine_secrets" "this" {}

resource "talos_machine_configuration_apply" "this" {
  for_each = var.cluster.machines

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.key].machine_configuration
  node                        = each.value.primary_ip == "" ? local.cluster_endpoint : each.value.primary_ip

  config_patches = [
    yamlencode({
      machine = {
        network = {
          hostname = each.key
        }
        install = {
          image = "ghcr.io/siderolabs/installer:v1.5.3"
          disk  = data.talos_machine_disks.this[each.key].disks[0].name
        }
      }
      cluster = {
        network = {
          podSubnets     = ["172.30.0.0/16"]
          serviceSubnets = ["172.31.0.0/16"]
        }
        inlineManifests = [
          {
            name : "create-namespaces"
            contents : <<-EOM
              apiVersion: v1
              kind: Namespace
              metadata:
                name: argocd
            EOM
          },
          {
            name : "argocd"
            contents : file("${path.root}/manifests/argocd.yaml")
          }
        ]
      }
    }),
    each.value.patch
  ]
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [
    talos_machine_configuration_apply.this
  ]
  for_each = var.cluster.machines

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = each.value.primary_ip == "" ? local.cluster_endpoint : each.value.primary_ip
}
