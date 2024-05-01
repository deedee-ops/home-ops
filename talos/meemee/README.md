# meemee

## Bootstrap

```bash
# generate manifests
bash -c 'cd talos/meemee && talhelper genconfig'

# provision talos
talosctl -n 10.100.91.1 apply-config --file talos/meemee/clusterconfig/meemee-ed.yaml --insecure
talosctl -n 10.100.91.2 apply-config --file talos/meemee/clusterconfig/meemee-edd.yaml --insecure
talosctl -n 10.100.91.3 apply-config --file talos/meemee/clusterconfig/meemee-eddy.yaml --insecure
talosctl -n 10.100.92.1 apply-config --file talos/meemee/clusterconfig/meemee-naruto.yaml --insecure
talosctl -n 10.100.92.2 apply-config --file talos/meemee/clusterconfig/meemee-sakura.yaml --insecure
talosctl -n 10.100.92.3 apply-config --file talos/meemee/clusterconfig/meemee-sasuke.yaml --insecure

# add talosconfig
talosctl config merge talos/meemee/clusterconfig/talosconfig

# bootstrap the cluster
talosctl -n 10.100.91.1 bootstrap

# add kubeconfig
talosctl -n 10.100.91.1 kubeconfig -m
```
