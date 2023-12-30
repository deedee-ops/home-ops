# meemee

## Bootstrap

```bash
# generate manifests
bash -c 'cd talos/meemee && talhelper genconfig'

# provision talos
talosctl -n 10.100.25.10 apply-config --file talos/meemee/clusterconfig/meemee-meemee.yaml --insecure

# add talosconfig
talosctl config merge talos/meemee/clusterconfig/talosconfig

# bootstrap the cluster
talosctl -n 10.100.25.10 bootstrap

# add kubeconfig
talosctl -n 10.100.25.10 kubeconfig -m
```
