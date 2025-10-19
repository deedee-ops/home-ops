local namespace = std.extVar('namespace');
local global = std.extVar('global');

{
  apiVersion: 'external-secrets.io/v1',
  kind: 'ClusterSecretStore',
  metadata: {
    name: 'onepassword',
  },
  spec: {
    provider: {
      onepassword: {
        connectHost: 'http://onepassword.external-secrets.svc.cluster.local:8080',
        vaults: {
          [global.clusterName]: 1,
        },
        auth: {
          secretRef: {
            connectTokenSecretRef: {
              name: 'onepassword-secret',
              namespace: 'external-secrets',
              key: 'token',
            },
          },
        },
      },
    },
  },
}
