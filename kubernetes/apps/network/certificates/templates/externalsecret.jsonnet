local global = std.extVar('global');

{
  apiVersion: 'external-secrets.io/v1',
  kind: 'ExternalSecret',
  metadata: {
    name: 'root-domain-tls',
  },
  spec: {
    refreshPolicy: 'CreatedOnce',
    secretStoreRef: {
      kind: 'ClusterSecretStore',
      name: 'onepassword',
    },
    target: {
      name: 'root-domain-tls-test',
      creationPolicy: 'Orphan',
      template: {
        type: 'kubernetes.io/tls',
        metadata: {
          annotations: {
            'cert-manager.io/alt-names': '*.%s,%s' % [global.rootDomain, global.rootDomain],
            'cert-manager.io/certificate-name': 'root-domain',
            'cert-manager.io/common-name': global.rootDomain,
            'cert-manager.io/ip-sans': '',
            'cert-manager.io/issuer-group': '',
            'cert-manager.io/issuer-kind': 'ClusterIssuer',
            'cert-manager.io/issuer-name': global.tls.clusterIssuer,
            'cert-manager.io/uri-sans': '',
          },
          labels: {
            'controller.cert-manager.io/fao': 'true',
          },
        },
      },
    },
    dataFrom: [
      {
        extract: {
          key: 'root-domain-tls',
          decodingStrategy: 'Base64',
        },
      },
    ],
  },
}
