local namespace = std.extVar('namespace');
local global = std.extVar('global');

[
  {
    apiVersion: 'gateway.networking.k8s.io/v1',
    kind: 'HTTPRoute',
    metadata: {
      name: 'argo-cd',
    },
    spec: {
      hostnames: [
        'argocd.%s' % global.rootDomain,
      ],
      parentRefs: [
        {
          name: 'envoy-internal',
          namespace: 'network',
          sectionName: 'https',
        },
      ],
      rules: [
        {
          backendRefs: [
            {
              name: 'argo-cd-server',
              namespace: '%s' % namespace,
              port: 80,
            },
          ],
          filters: [
            {
              type: 'ResponseHeaderModifier',
              responseHeaderModifier: {
                add: [
                  {
                    name: 'Content-Security-Policy',
                    value: "default-src 'self' 'unsafe-inline' data:; object-src 'none'; connect-src 'self' https://auth.%s;" % global.rootDomain,
                  },
                ],
              },
            },
          ],
        },
      ],
    },
  },
  {
    apiVersion: 'gateway.networking.k8s.io/v1',
    kind: 'HTTPRoute',
    metadata: {
      name: 'argo-cd-webhook',
    },
    spec: {
      hostnames: [
        'argocd.%s' % global.rootDomain,
      ],
      parentRefs: [
        {
          name: 'envoy-external',
          namespace: 'network',
          sectionName: 'https',
        },
      ],
      rules: [
        {
          backendRefs: [
            {
              name: 'argo-cd-server',
              namespace: '%s' % namespace,
              port: 80,
            },
          ],
          matches: [
            {
              path: {
                value: '/api/webhook',
              },
            },
          ],
        },
      ],
    },
  },
]
