# Dexter

## Bootstrap

```bash
# generate manifests
bash -c 'cd talos/dexter && talhelper genconfig'

# provision talos
talosctl -n 10.100.91.1 apply-config --file talos/dexter/clusterconfig/dexter-ed.yaml --insecure
talosctl -n 10.100.91.2 apply-config --file talos/dexter/clusterconfig/dexter-edd.yaml --insecure
talosctl -n 10.100.91.3 apply-config --file talos/dexter/clusterconfig/dexter-eddy.yaml --insecure
talosctl -n 10.100.92.1 apply-config --file talos/dexter/clusterconfig/dexter-naruto.yaml --insecure
talosctl -n 10.100.92.2 apply-config --file talos/dexter/clusterconfig/dexter-sakura.yaml --insecure
talosctl -n 10.100.92.3 apply-config --file talos/dexter/clusterconfig/dexter-sasuke.yaml --insecure

# add talosconfig
talosctl config merge talos/dexter/clusterconfig/talosconfig

# bootstrap the cluster
talosctl -n 10.100.91.1 bootstrap

# add kubeconfig
talosctl -n 10.100.91.1 kubeconfig -m
```
