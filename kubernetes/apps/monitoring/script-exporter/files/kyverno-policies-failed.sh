#!/bin/sh

echo "# HELP kyverno_policies_failed Number of failed kyverno policies for given resource"
echo "# TYPE kyverno_policies_failed gauge"
kubectl get policyreports -A -o wide | grep -v '0      0      0' | grep -v '^NAMESPACE' | awk '{ print "kyverno_policies_failed{target_namespace=\"" $1 "\",target_name=\"" $4 "\",target_kind=\"" $ 3 "\"} " $6}'
