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

### Stage 0: talos

- Refer to corresponding cluster README: [meemee](../talos/meemee/README.md) or [deedee](../talos/deedee/README.md)
- Nodes will be in `NotReady` state with networking errors - this is expected, as there is no CNI at this moment.

### Stage 1: Cilium, rook-ceph and ArgoCD

- Set cluster to be deployed

    ```bash
    export CLUSTER=deedee # or meemee
    ```

- Bootstrap cilium, rook-ceph and argocd

    ```bash
    go-task bootstrap:stage1 cluster=${CLUSTER}
    ```

- Create proper CRUSH map for ceph

    ```bash
    go-task ceph:build-crush-map cluster=${CLUSTER}
    ```

- If ceph blockpools or filesystems, are stuck in "progressing" state, just delete them, and reapply rook-ceph-cluster manifest:

    ```bash
    helm template -n rook-ceph -f "talos/${CLUSTER}/values.bootstrap.yaml" rook-ceph-cluster kubernetes/apps/rook-ceph/rook-ceph-cluster/ | kubectl apply -n rook-ceph -f -
    ```

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
    kubectl apply -f kubernetes/clusters/${CLUSTER}/argocd/app-of-apps/application.yaml
    ```
