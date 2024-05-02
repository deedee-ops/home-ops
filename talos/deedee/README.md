# DeeDee

## Bootstrap

```bash
# generate manifests
bash -c 'cd talos/deedee && talhelper genconfig'

# provision talos
talosctl -n 10.100.21.10 apply-config --file talos/deedee/clusterconfig/deedee-huey.yaml --insecure
talosctl -n 10.100.21.11 apply-config --file talos/deedee/clusterconfig/deedee-dewey.yaml --insecure
talosctl -n 10.100.21.12 apply-config --file talos/deedee/clusterconfig/deedee-louie.yaml --insecure
talosctl -n 10.100.21.20 apply-config --file talos/deedee/clusterconfig/deedee-blossom.yaml --insecure
talosctl -n 10.100.21.21 apply-config --file talos/deedee/clusterconfig/deedee-bubbles.yaml --insecure
talosctl -n 10.100.21.22 apply-config --file talos/deedee/clusterconfig/deedee-buttercup.yaml --insecure

# add talosconfig
talosctl config merge talos/deedee/clusterconfig/talosconfig

# bootstrap the cluster
talosctl -n 10.100.21.10 bootstrap

# add kubeconfig
talosctl -n 10.100.21.10 kubeconfig -m
```
