## dexter

```bash
tofu -chdir=tofu/talos_cluster init

CLUSTER_IP="1.2.3.4" # main IP (VIP) of the cluster
tofu -chdir=tofu/talos_cluster apply -var-file=../dexter.tfvars --var="cluster_endpoint=${CLUSTER_IP}"

talosctl config merge <(tofu -chdir=tofu/talos_cluster output -raw talosconfig)
# you need konfig plugin for that: kubectl krew install konfig
printf '%s' "$(kubectl konfig import <(tofu -chdir=tofu/talos_cluster output -raw kubeconfig))" > "${KUBECONFIG}"
```
