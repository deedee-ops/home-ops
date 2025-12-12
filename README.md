<!-- markdownlint-disable MD013 MD033 MD041 -->
<div align="center">
  <img src="https://raw.githubusercontent.com/deedee-ops/home-ops/refs/heads/assets/k8shappy.png" alt="kubepepe" />
  <br>
  <sup><sup>
    Art by <a href="https://twitter.com/SkeletalGadget">@SkeletalGadget</a>
  </sup></sup>

### My Home Operations Repository ☸

_... managed with [Flux](https://fluxcd.io/), [Komodo](https://komo.do/), [OpenTofu](https://opentofu.org/), [Renovate](https://github.com/renovatebot/renovate) and [GitHub Actions](https://github.com/features/actions)_ 🤖

</div>

<div align="center">

[![Discord](https://img.shields.io/discord/673534664354430999?style=for-the-badge&label&logo=discord&logoColor=white&color=blue)](https://discord.gg/home-operations)&nbsp;&nbsp;
[![Talos](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.ajgon.casa%2Ftalos_version%3Fformat%3Dendpoint&style=for-the-badge&logo=talos&logoColor=white&color=blue&label=%20)](https://www.talos.dev/)&nbsp;&nbsp;
[![Kubernetes](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.ajgon.casa%2Fkubernetes_version%3Fformat%3Dendpoint&style=for-the-badge&logo=kubernetes&logoColor=white&color=blue&label=%20)](https://kubernetes.io/)&nbsp;&nbsp;
[![Flux](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.ajgon.casa%2Fflux_version&style=for-the-badge&logo=flux&logoColor=white&color=blue&label=%20)](https://fluxcd.io)&nbsp;&nbsp;
[![Renovate](https://img.shields.io/github/actions/workflow/status/deedee-ops/home-ops/renovate.yaml?branch=master&label=&logo=renovatebot&style=for-the-badge&color=blue)](https://github.com/deedee-ops/home-ops/actions/workflows/renovate.yaml)

</div>

<div align="center">

[![Age-Days](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.ajgon.casa%2Fcluster_age_days%3Fformat%3Dendpoint&style=flat-square&label=Age)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
[![Uptime-Days](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.ajgon.casa%2Fcluster_uptime_days%3Fformat%3Dendpoint&style=flat-square&label=Uptime)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
[![Node-Count](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.ajgon.casa%2Fcluster_node_count%3Fformat%3Dendpoint&style=flat-square&label=Nodes)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
[![Pod-Count](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.ajgon.casa%2Fcluster_pod_count%3Fformat%3Dendpoint&style=flat-square&label=Pods)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
[![CPU-Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.ajgon.casa%2Fcluster_cpu_usage%3Fformat%3Dendpoint&style=flat-square&label=CPU)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
[![Memory-Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.ajgon.casa%2Fcluster_memory_usage%3Fformat%3Dendpoint&style=flat-square&label=Memory)](https://github.com/kashalls/kromgo/)&nbsp;
[![Alerts](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.ajgon.casa%2Fcluster_alert_count%3Fformat%3Dendpoint&style=flat-square&label=Alerts)](https://github.com/kashalls/kromgo/)&nbsp;

</div>
<!-- markdownlint-enable MD013 MD033 -->

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f4a1/512.gif" alt="💡" width="20" height="20" /> Overview

This is a mono repository for my home infrastructure and Kubernetes cluster. I try to adhere to Infrastructure as Code
(IaC) and GitOps practices using tools like [Komodo](https://komo.do/), [OpenTofu](https://www.opentofu.org/),
[Kubernetes](https://kubernetes.io/), [Flux](https://github.com/fluxcd/flux2), [Renovate](https://github.com/renovatebot/renovate),
and [GitHub Actions](https://github.com/features/actions).

> [!NOTE]
> Old [ArgoCD](https://argo-cd.readthedocs.io/en/stable/) is not maintained anymore,
> but it is [available here](https://github.com/deedee-ops/home-ops/tree/argocd-legacy) for reference.

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f331/512.gif" alt="🌱" width="20" height="20" /> Kubernetes

My Kubernetes cluster is deployed with [Talos](https://www.talos.dev). This is a semi-hyper-converged cluster, workloads
and block storage are sharing the same available resources on my nodes while I have a separate server with ZFS
for NFS/SMB shares, bulk file storage and backups.

There is a [great template made by onedr0p](https://github.com/onedr0p/cluster-template) if you want to try and follow
along with some of the practices I use here.

### Core Components

- **Networking & Service Mesh**: [cilium](https://github.com/cilium/cilium) provides eBPF-based networking,
  [cloudflared](https://github.com/cloudflare/cloudflared) secures ingress traffic via Cloudflare,
  and [external-dns](https://github.com/kubernetes-sigs/external-dns) keeps DNS records in sync automatically.
  All egress traffic is carefuly filtered using network policies.
- **Security & Secrets**: [cert-manager](https://github.com/cert-manager/cert-manager) automates SSL/TLS certificate
  management. For secrets, I use [external-secrets](https://github.com/external-secrets/external-secrets) with
  self-hosted [HashiCorp Vault](https://www.hashicorp.com/en/products/vault) to inject secrets into Kubernetes.
- **Storage & Data Protection**: [rook](https://github.com/rook/rook) provides distributed storage for persistent
  volumes, with [volsync](https://github.com/backube/volsync) handling backups and restores.
  [spegel](https://github.com/spegel-org/spegel) improves reliability by running a stateless, cluster-local OCI image mirror.
- **Automation & CI/CD**: [actions-runner-controller](https://github.com/actions/actions-runner-controller) runs
  self-hosted GitHub Actions runners directly in the cluster for continuous integration workflows.

### GitOps

[Flux](https://github.com/fluxcd/flux2) watches the clusters in my [kubernetes](./kubernetes/) folder
(see Directories below) and makes the changes to my clusters based on the state of my Git repository.

The way Flux works for me here is it will recursively search the `kubernetes/clusters/<cluster name>` folder
until it finds the most top level `kustomization.yaml` per directory and then apply all the resources listed in it.
That aforementioned `kustomization.yaml` will generally only have a namespace resource and per-cluster Flux kustomization
for subset of apps used in said cluster. Under the control of those Flux kustomizations there will be a `HelmRelease`
or other resources related to the application which will be applied.

[Renovate](https://github.com/renovatebot/renovate) watches my **entire** repository looking for dependency updates,
when they are found a PR is automatically created. When some PRs are merged Flux applies the changes to my cluster.

### Docker

Machines which are not feesible to be maintained by kubernetes (like NAS), are managed by [Komodo](https://komo.do)
and [Docker Compose](https://compose-spec.io/) files. Directories are organized similar to flux flow - there are global
`stacks` with application configuration meant to be shared among machines, and `hosts` configurations with fine-tuned
per-machine options.

### Directories

This Git repository contains the following directories.

```sh
📁 bootstrap      # initial set of files necessary to kickstart the cluster
📁 docker
├── 📁 hosts      # per-host docker compose komodo configurations
└── 📁 stacks     # application templates with base rules shared among machines
📁 kubernetes
├── 📁 apps       # application templates with base rules shared among clusters
├── 📁 clusters   # per-cluster configurations of said apps
└── 📁 components # re-useable kustomize components
📁 opentofu       # opentofu plans for external services like cloudflare
📁 talos          # per-cluster talos configurations
```

---

<!-- markdownlint-disable MD013 -->
## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f636_200d_1f32b_fe0f/512.gif" alt="😶" width="20" height="20" /> Cloud Dependencies
<!-- markdownlint-enable MD013 -->

While most of my infrastructure and workloads are self-hosted I do rely upon the cloud for certain key parts of my setup.
This saves me from having to worry about three things. (1) Dealing with chicken/egg scenarios, (2) services I critically
need whether my cluster is online or not and (3) The "hit by a bus factor" - what happens to critical apps
(e.g. Email, Password Manager, Photos) that my family relies on when I no longer around.

| Service                                   | Use                                                            | Cost           |
|-------------------------------------------|----------------------------------------------------------------|----------------|
| [BorgBase](https://www.borgbase.com/)     | Borg Backups                                                   | $80/yr         |
| [Cloudflare](https://www.cloudflare.com/) | Services exposed externally                                    | Free           |
| [GitHub](https://github.com/)             | Hosting this repository and continuous integration/deployments | Free           |
| [Migadu](https://migadu.com/)             | Email hosting                                                  | $19/yr         |
| [NextDNS](https://nextdns.io/)            | Ad filtering                                                   | ~$20/yr        |
| [Pushover](https://pushover.net/)         | Kubernetes Alerts and application notifications                | $5 OTP         |
|                                           |                                                                | Total: ~$10/mo |

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f30e/512.gif" alt="🌎" width="20" height="20" /> DNS

In my cluster there are two instances of [ExternalDNS](https://github.com/kubernetes-sigs/external-dns) running.
One for syncing private DNS records to my `UCG Ultra` using [ExternalDNS webhook provider for UniFi](https://github.com/kashalls/external-dns-unifi-webhook),
while another instance syncs public DNS to `Cloudflare`. This setup is managed by creating ingresses with two specific
classes: `internal` for private DNS and `external` for public DNS. The `external-dns` instances then syncs
the DNS records to their respective platforms accordingly.

---

<!-- markdownlint-disable MD013 -->
## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/2699_fe0f/512.gif" alt="⚙" width="20" height="20" /> Hardware
<!-- markdownlint-enable MD013 -->

<!-- markdownlint-disable MD013 MD033 -->
<details>
  <summary>Click here to see my server rack</summary>

  <img src="https://raw.githubusercontent.com/deedee-ops/home-ops/refs/heads/assets/rack-20251212.jpg" align="center" width="250px" alt="rack" />
</details>
<!-- markdownlint-enable MD013 MD033 -->

| Device                            | Num | OS Disk Size | Data Disk Size                  | Ram  | OS            | Function                |
|-----------------------------------|-----|--------------|---------------------------------|------|---------------|-------------------------|
| Intel NUC12WSHi5                  | 3   | 512GB NVME   | 1TB (rook-ceph)                 | 64GB | Talos         | Kubernetes              |
| AMD Ryzen + GB B550I Aorus Pro AX | 1   | 1TB SSD      | 2x26TB ZFS (mirrored) + 4TB SSD | 64GB | TrueNAS SCALE | NFS + Backup Server     |
| JetKVM + AIMOS HDMI KVM Switch    | 1   | -            | -                               | -    | -             | KVM for Kubernetes      |
| UniFi UCG Ultra                   | 1   | -            | -                               | -    | -             | Router                  |
| UniFi USW-Pro-Max-16-PoE          | 1   | -            | -                               | -    | -             | 1Gb+2.5Gb PoE Switch    |

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f31f/512.gif" alt="🌟" width="20" height="20" /> Stargazers

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

<!-- markdownlint-disable MD013 -->
## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f64f/512.gif" alt="🙏" width="20" height="20" /> Gratitude and Thanks
<!-- markdownlint-enable MD013 -->

Thanks to all the people who donate their time to the [Home Operations](https://discord.gg/home-operations) Discord community.
Be sure to check out [kubesearch.dev](https://kubesearch.dev/) for ideas on how to deploy applications
or get ideas on what you could deploy.
