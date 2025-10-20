local global = std.extVar('global');

[
  {
    apiVersion: 'gateway.networking.k8s.io/v1',
    kind: 'Gateway',
    metadata: {
      name: if global.singleNode then 'envoy-internal' else 'envoy',
      annotations: {
        'external-dns.alpha.kubernetes.io/target': '%s-internal.%s' % [global.clusterName, global.rootDomain],
      },
    },
    spec: {
      gatewayClassName: 'envoy-internal',
      infrastructure: {
        annotations: {
          'external-dns.alpha.kubernetes.io/hostname': '%s-internal.%s' % [global.clusterName, global.rootDomain],
          [if !global.singleNode then 'lbipam.cilium.io/ips']: global.ips.internalLB,
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
                group: '',
                kind: 'Secret',
                name: 'root-domain-tls',
              },
            ],
          },
        },
      ],
    },
  },
  {
    apiVersion: 'gateway.networking.k8s.io/v1',
    kind: 'Gateway',
    metadata: {
      name: if global.singleNode then 'envoy-external' else 'envoy',
      annotations: {
        'external-dns.alpha.kubernetes.io/target': '%s-external.%s' % [global.clusterName, global.rootDomain],
      },
    },
    spec: {
      gatewayClassName: 'envoy-external',
      infrastructure: {
        annotations: {
          'external-dns.alpha.kubernetes.io/hostname': '%s-external.%s' % [global.clusterName, global.rootDomain],
          [if !global.singleNode then 'lbipam.cilium.io/ips']: global.ips.externalLB,
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
                group: '',
                kind: 'Secret',
                name: 'root-domain-tls',
              },
            ],
          },
        },
      ],
    },
  },
]
