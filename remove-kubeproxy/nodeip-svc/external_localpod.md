## (ExtIP, LocalNodeIP)  ==>  (GwIP, LocalPodIP): PASS

Req1: (ExtIP, LocalNodeIP)  --> Uplink --> DNAT(ExtIP, VIP) -->  SNAT(GwIP, VIP) --> DNAT(GwIP, LocalPodIP) --> LocalPod
Repl1: LocalPod --> (LocalPodIP, GwIP) --> unDNAT(VIP, GwIP) --> unSNAT(VIP, ExtIP) --> unDNAT(LocalNodeIP, ExtIP) --> gw --> host --> br-int --> uplink

## Req1

Req1: (ExtIP, LocalNodeIP)  --> Uplink --> DNAT(ExtIP, VIP) -->  SNAT(GwIP, VIP) --> DNAT(GwIP, LocalPodIP) --> LocalPod

ovs-ofctl.exe del-flows br-int "cookie=0x520/-1"

Include: nodeport_svc_mark.md

## Repl1

Repl1: LocalPod --> (LocalPodIP, GwIP) --> unDNAT(VIP, GwIP) --> unSNAT(VIP, ExtIP) --> unDNAT(LocalNodeIP, ExtIP) --> gw --> host --> br-int --> uplink

``` powershell
$ClientNodeIP="10.176.26.36"
$VIP="169.254.169.110"
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
$DnatTable=8
$PostDnatTable=9
$SnatTable=11
$PostSnatTable=12



$Cookie="0x520"
$TestCookie="0x999"
$DnatCTZone="52100"
$SnatCTZone="52200"

## No new flows are needed
## Redirect reply pkts to SNAT table for unSNAT
## Match: $markTrafficFromLocal,ip,nw_src=$LocalNodeIP,nw_dst=$GwIP
# ovs-ofctl add-flow br-int "table=$L2ForwardingOutTable, cookie=$Cookie,priority=210,$markTrafficFromLocal,ip,nw_src=$VIP  actions=resubmit(,$PostSnatTable)"

# From other node curl Windows nodeport
curl 10.176.25.244:31736

```
root@a-ms-2000-0:/home/ubuntu/test-ymls# curl 10.176.25.244:31736
Hello Antrea!
Windows-10-10.0.17763-SP0
ServerIP: 172.16.2.7
ClientIP: 172.16.2.1
```

```

## Test flows

``` powershell

# Verify request pkts
ovs-ofctl add-flow br-int "table=$NodePortFilterTable2, cookie=$TestCookie,priority=220,ip,tcp,tp_dst=$LocalNodePort,$markTrafficFromUplink,nw_src=$ClientNodeIP,nw_dst=$LocalNodeIP actions=ct(table=$DnatTable,zone=$DnatCTZone,nat)"

# Verify reply pkts
ovs-ofctl add-flow br-int "table=$L2ForwardingOutTable, cookie=$TestCookie,priority=220,$markTrafficFromLocal,ip,nw_src=$VIP,nw_dst=$GwIP  actions=ct(table=$SnatTable,zone=$SnatCTZone,nat)"

ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$TestCookie,priority=220,$markTrafficFromLocal,ip,nw_src=$VIP,nw_dst=$ClientNodeIP,ct_state=-new+trk actions=ct(table=$DnatTable,zone=$DnatCTZone)"

ovs-ofctl add-flow br-int "table=$DnatTable, cookie=$TestCookie,priority=220,$markTrafficFromLocal,ip,nw_src=$LocalNodeIP,nw_dst=$ClientNodeIP,ct_state=-new+trk actions=output:$GwPort"
```

