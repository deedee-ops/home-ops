# Cilium

## UniFi BGP

```sh
router bgp 64512
  bgp router-id 192.168.1.1
  no bgp ebgp-requires-policy

  neighbor k8s peer-group
  neighbor k8s remote-as 64513

  neighbor 192.168.42.21 peer-group k8s
  neighbor 192.168.42.22 peer-group k8s
  neighbor 192.168.42.23 peer-group k8s

  address-family ipv4 unicast
    neighbor k8s next-hop-self
    neighbor k8s soft-reconfiguration inbound
  exit-address-family
exit
```
