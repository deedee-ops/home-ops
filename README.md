<!-- markdownlint-disable MD013 MD033 MD041 -->
<div align="center">
  <img src="docs/img/k8shappy.png" alt="kubepepe">
  <br>
  <sup><sup>
    Art by <a href="https://twitter.com/SkeletalGadget">@SkeletalGadget</a>
  </sup></sup>

### My Home Operations Repository ☸

_... automated via [ArgoCD](https://argoproj.github.io/cd/), [Renovate](https://github.com/renovatebot/renovate) and [GitHub Actions](https://github.com/features/actions)_ 🤖

</div>
<!-- markdownlint-enable MD013 MD033 -->

---

## 🚧 NO LONGER MAINTAINED

> [!IMPORTANT]
> As of October 11th, 2024, I am no longer using Kubernetes in my homelab.
>
> Thank you to everyone that has followed, had questions and learnt from my k8s journey.
>
> My new homelab repo is built with Nix + NixOS at can be found at: <https://github.com/deedee-ops/nixlab>
>
> This will be publically archived for learning purposes but please note that it will be outdated.

---

## 📖 Overview

This is a repository for my home infrastructure and Kubernetes cluster.
I try to adhere to Infrastructure as Code (IaC) and GitOps practices using tools like [OpenTofu](https://opentofu.org/),
[Kubernetes](https://kubernetes.io), [ArgoCD](https://argoproj.github.io/cd/), [Renovate](https://github.com/renovatebot/renovate)
and [GitHub Actions](https://github.com/features/actions).

---

## ⛵ Kubernetes

### Installation

This semi hyper-converged cluster runs [Talos Linux](https://talos.dev), an immutable and ephemeral Linux distribution
built for [Kubernetes](https://kubernetes.io), deployed on bare-metal [Intel NUCs](https://www.intel.com/content/www/us/en/products/details/nuc.html).
[Rook](https://rook.io) then provides my workloads with persistent block, and file storage;
while a seperate server provides file storage for my media.

### Core Components

- [actions-runner-controller](https://github.com/actions/actions-runner-controller): Self-hosted Github runners.
- [cilium](https://cilium.io): Internal Kubernetes networking plugin.
- [cert-manager](https://cert-manager.io): Creates SSL certificates for services in my Kubernetes cluster.
- [external-dns](https://github.com/kubernetes-sigs/external-dns): Automatically manages DNS records from my cluster
  in a cloud DNS provider.
- [ingress-nginx](https://github.com/kubernetes/ingress-nginx): Ingress controller for Kubernetes using NGINX as
  a reverse proxy and load balancer.
- [rook](https://rook.io): Distributed block storage for peristent storage.
- [spegel](https://github.com/XenitAB/spegel): Stateless cluster local OCI registry mirror.
- [vault](https://www.vaultproject.io/): Safe and encrypted storage for all Kubernetes secrets.
- [volsync](https://github.com/backube/volsync): Backup and recovery of persistent volume claims.

### GitOps

[ArgoCD](https://argoproj.github.io/cd/) watches the clusters in my [kubernetes](./kubernetes/) folder
(see Directories below), and makes the changes to my clusters based on the state of my Git repository.

The way ArgoCD works for me here is it will recursively search the `kubernetes/clusters/${cluster}` folder,
and deploys all `application.yaml` manifests. I follow "app of apps" pattern, so cluster apps can include other apps,
which can be shared between clusters, and which live under `kubernetes/apps` directory.

[Renovate](https://github.com/renovatebot/renovate) watches my **entire** repository looking for dependency updates.
When they are found a PR is automatically created. When some PRs are merged ArgoCD applies the changes to my cluster.

### Directories

This Git repository contains the following directories under [Kubernetes](./kubernetes/).

```sh
📁 kubernetes
├── 📁 apps           # applications
└── 📁 clusters       # clusters
    ├── 📁 deedee     # main cluster
    └── 📁 meemee     # development cluster, deployed on VMs
📁 opentofu           # opentofu scripts for external services (cloudflare)
📁 talos              # talhelper scripts to bootstrap Talos
```

---

## ☁️ Cloud Dependencies

While most of my infrastructure and workloads are self-hosted I do rely upon the cloud for certain key parts of my setup.
This saves me from having to worry about two things. (1) Dealing with chicken/egg scenarios and (2) services I critically
need whether my cluster is online or not.

| Service                                   | Use                                                            | Cost           |
|-------------------------------------------|----------------------------------------------------------------|----------------|
| [addy.io](https://addy.io/)               | Email address protection                                       | $12/yr         |
| [BorgBase](https://www.borgbase.com/)     | Backups                                                        | $80/yr         |
| [Cloudflare](https://www.cloudflare.com/) | Domains and tunnel                                             | Free           |
| [GitHub](https://github.com/)             | Hosting this repository and continuous integration/deployments | Free           |
| [Migadu](https://migadu.com/)             | Email hosting                                                  | $19/yr         |
| [Pushover](https://pushover.net/)         | Kubernetes Alerts and application notifications                | $5 (one time)  |
|                                           |                                                                | Total: ~$10/mo |

---

## 🔧 Hardware

| Device                      | Count | OS Disk Size | Data Disk Size                             | Ram  | Operating System   | Purpose             |
|-----------------------------|-------|--------------|--------------------------------------------|------|--------------------|---------------------|
| Dell Wyse 5070              | 3     | 128GB SSD    | -                                          | 8GB  | Talos Linux        | Kubernetes Masters  |
| Intel NUC12WSHi5            | 3     | 128GB SSD    | 512GB NVMe & 1TB PLP SSD(rook-ceph)        | 64GB | Talos Linux        | Kubernetes Workers  |
| Synology DS1621+            | 1     | 256GB SSD    | 4x4TB HDD (mirrored)                       | 32GB | Synology DSM       | NFS + Backup Server |
| Minisforum MS-01            | 1     | 1TB SSD      | -                                          | 48GB | Proxmox PVE        | Router + VMs        |
| TP-LINK SG3428X-M2          | 1     | -            | -                                          | -    | -                  | 2.5Gb Core Switch   |
| TP-LINK SG2005P-PD          | 1     | -            | -                                          | -    | -                  | 1Gb PoE Switch      |

---

## ⭐ Stargazers

<!-- markdownlint-disable MD013 MD033 -->
<div align="center">

<a href="https://star-history.com/#deedee-ops/home-ops&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=deedee-ops/home-ops&type=Date&theme=dark" />
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=deedee-ops/home-ops&type=Date" />
    <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=deedee-ops/home-ops&type=Date" />
  </picture>
</a>

</div>
<!-- markdownlint-enable MD013 MD033 -->

---

## 🤝 Gratitude and Thanks

Thanks to all the people who donate their time to the [Home Operations](https://discord.gg/home-operations) Discord community.
Be sure to check out [kubesearch.dev](https://kubesearch.dev/) for ideas on how to deploy applications
or get ideas on what you may deploy.

---

## 📜 Changelog

See my _awful_ [commit history](https://github.com/deedee-ops/home-ops/commits/master)

---

## 🔏 License

See [LICENSE](./LICENSE)
