local cilium = std.extVar('cilium');

if std.objectHas(cilium, 'l2announcements') && cilium.l2announcements.enabled then {
  apiVersion: "cilium.io/v2alpha1",
  kind: "CiliumL2AnnouncementPolicy",
  metadata: {
    name: "l2-policy",
  },
  spec: {
    loadBalancerIPs: true,
    nodeSelector: {
      matchLabels: {
        "kubernetes.io/os": "linux",
      },
    },
  },
} else {}
