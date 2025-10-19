local global = std.extVar('global');

{
  apiVersion: 'cert-manager.io/v1',
  kind: 'Certificate',
  metadata: {
    name: 'root-domain',
  },
  spec: {
    secretName: 'root-domain-tls',
    issuerRef: {
      name: global.tls.clusterIssuer,
      kind: 'ClusterIssuer',
    },
    commonName: global.rootDomain,
    dnsNames: [
      global.rootDomain,
      '*.%s' % global.rootDomain,
    ],
  },
}

