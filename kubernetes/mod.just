set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

kubernetes_dir := justfile_dir() + '/kubernetes'

[private]
default:
    just -l kube

[doc('Open a shell on a node')]
node-shell node:
    kubectl debug node/{{ node }} -n kube-system -it --image="mirror.gcr.io/alpine:latest" --profile sysadmin
    kubectl delete pod -n kube-system -l app.kubernetes.io/managed-by=kubectl-debug
