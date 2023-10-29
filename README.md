## dexter

```bash
tofu -chdir=tofu/talos_cluster init
tofu -chdir=tofu/talos_cluster apply -var-file=../dexter.tfvars

talosctl config merge <(tofu -chdir=tofu/talos_cluster output -raw talosconfig)
# you need konfig plugin for that: kubectl krew install konfig
printf '%s' "$(kubectl konfig import <(tofu -chdir=tofu/talos_cluster output -raw kubeconfig))" > "${KUBECONFIG}"

# after cluster provisions
go-task volsync:restore rsrc=vault namespace=vault
k apply -f kubernetes/clusters/dexter/argocd/app-of-apps/application.yaml
```
