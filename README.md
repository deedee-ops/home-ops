# homelab

## Bootstrap

### Stage 1: rook-ceph

- Bootstrap cluster

    ```bash
    tofu -chdir=tofu/talos_cluster init
    tofu -chdir=tofu/talos_cluster apply -var-file=../homelab.tfvars
    ```

- Wait for everything to deploy (all apps in ArgoCD are green)
- Create kubeconfig and talosconfig

    ```bash
    talosctl config merge <(tofu -chdir=tofu/talos_cluster output -raw talosconfig)
    # you need konfig plugin for that: kubectl krew install konfig
    printf '%s' "$(kubectl konfig import <(tofu -chdir=tofu/talos_cluster output -raw kubeconfig))" > "${KUBECONFIG}"
    ```

- Create proper CRUSH map for ceph

    ```bash
    go-task ceph:build-crush-map tfvars=tofu/homelab.tfvars
    ```

- If ceph blockpools or filesystems, are stuck in "progressing" state, just delete them. They should be recreated
  properly and attached to corresponding CRUSH map.

### Stage 2: vault

- Bootstrap volsync and vault

    ```bash
    go-task bootstrap:stage2
    ```

### Stage 3: app-of-apps

- Bootstrap everything else

    ```bash
    kubectl apply -f kubernetes/clusters/dexter/argocd/app-of-apps/application.yaml
    ```
