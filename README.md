## dexter

```bash
tofu -chdir=tofu/talos_cluster init
tofu -chdir=tofu/talos_cluster apply -var-file=../dexter.tfvars

talosctl config merge <(tofu -chdir=tofu/talos_cluster output -raw talosconfig)
# you need konfig plugin for that: kubectl krew install konfig
printf '%s' "$(kubectl konfig import <(tofu -chdir=tofu/talos_cluster output -raw kubeconfig))" > "${KUBECONFIG}"

# after cluster provisions
go-task ceph:build-crush-map tfvars=tofu/dexter.tfvars
for v in 0 1 2; do go-task volsync:restore rsrc=vault namespace=vault claim=data-vault-$v previous=1; done
kubectl apply -f kubernetes/clusters/dexter/argocd/app-of-apps/application.yaml
```
