

## (ExtIP, LocalNodeIP)  ==>  (GwIP, RemotePodIP)

Req1: (ExtIP, LocalNodeIP)  --> Uplink --> DNAT(ExtIP, VIP) -->  SNAT(GwIP, VIP) --> DNAT(GwIP, RemotePodIP) --> Tunnel --> RemotePodIP
Repl1: RemotePodIP --> Tunnel --> (RemotePodIP, GwIP) --> unDNAT(VIP, GwIP) --> unSNAT(VIP, ExtIP) --> unDNAT(LocalNodeIP, ExtIP) --> gw --> host --> br-int --> uplink

``` powershell

# Include basic flows
$LocalNodePortNew="30232"

ovs-ofctl add-flow br-int "table=$UplinkTable, cookie=$Cookie,priority=210,$markTrafficFromUplink,ip,nw_dst=$LocalNodeIP,tcp,tp_dst=$LocalNodePortNew actions=resubmit(,$NodePortFilterTable1)"
ovs-ofctl add-flow br-int "table=$NodePortFilterTable2, cookie=$Cookie,priority=200,ip,tcp,tp_dst=$LocalNodePortNew actions=ct(table=$DnatTable,zone=$DnatCTZone,nat)"

# Depricated
# ovs-ofctl add-flow br-int "table=$L2ForwardingOutTable, cookie=$Cookie,priority=210,$markTrafficFromTunnel,ip,nw_src=$VIP  actions=ct(table=$SnatTable,zone=$SnatCTZone,nat)"
# ovs-ofctl add-flow br-int "table=$L2ForwardingOutTable, cookie=$Cookie,priority=210,$markTrafficFromTunnel,ip,nw_src=$VIP  actions=resubmit(,$PostSnatTable)"


# Depricated
# ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=190,$markTrafficFromTunnel,ip,ct_state=-new+trk actions=ct(table=$DnatTable,zone=$DnatCTZone,nat)"
# ovs-ofctl add-flow br-int "table=$DnatTable, cookie=$Cookie,priority=190,$markTrafficFromTunnel,ip,ct_state=-new+trk actions=output:$GwPort"
```

Include: nodeport_svc_mark.md.Add-new-NodePort


Test:
curl 10.176.25.244:30232

HalfFail: data/v3/ext_remotepod_on_container.pcap

Found wrong sequence number

## Total flows:

``` powershell
## Basic flows for new nodeport
$LocalNodePortNew="30232"

ovs-ofctl add-flow br-int "table=$UplinkTable, cookie=$Cookie,priority=210,$markTrafficFromUplink,ip,nw_dst=$LocalNodeIP,tcp,tp_dst=$LocalNodePortNew actions=resubmit(,$NodePortFilterTable1)"
ovs-ofctl add-flow br-int "table=$NodePortFilterTable2, cookie=$Cookie,priority=200,ip,tcp,tp_dst=$LocalNodePortNew actions=ct(table=$DnatTable,zone=$DnatCTZone,nat)"
ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=200,$markTrafficFromUplink,ip,tcp,tp_dst=$LocalNodePortNew,ct_state=+new+trk actions=ct(commit,table=$PostSnatTable,zone=$SnatCTZone,nat(src=$GwIP))"

## Specific flows
ovs-ofctl add-flow br-int "table=$L2ForwardingOutTable, cookie=$Cookie,priority=210,$markTrafficFromTunnel,ip,nw_src=$VIP  actions=resubmit(,$PostSnatTable)"

ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=190,$markTrafficFromTunnel,ip,ct_state=-new+trk actions=ct(table=$DnatTable,zone=$DnatCTZone,nat)"
ovs-ofctl add-flow br-int "table=$DnatTable, cookie=$Cookie,priority=190,$markTrafficFromTunnel,ip,ct_state=-new+trk actions=output:$GwPort"
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