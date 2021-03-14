

## (ExtIP, LocalNodeIP)  ==>  (GwIP, RemoteNodeIP)

Req1: (ExtIP, LocalNodeIP)  --> Uplink --> DNAT(ExtIP, VIP) -->  SNAT(GwIP, VIP) --> DNAT(GwIP, RemoteNodeIP) --> SNAT(LocalNodeIP, RemoteNodeIP) --> gw --> host --> br-int --> RemoteNode
Repl1: RemoteNode --> (RemoteNodeIP, LocalNodeIP) --> uplink  --> unSNAT(RemoteNodeIP, GwIP) --> unDNAT(VIP, GwIP) --> unSNAT(VIP, ExtIP) --> unDNAT(LocalNodeIP, ExtIP) --> gw --> host --> br-int --> uplink

``` powershell


$NewNodePort="32287"

# Include base flows
ovs-ofctl add-flow br-int "table=$UplinkTable, cookie=$Cookie,priority=210,$markTrafficFromUplink,ip,nw_dst=$LocalNodeIP,tcp,tp_dst=$LocalNodePortNew actions=resubmit(,$NodePortFilterTable1)"
ovs-ofctl add-flow br-int "table=$NodePortFilterTable2, cookie=$Cookie,priority=200,ip,tcp,tp_dst=$LocalNodePortNew actions=ct(table=$DnatTable,zone=$DnatCTZone,nat)"

# + SNAT(TBD)
# Mark SNAT require
ovs-ofctl add-flow br-int "table=$l3ForwardingTable, cookie=$Cookie,priority=190,$markTrafficFromUplink,ip,ct_state=+new+trk,nw_src=$GwIP,reg8=0x1/0xffff actions=mod_dl_dst:$GwMac,load:0x1->NXM_NX_REG0[17],resubmit(,80)"
```

``` powershell
# Test flows
ovs-ofctl add-flow br-int "table=$L2ForwardingOutTable, cookie=$TestCookie,priority=230,$markTrafficFromUplink,ip,nw_src=$VIP,nw_dst=10.176.26.36  actions=drop"

ovs-ofctl add-flow br-int "table=$L2ForwardingOutTable, cookie=$TestCookie,priority=220,$markTrafficFromUplink,ip,nw_src=$VIP  actions=2"


```

Include: nodeport_svc_mark.md.Add-new-NodePort


Test:
curl 10.176.25.244:32287

## Test

Fail, unknow issue.

## Total flows

``` powershell
## Basic flows for new nodeport
$LocalNodePortNew="32287"

ovs-ofctl add-flow br-int "table=$UplinkTable, cookie=$Cookie,priority=210,$markTrafficFromUplink,ip,nw_dst=$LocalNodeIP,tcp,tp_dst=$LocalNodePortNew actions=resubmit(,$NodePortFilterTable1)"
ovs-ofctl add-flow br-int "table=$NodePortFilterTable2, cookie=$Cookie,priority=200,ip,tcp,tp_dst=$LocalNodePortNew actions=ct(table=$DnatTable,zone=$DnatCTZone,nat)"
ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=200,$markTrafficFromUplink,ip,tcp,tp_dst=$LocalNodePortNew,ct_state=+new+trk actions=ct(commit,table=$PostSnatTable,zone=$SnatCTZone,nat(src=$GwIP))"


```
