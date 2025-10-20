local global = std.extVar('global');

{
  apiVersion: 'gateway.networking.k8s.io/v1',
  kind: 'Gateway',
  metadata: {
    name: 'envoy-internal',
    annotations: {
      'external-dns.alpha.kubernetes.io/target': 'internal.%s' % global.rootDomain,
    },
  },
  spec: {
    gatewayClassName: 'envoy',
    infrastructure: {
      annotations: {
        'external-dns.alpha.kubernetes.io/hostname': 'internal.%s' % global.rootDomain,
      },
    },
    listeners: [
      {
        name: 'http',
        protocol: 'HTTP',
        port: 80,
        allowedRoutes: {
          namespaces: {
            from: 'Same',
          },
        },
      },
      {
        name: 'https',
        protocol: 'HTTPS',
        port: 443,
        allowedRoutes: {
          namespaces: {
            from: 'All',
          },
        },
        tls: {
          certificateRefs: [
            {
              kind: 'Secret',
              name: 'root-domain-tls',
            },
          ],
        },
      },
    ],
  },
}
