local global = std.extVar('global');

[
  {
    apiVersion: 'gateway.envoyproxy.io/v1alpha1',
    kind: 'EnvoyProxy',
    metadata: {
      name: 'envoy-internal',
    },
    spec: {
      logging: {
        level: {
          default: 'info',
        },
      },
      provider: {
        type: 'Kubernetes',
        kubernetes: {
          envoyDeployment: {
            container: {
              image: 'mirror.gcr.io/envoyproxy/envoy:v1.36.2',
              resources: {
                requests: {
                  cpu: '100m',
                },
                limits: {
                  memory: '1Gi',
                },
              },
            },
            [if global.singleNode then 'patch']: {
              value: {
                spec: {
                  template: {
                    spec: {
                      containers: [
                        {
                          name: 'envoy',
                          ports: [
                            {
                              containerPort: 10080,
                              hostPort: 80,
                              hostIP: global.ips.internalLB,
                              name: 'http',
                              protocol: 'TCP',
                            },
                            {
                              containerPort: 10443,
                              hostPort: 443,
                              hostIP: global.ips.internalLB,
                              name: 'https',
                              protocol: 'TCP',
                            },
                          ],
                        },
                      ],
                    },
                  },
                },
              },
            },
          },
          envoyService: {
            externalTrafficPolicy: 'Local',
          },
        },
      },
      shutdown: {
        drainTimeout: '180s',
      },
      telemetry: {
        metrics: {
          prometheus: {
            compression: {
              type: 'Gzip',
            },
          },
        },
      },
    },
  },
  {
    apiVersion: 'gateway.envoyproxy.io/v1alpha1',
    kind: 'EnvoyProxy',
    metadata: {
      name: 'envoy-external',
    },
    spec: {
      logging: {
        level: {
          default: 'info',
        },
      },
      provider: {
        type: 'Kubernetes',
        kubernetes: {
          envoyDeployment: {
            container: {
              image: 'mirror.gcr.io/envoyproxy/envoy:v1.36.2',
              resources: {
                requests: {
                  cpu: '100m',
                },
                limits: {
                  memory: '1Gi',
                },
              },
            },
            [if global.singleNode then 'patch']: {
              value: {
                spec: {
                  template: {
                    spec: {
                      containers: [
                        {
                          name: 'envoy',
                          ports: [
                            {
                              containerPort: 10080,
                              hostPort: 80,
                              hostIP: global.ips.externalLB,
                              name: 'http',
                              protocol: 'TCP',
                            },
                            {
                              containerPort: 10443,
                              hostPort: 443,
                              hostIP: global.ips.externalLB,
                              name: 'https',
                              protocol: 'TCP',
                            },
                          ],
                        },
                      ],
                    },
                  },
                },
              },
            },
          },
          envoyService: {
            externalTrafficPolicy: 'Local',
          },
        },
      },
      shutdown: {
        drainTimeout: '180s',
      },
      telemetry: {
        metrics: {
          prometheus: {
            compression: {
              type: 'Gzip',
            },
          },
        },
      },
    },
  },
]

