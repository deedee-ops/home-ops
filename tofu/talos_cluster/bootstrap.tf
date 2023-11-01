resource "talos_machine_secrets" "this" {}

resource "talos_machine_configuration_apply" "controlplanes" {
  for_each = local.controlplanes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.key].machine_configuration
  node                        = each.value.primary_ip == "" ? local.cluster_endpoint : each.value.primary_ip

  config_patches = [
    yamlencode({
      machine = {
        network = {
          hostname = each.key
          interfaces = [{
            deviceSelector = {
              hardwareAddr = each.value.primary_mac
            }
            dhcp = true
            vip = {
              ip : local.cluster_endpoint
            }
          }]
        }
        install = {
          image = "ghcr.io/siderolabs/installer:v1.5.4"
          disk  = data.talos_machine_disks.this[each.key].disks[0].name
        }
        features = {
          kubePrism = {
            enabled = true
            port    = 7445
          }
        }
      }
      cluster = {
        network = {
          podSubnets     = ["172.30.0.0/16"]
          serviceSubnets = ["172.31.0.0/16"]
          cni = {
            name = "none"
          }
        }
        controllerManager = {
          extraArgs = {
            "bind-address" = "0.0.0.0"
          }
        }
        proxy = {
          disabled = true
        }
        scheduler = {
          extraArgs = {
            "bind-address" = "0.0.0.0"
          }
        }
        etcd = {
          extraArgs = {
            "listen-metrics-urls" = "http://0.0.0.0:2381"
          }
        }
        inlineManifests = [
          {
            name : "cilium"
            contents : file("${path.root}/manifests/cilium.yaml")
          },
          {
            name : "argocd"
            contents : file("${path.root}/manifests/argocd.yaml")
          },
          {
            name : "argocd-repo-and-project"
            contents : file("${path.root}/manifests/argocd-repo-and-project.yaml")
          },
          {
            name : "ceph"
            contents : <<-EOS
              ---
              apiVersion: v1
              kind: Namespace
              metadata:
                labels:
                  kubernetes.io/metadata.name: rook-ceph
                name: rook-ceph
              ---
              apiVersion: v1
              kind: ConfigMap
              metadata:
                name: rook-config-override
                namespace: rook-ceph
              data:
                config: |
                  [global]
                  bdev_enable_discard = true
                  bdev_async_discard = true
                  osd_class_update_on_start = false

                  public network = ${var.cluster.ceph.public_network}
                  cluster network = ${var.cluster.ceph.cluster_network}
                  public addr = ""
                  cluster addr = ""

                  [mon]
                  mon_data_avail_warn = 15

            EOS
          },
          {
            name : "vault"
            contents : <<-EOS
              ---
              apiVersion: v1
              kind: Namespace
              metadata:
                labels:
                  kubernetes.io/metadata.name: vault
                name: vault
              ---
              apiVersion: v1
              kind: Secret
              type: Opaque
              metadata:
                name: vault-unseal
                namespace: vault
              stringData:
                UNSEAL_KEY: "${var.initial_secrets.vault_unseal}"
              ---
              apiVersion: v1
              kind: Secret
              metadata:
                name: restic-vault-data-vault-0
                namespace: vault
              type: Opaque
              stringData:
                AWS_ACCESS_KEY_ID: "${var.initial_secrets.volsync_access_key_id}"
                AWS_SECRET_ACCESS_KEY: "${var.initial_secrets.volsync_secret_access_key}"
                RESTIC_PASSWORD: "${var.initial_secrets.volsync_restic_password}"
                RESTIC_REPOSITORY: "${var.initial_secrets.volsync_restic_repository_template}/vault/data-vault-0"
              ---
              apiVersion: v1
              kind: Secret
              metadata:
                name: restic-vault-data-vault-1
                namespace: vault
              type: Opaque
              stringData:
                AWS_ACCESS_KEY_ID: "${var.initial_secrets.volsync_access_key_id}"
                AWS_SECRET_ACCESS_KEY: "${var.initial_secrets.volsync_secret_access_key}"
                RESTIC_PASSWORD: "${var.initial_secrets.volsync_restic_password}"
                RESTIC_REPOSITORY: "${var.initial_secrets.volsync_restic_repository_template}/vault/data-vault-1"
              ---
              apiVersion: v1
              kind: Secret
              metadata:
                name: restic-vault-data-vault-2
                namespace: vault
              type: Opaque
              stringData:
                AWS_ACCESS_KEY_ID: "${var.initial_secrets.volsync_access_key_id}"
                AWS_SECRET_ACCESS_KEY: "${var.initial_secrets.volsync_secret_access_key}"
                RESTIC_PASSWORD: "${var.initial_secrets.volsync_restic_password}"
                RESTIC_REPOSITORY: "${var.initial_secrets.volsync_restic_repository_template}/vault/data-vault-2"
            EOS
          },
          {
            name : "app-rook-ceph"
            contents : file("${path.root}/../../kubernetes/apps/rook-ceph/rook-ceph/application.yaml")
          },
          {
            name : "app-rook-ceph-cluster"
            contents : yamlencode(local.patched_rook_ceph_app)
          },
          {
            name : "app-snapshot-controller"
            contents : file("${path.root}/../../kubernetes/apps/kube-system/snapshot-controller/application.yaml")
          },
          {
            name : "app-volsync"
            contents : file("${path.root}/../../kubernetes/apps/backups/volsync/application.yaml")
          },
          {
            name : "app-secrets-store-csi-driver"
            contents : file("${path.root}/../../kubernetes/apps/kube-system/secrets-store-csi-driver/application.yaml")
          },
          {
            name : "app-argocd-update",
            contents : file("${path.root}/../../kubernetes/apps/argocd/argocd/application.yaml")
          },
          {
            name : "app-vault"
            contents : file("${path.root}/../../kubernetes/apps/database/vault/application.yaml")
          },
        ]
        extraManifests = [
          "https://raw.githubusercontent.com/giantswarm/silence-operator/master/config/crd/monitoring.giantswarm.io_silences.yaml",
          "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml",
          "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml",
          "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml"
        ]
      }
    }),
    each.value.patch
  ]
}

