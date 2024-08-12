# INSTALL

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

### Stage 1: kubernetes

- Set cluster to be deployed

    ```bash
    export CLUSTER=deedee # or meemee
    ```

- Bootstrap the crucial cluster services

    ```bash
    go-task bootstrap cluster=${CLUSTER}
    ```

### Stage 2: app-of-apps

- Bootstrap everything else

    ```bash
    kubectl apply -f kubernetes/clusters/${CLUSTER}/argocd/app-of-apps/application.yaml
    ```
