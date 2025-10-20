local global = std.extVar('global');

if global.singleNode then [
  {
    apiVersion: 'gateway.networking.k8s.io/v1',
    kind: 'GatewayClass',
    metadata: {
      name: 'envoy-internal',
    },
    spec: {
      controllerName: 'gateway.envoyproxy.io/gatewayclass-controller',
      parametersRef: {
        group: 'gateway.envoyproxy.io',
        kind: 'EnvoyProxy',
        name: 'envoy-internal',
        namespace: 'network',
      },
    },
  },
  {
    apiVersion: 'gateway.networking.k8s.io/v1',
    kind: 'GatewayClass',
    metadata: {
      name: 'envoy-external',
    },
    spec: {
      controllerName: 'gateway.envoyproxy.io/gatewayclass-controller',
      parametersRef: {
        group: 'gateway.envoyproxy.io',
        kind: 'EnvoyProxy',
        name: 'envoy-external',
        namespace: 'network',
      },
    },
  },
] else [
  {
    apiVersion: 'gateway.networking.k8s.io/v1',
    kind: 'GatewayClass',
    metadata: {
      name: 'envoy',
    },
    spec: {
      controllerName: 'gateway.envoyproxy.io/gatewayclass-controller',
      parametersRef: {
        group: 'gateway.envoyproxy.io',
        kind: 'EnvoyProxy',
        name: 'envoy',
        namespace: 'network',
      },
    },
  },
]
