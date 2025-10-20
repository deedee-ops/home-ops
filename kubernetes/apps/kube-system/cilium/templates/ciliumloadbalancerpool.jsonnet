local cilium = std.extVar('cilium');

if cilium.custom && cilium.custom.pools then {
  apiVersion: 'cilium.io/v2alpha1',
  kind: 'CiliumLoadBalancerIPPool',
  metadata: {
    name: 'pool',
  },
  spec: {
    allowFirstLastIPs: 'No',
    blocks: [{ cidr: cidr } for cidr in cilium.custom.pools],
  },
} else {}