resource "talos_machine_bootstrap" "controlplanes" {
  depends_on = [
    talos_machine_configuration_apply.controlplanes
  ]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = values(local.controlplanes)[0].primary_ip == "" ? local.cluster_endpoint : values(local.controlplanes)[0].primary_ip
}

resource "talos_machine_configuration_apply" "workers" {
  depends_on = [
    talos_machine_bootstrap.controlplanes
  ]
  for_each = local.workers

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
        features = {
          kubePrism = {
            enabled = true
            port    = 7445
          }
        }
      }
      cluster = {
        network = {
          podSubnets     = ["172.30.0.0/16"]
          serviceSubnets = ["172.31.0.0/16"]
          cni = {
            name = "none"
          }
        }
        proxy = {
          disabled = true
        }
      }
    }),
    each.value.patch
  ]
}

locals {
  # hashicorp... have mercy
  patched_rook_ceph_app = {
    for k, v in yamldecode(file("${path.root}/../../kubernetes/apps/rook-ceph/rook-ceph-cluster/application.yaml")) : k => try(
      merge(v, {
        sources = [
          merge(
            yamldecode(file("${path.root}/../../kubernetes/apps/rook-ceph/rook-ceph-cluster/application.yaml")).spec.sources[0], {
              helm = {
                valueFiles = ["./values.yaml"],
                valuesObject = {
                  "rook-ceph-cluster" = {
                    cephClusterSpec = {
                      storage = {
                        nodes = var.cluster.ceph.storage_nodes
                      }
                    }
                  }
                }
              }
            }
          )
        ]
        }
      ),
      v
  ) }
}
