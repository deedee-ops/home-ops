There is an issue with kubevirt+cilium routing.

The problem is, that kubevirt pods (with pod network) doesn't have access to SVC CIDRs.
And there is a bug in cilium (or kubevirt maybe), that kubevirt can't access LB IP of a service,
if the service pod is on the same node as VM. Meaning if VM is scheduled to node A and expected app
(teleport, ingress etc.) is also on node A, VM won't see this app in any way.
To avoid this, haproxy is scheduled to master nodes, which guarantees no conflict and forwards all
the traffic to corresponding pods. VM nodes are never scheduled to masters, only to workers,
so there should be no conflicts.
