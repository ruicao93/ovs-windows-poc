## (ExtIP, LocalNodeIP)  ==>  (GwIP, LocalPodIP)

Req1: (ExtIP, LocalNodeIP)  --> Uplink --> SNAT(GwIP, LocalNodeIP) --> DNAT(GwIP, LocalPodIP) --> LocalPod
Repl1: LocalPod --> (LocalPodIP, GwIP) --> d-DNAT(LocalNodeIP, GwIP) --> d-SNAT(LocalNodeIP, ExtIP) --> gw --> host --> br-int --> uplink

## Req1

ovs-ofctl.exe del-flows br-int "cookie=0x520/-1"

Include: nodeport_svc_mark.md

## Repl1

Repl1: LocalPod --> (LocalPodIP, GwIP) --> d-DNAT(LocalNodeIP, GwIP) --> d-SNAT(LocalNodeIP, ExtIP) --> gw --> host --> br-int --> uplink

``` powershell

$LocalNodeIP="10.176.25.244"
$LocalNodePort="31736"
$GwIP="172.16.2.1"
$GwPort="2"

$markTrafficFromTunnel="reg0=0x0/0xffff"
$markTrafficFromGateway="reg0=0x1/0xffff"
$markTrafficFromLocal="reg0=0x2/0xffff"
$markTrafficFromUplink="reg0=0x4/0xffff"
$markTrafficFromBridge="reg0=0x5/0xffff"

$conntrackTable=30
$conntrackStateTable=31
$SVCDnatTable=40
$serviceLBTable=41
$conntrackCommitTable=105
$L2ForwardingOutTable=110

$UplinkTable=5
$NodePortFilterTable1=6
$NodePortFilterTable2=7
$SnatTable=8
$PostSnatTable=9

$Cookie="0x520"
$TestCookie="0x999"
$SnatCTZone="52200"

## Redirect reply pkts to SNAT table for d-SNAT
## Match: $markTrafficFromLocal,ip,nw_src=$LocalNodeIP,nw_dst=$GwIP
ovs-ofctl add-flow br-int "table=$L2ForwardingOutTable, cookie=$Cookie,priority=210,$markTrafficFromLocal,ip,nw_src=$LocalNodeIP,nw_dst=$GwIP  actions=ct(table=$SnatTable,zone=$SnatCTZone,nat)"

# From other node curl Windows nodeport
curl 10.176.25.244:31736

```

## Test DNAT/d-SNAT issue

DNAT/d-SNAT/mod_nw_dst will cause TCP checksum issue
``` powershell
ovs-ofctl add-flow br-int "table=$UplinkTable, cookie=$TestCookie,priority=220,$markTrafficFromUplink,ip,nw_src=10.176.26.36,nw_dst=$LocalNodeIP,tcp,tp_dst=$LocalNodePort actions=mod_nw_src:$GwIP,load:0x1->NXM_NX_REG8[],resubmit(,$PostSnatTable)"
ovs-ofctl add-flow br-int "table=$L2ForwardingOutTable, cookie=$TestCookie,priority=220,$markTrafficFromLocal,ip,nw_src=$LocalNodeIP,nw_dst=$GwIP  actions=mod_nw_dst:10.176.26.36,$GwPort"
```
