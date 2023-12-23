# DeeDee

## Bootstrap

```bash
# generate manifests
bash -c 'cd talos/deedee && talhelper genconfig'

# provision talos
talosctl -n 10.100.21.10 apply-config --file talos/deedee/clusterconfig/deedee-huey.yaml --insecure
talosctl -n 10.100.21.11 apply-config --file talos/deedee/clusterconfig/deedee-dewie.yaml --insecure
talosctl -n 10.100.21.12 apply-config --file talos/deedee/clusterconfig/deedee-louie.yaml --insecure
talosctl -n 10.100.22.10 apply-config --file talos/deedee/clusterconfig/deedee-blossom.yaml --insecure
talosctl -n 10.100.22.11 apply-config --file talos/deedee/clusterconfig/deedee-bubbles.yaml --insecure
talosctl -n 10.100.22.12 apply-config --file talos/deedee/clusterconfig/deedee-buttercup.yaml --insecure

# add talosconfig
talosctl config merge talos/deedee/clusterconfig/talosconfig

# bootstrap the cluster
talosctl -n 10.100.21.10 bootstrap

# add kubeconfig
talosctl -n 10.100.21.10 kubeconfig -m
```
