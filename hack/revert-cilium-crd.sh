#!/usr/bin/env bash

if [ -z "$1" ]; then
  echo "provide version (without v prefix)"
  exit 1
fi

for crd in ciliumbgpadvertisements.yaml ciliumbgpclusterconfigs.yaml ciliumbgpnodeconfigoverrides.yaml ciliumbgpnodeconfigs.yaml ciliumbgppeerconfigs.yaml ciliumbgppeeringpolicies.yaml ciliumcidrgroups.yaml ciliumendpointslices.yaml ciliuml2announcementpolicies.yaml ciliumloadbalancerippools.yaml ciliumpodippools.yaml; do
  kubectl apply -f "https://raw.githubusercontent.com/cilium/cilium/v$1/pkg/k8s/apis/cilium.io/client/crds/v2alpha1/$crd"
done
