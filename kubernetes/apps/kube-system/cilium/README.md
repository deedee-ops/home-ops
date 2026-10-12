# Cilium

## UniFi BGP

```sh
router bgp 64512
  bgp router-id 192.168.1.1
  no bgp ebgp-requires-policy

  neighbor k8s peer-group
  neighbor k8s remote-as 64513
  ! keep in sync with CiliumBGPPeerConfig timers
  neighbor k8s timers 3 9
  neighbor k8s timers connect 5

  neighbor 192.168.42.21 peer-group k8s
  neighbor 192.168.42.22 peer-group k8s
  neighbor 192.168.42.23 peer-group k8s

  address-family ipv4 unicast
    ! ECMP across every node announcing a VIP (externalTrafficPolicy: Local)
    maximum-paths 3
    neighbor k8s next-hop-self
    neighbor k8s soft-reconfiguration inbound
  exit-address-family
exit
```

Verify on the gateway: `vtysh -c 'show ip route 192.168.42.53/32'` lists one
next hop per node running a blocky pod.
