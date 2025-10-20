local cilium = std.extVar('cilium');

if std.objectHas(cilium, 'custom') &&
   std.objectHas(cilium.custom, 'pools') &&
   std.type(cilium.custom.pools) == 'array' &&
   std.length(cilium.custom.pools) > 0 then {
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
