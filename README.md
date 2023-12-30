<div align="center">
  <img src="docs/img/k8shappy.png">
  <br>
  <sup><sup>
    Art by <a href="https://twitter.com/SkeletalGadget">@SkeletalGadget</a>
  </sup></sup>

### My Home Operations Repository ☸

_... automated via [ArgoCD](https://argoproj.github.io/cd/), [Renovate](https://github.com/renovatebot/renovate) and [GitHub Actions](https://github.com/features/actions)_ 🤖

</div>

<div align="center">

[![Discord](https://img.shields.io/discord/673534664354430999?style=for-the-badge&label&logo=discord&logoColor=white&color=blue)](https://discord.gg/home-operations)&nbsp;&nbsp;
[![Kubernetes](https://img.shields.io/badge/dynamic/yaml?url=https%3A%2F%2Fraw.githubusercontent.com%2Fdeedee-ops%2Fhome-ops%2Fmaster%2Fkubernetes%2Fapps%2Fkube-system%2Fsystem-upgrade-controller%2Ftemplates%2Fplans%2Fkubernetes.yaml&query=%24.spec.version&style=for-the-badge&logo=kubernetes&logoColor=white&label=%20)](https://kubernetes.io)&nbsp;&nbsp;
[![Renovate](https://img.shields.io/github/actions/workflow/status/deedee-ops/home-ops/renovate.yaml?branch=master&label=&logo=renovatebot&style=for-the-badge&color=blue)](https://github.com/deedee-ops/home-ops/actions/workflows/renovate.yaml)

</div>

<div align="center">

[![Age-Days](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.rzegocki.dev%2Fquery%3Fformat%3Dendpoint%26metric%3Dcluster_age_days&style=flat-square&label=Age)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
[![Uptime-Days](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.rzegocki.dev%2Fquery%3Fformat%3Dendpoint%26metric%3Dcluster_uptime_days&style=flat-square&label=Uptime)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
[![Node-Count](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.rzegocki.dev%2Fquery%3Fformat%3Dendpoint%26metric%3Dcluster_node_count&style=flat-square&label=Nodes)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
[![Pod-Count](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.rzegocki.dev%2Fquery%3Fformat%3Dendpoint%26metric%3Dcluster_pod_count&style=flat-square&label=Pods)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
[![CPU-Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.rzegocki.dev%2Fquery%3Fformat%3Dendpoint%26metric%3Dcluster_cpu_usage&style=flat-square&label=CPU)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
[![Memory-Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.rzegocki.dev%2Fquery%3Fformat%3Dendpoint%26metric%3Dcluster_memory_usage&style=flat-square&label=Memory)](https://github.com/kashalls/kromgo/)

</div>

---

## 📖 Overview

This is a repository for my home infrastructure and Kubernetes cluster. I try to adhere to Infrastructure as Code (IaC) and GitOps practices using tools like [OpenTofu](https://opentofu.org/), [Kubernetes](https://kubernetes.io), [ArgoCD](https://argoproj.github.io/cd/), [Renovate](https://github.com/renovatebot/renovate) and [GitHub Actions](https://github.com/features/actions).

---

## ⛵ Kubernetes

### Installation

This semi hyper-converged cluster runs [Talos Linux](https://talos.dev), an immutable and ephemeral Linux distribution built for [Kubernetes](https://kubernetes.io), deployed on bare-metal [Intel NUCs](https://www.intel.com/content/www/us/en/products/details/nuc.html). [Rook](https://rook.io) then provides my workloads with persistent block, and file storage; while a seperate server provides file storage for my media.

### Core Components

- [cilium](https://cilium.io): Internal Kubernetes networking plugin.
- [cert-manager](https://cert-manager.io): Creates SSL certificates for services in my Kubernetes cluster.
- [external-dns](https://github.com/kubernetes-sigs/external-dns): Automatically manages DNS records from my cluster in a cloud DNS provider.
- [ingress-nginx](https://github.com/kubernetes/ingress-nginx): Ingress controller for Kubernetes using NGINX as a reverse proxy and load balancer.
- [rook](https://rook.io): Distributed block storage for peristent storage.
- [vault](https://www.vaultproject.io/): Safe and encrypted storage for all Kubernetes secrets.
- [volsync](https://github.com/backube/volsync): Backup and recovery of persistent volume claims.

### GitOps

[ArgoCD](https://argoproj.github.io/cd/) watches the clusters in my [kubernetes](./kubernetes/) folder (see Directories below) and makes the changes to my clusters based on the state of my Git repository.

The way ArgoCD works for me here is it will recursively search the `kubernetes/clusters/${cluster}` folder and deploys all `application.yaml` manifests. I follow "app of apps" pattern, so cluster apps can include other apps, which can be shared between clusters, and which live under `kubernetes/apps` directory.

[Renovate](https://github.com/renovatebot/renovate) watches my **entire** repository looking for dependency updates, when they are found a PR is automatically created. When some PRs are merged Flux applies the changes to my cluster.

### Directories

This Git repository contains the following directories under [Kubernetes](./kubernetes/).

```sh
📁 kubernetes
├── 📁 apps           # applications
└── 📁 clusters       # clusters
    ├── 📁 deedee     # main cluster
    └── 📁 dexter     # development cluster, deployed on VMs
📁 opentofu           # opentofu scripts for external services (cloudflare)
📁 talos              # talhelper scripts to bootstrap Talos
```


## 🔧 Hardware

| Device                      | Count | OS Disk Size | Data Disk Size                             | Ram  | Operating System   | Purpose             |
|-----------------------------|-------|--------------|--------------------------------------------|------|--------------------|---------------------|
| Dell Wyse 5070              | 3     | 128GB SSD    | -                                          | 8GB  | Talos Linux        | Kubernetes Masters  |
| Intel NUC12WSHi5            | 3     | 128GB SSD    | 512GB NVMe & 1TB PLP SSD(rook-ceph)        | 64GB | Talos Linux        | Kubernetes Workers  |
| Synology DS1621+            | 1     | 256GB SSD    | 4x4TB HDD (mirrored)                       | 32GB | Synology DSM       | NFS + Backup Server |
| Protectli F4WB              | 1     | 256GB SSD    | -                                          | 8GB  | OpnSense (FreeBSD) | Router              |
| MikroTik CSS326-24G-2S+RM   | 1     | -            | -                                          | -    | SwitchOS           | 1Gb Core Switch     |

---

## ⭐ Stargazers

<div align="center">

<a href="https://star-history.com/#deedee-ops/home-ops&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=deedee-ops/home-ops&type=Date&theme=dark" />
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=deedee-ops/home-ops&type=Date" />
    <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=deedee-ops/home-ops&type=Date" />
  </picture>
</a>

</div>

---

## 🤝 Gratitude and Thanks

Thanks to all the people who donate their time to the [Home Operations](https://discord.gg/home-operations) Discord community. Be sure to check out [kubesearch.dev](https://kubesearch.dev/) for ideas on how to deploy applications or get ideas on what you may deploy.

---

## 📜 Changelog

See my _awful_ [commit history](https://github.com/deedee-ops/home-ops/commits/master)

---

## 🔏 License

See [LICENSE](./LICENSE)
