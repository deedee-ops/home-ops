# homelab

## Prepare

### Zap disks for CEPH

```bash
DISK="/dev/sdX"

# Zap the disk to a fresh, usable state (zap-all is important, b/c MBR has to be clean)
sgdisk --zap-all $DISK

# Wipe a large portion of the beginning of the disk to remove more LVM metadata that may be present
dd if=/dev/zero of="$DISK" bs=1M count=100 oflag=direct,dsync

# SSDs may be better cleaned with blkdiscard instead of dd
blkdiscard $DISK

# Inform the OS of partition table changes
partprobe $DISK
```

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

### Stage 2: volsync and vault

- Bootstrap volsync and vault

    ```bash
    go-task bootstrap:stage2
    ```

### Stage 3: crucial apps to keep clsuter running

- Bootstrap all supporting and monitoring apps

    ```bash
    go-task bootstrap:stage3
    ```

### Stage 4: app-of-apps

- Bootstrap everything else

    ```bash
    kubectl apply -f kubernetes/clusters/dexter/argocd/app-of-apps/application.yaml
    ```
