{ ... }:
{
  services.frr.bgp = {
    enable = true;
    config = ''
      frr defaults traditional
      log syslog debugging
      !
      router bgp 64512
       bgp router-id 10.100.1.1
       bgp log-neighbor-changes
       no bgp default ipv4-unicast
       no bgp ebgp-requires-policy
       bgp network import-check
       !
       ! Peer group for K8S
       neighbor K8S peer-group
       neighbor K8S remote-as 64513
       neighbor K8S activate
       neighbor K8S soft-reconfiguration inbound
       neighbor K8S update-source trst0
       neighbor K8S timers 15 45
       neighbor K8S timers connect 15
       !
       ! Neighbors for K8S
       neighbor 10.100.21.10 peer-group K8S
       neighbor 10.100.21.11 peer-group K8S
       neighbor 10.100.21.12 peer-group K8S
       neighbor 10.100.21.20 peer-group K8S
       neighbor 10.100.21.21 peer-group K8S
       neighbor 10.100.21.22 peer-group K8S

       address-family ipv4 unicast
        redistribute connected
        redistribute kernel
        network 10.100.0.0/16
        neighbor K8S activate
        neighbor K8S next-hop-self
       exit-address-family
      !

      ip prefix-list bc-any seq 10 permit any
      !
      line vty
      !
    '';
  };
}
