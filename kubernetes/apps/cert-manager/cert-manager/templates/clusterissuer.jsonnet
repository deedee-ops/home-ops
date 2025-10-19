local global = std.extVar('global');

[
  {
    apiVersion: 'cert-manager.io/v1',
    kind: 'ClusterIssuer',
    metadata: {
      name: 'letsencrypt-production',
    },
    spec: {
      acme: {
        server: 'https://acme-v02.api.letsencrypt.org/directory',
        privateKeySecretRef: {
          name: 'letsencrypt-production',
        },
        solvers: [
          {
            dns01: {
              cloudflare: {
                apiTokenSecretRef: {
                  name: 'cloudflare-issuer-secret',
                  key: 'CLOUDFLARE_DNS_TOKEN',
                },
              },
            },
            selector: {
              dnsZones: [global.rootDomain],
            },
          },
        ],
      },
    },
  },
  {
    apiVersion: 'cert-manager.io/v1',
    kind: 'ClusterIssuer',
    metadata: {
      name: 'letsencrypt-staging',
    },
    spec: {
      acme: {
        server: 'https://acme-staging-v02.api.letsencrypt.org/directory',
        privateKeySecretRef: {
          name: 'letsencrypt-staging',
        },
        solvers: [
          {
            dns01: {
              cloudflare: {
                apiTokenSecretRef: {
                  name: 'cloudflare-issuer-secret',
                  key: 'CLOUDFLARE_DNS_TOKEN',
                },
              },
            },
            selector: {
              dnsZones: [global.rootDomain],
            },
          },
        ],
      },
    },
  },
]
