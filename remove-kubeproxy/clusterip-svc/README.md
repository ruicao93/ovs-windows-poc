## ClusterIP SVC

With kube-proxy enabled(current implementation):
1. LocalPod --> SVC (AntreaProxy)
2. LocalNode --> SVC (Kube-proxy)
(NodeIP, SVCIP) --> OVS(br-int, gw)

With kube-proxy disabled(in progress):
1. LocalPod --> SVC (AntreaProxy)
2. LocalNode --> SVC (Kube-proxy)
(NodeIP, SVCIP) --> OVS(br-int, gw)

### LocalNode --> SVC(Linux)

** (1) Endpoint is not host network **
(NodeIP, SVCIP) --> IPset(mark) --> AntreaRouteTable(NextHop: gw) --> Masquerade(GWIP, SVCIP)  --> OVS --> DNAT(GWIP, EndpointIP) --> Endpoint

** (2) Endpoint is local host network **
> Dst EndpintNode is local node
(NodeIP, SVCIP) --> IPset(mark) --> AntreaRouteTable(NextHop: gw) --> Masquerade(GWIP, SVCIP)       --> OVS --> DNAT(GWIP, EndpointNodeIP)   --> mod_nw_src(VIP, EndpointNodeIP)  --> HostNetwork
(SVCIP, NodeIP) <--                                               <-- de-Masquerade(SVCIP, NodeIP)  <-- OVS <-- d-DNAT(SVCIP,EndpointNodeIP) <-- mod_nw_dst(EndpointNodeIP, GWIP) <-- HostNetwork  <-- (EndpointNodeIP, VIP)

SNAT(GWIP)的原因: 防止reply pkts不能按原路径返回。
- 如果EndpointIP是remote NodeIP，不用GWIP的话，reply pkts就会绕过OVS(LB)直接回复，这样SVCIP得不到还原。

> Dst EndpintNode is remote node

### LocalNode --> SVC(Windows)

** (1) Endpoint is not host network **

方案一:

(NodeIP, SVCIP) --> IPset(mark) --> AntreaRouteTable(NextHop: gw) --> Masquerade(GWIP, SVCIP)  --> OVS --> DNAT(GWIP, EndpointIP) --> Endpoint

```
# Add route svcIP.nexthop = self, iface=gw
$SVCIP="10.111.43.196"
New-NetRoute -InterfaceAlias antrea-gw0 -DestinationPrefix $SVCIP/32 -NextHop $SVCIP

# Add arp respondor for svcip
$SVCIPHex="0xA6F2BC4" # 10.111.43.196
$DstMacHex="0xaabbccddeeff"

ovs-ofctl add-flow br-int "table=0,cookie=0x520,priority=200,arp,arp_tpa=$SVCIP,arp_op=1 actions=move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[],mod_dl_src:aa:bb:cc:dd:ee:ff,load:0x2->NXM_OF_ARP_OP[],move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[],load:$DstMacHex->NXM_NX_ARP_SHA[],move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[],load:$SVCIPHex->NXM_OF_ARP_SPA[],IN_PORT"
```

Test WinSVC on local node:
```
# Add route svcIP.nexthop = self, iface=gw
$SVCIP="10.105.113.209"
New-NetRoute -InterfaceAlias antrea-gw0 -DestinationPrefix $SVCIP/32 -NextHop $SVCIP

# Add arp respondor for svcip
$SVCIPHex="0xA6F2BC4" # 10.105.113.209
$DstMacHex="0xaabbccddeeff"

ovs-ofctl add-flow br-int "table=0,cookie=0x520,priority=200,arp,arp_tpa=$SVCIP,arp_op=1 actions=move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[],mod_dl_src:aa:bb:cc:dd:ee:ff,load:0x2->NXM_OF_ARP_OP[],move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[],load:$DstMacHex->NXM_NX_ARP_SHA[],move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[],load:$SVCIPHex->NXM_OF_ARP_SPA[],IN_PORT"
```


** ISSUE1 **

There're dup pkts. Captured pkts in `asset/clusterip_dup_issue.pcap`: 
![Dupe pkts](assets/dup_pkts_issue.png)

May caused by GwCTMark and ServiceCTMark conflict.


Try to add flow to address the conflict.
```
c.pipeline[conntrackCommitTable].BuildFlow(priorityHigh).
    MatchProtocol(binding.ProtocolIP).
    MatchCTMark(serviceCTMark).
    MatchCTStateNew(true).
    MatchCTStateTrk(true).
    MatchRegRange(int(marksReg), markTrafficFromGateway, binding.Range{0, 15}).
    Action().GotoTable(L2ForwardingOutTable).
    Done()

ovs-ofctl add-flow br-int "table=105,cookie=0x520,priority=210,ct_state=+new+trk,ip,reg0=0x1/0xffff,ct_mark=0x21 actions=resubmit(,110)"

# ovs-ofctl add-flow br-int "table=105,cookie=0x520,priority=200,ct_state=+new+trk,ip,reg0=0x1/0xffff,ct_mark=0x21 actions=resubmit(,110)"
# ovs-ofctl del-flows br-int "table=105,cookie=0x520/-1,ct_state=+new+trk,ip,reg0=0x1/0xffff,ct_mark=0x21"
```
