
(ExtIP, LocalNodeIP)  ==>  (GwIP, LocalPodIP)

## Req1

(ExtIP, LocalNodeIP)  --> Uplink --> DNAT(ExtIP, VIP) --> SNAT(GwIP, VIP) --> DNAT(GwIP, LocalPodIP) --> LocalPod


``` powershell
$LocalNodeIP="10.176.25.244"
$LocalNodePort="31736"
$VirtualSVCIP="169.254.169.110"
$GwIP="172.16.2.1"
$GwPort="2"

$UplinkTable=5
$DnatTable=6
$PreSnatTable=7
$SnatTable=8
$PostSnatTable=9



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


$Cookie="0x520"

$DnatCTZone="52100"
$SnatCTZone="52200"

ovs-ofctl add-flow br-int "table=$UplinkTable, cookie=$Cookie,priority=200,$markTrafficFromUplink,ip,nw_dst=$LocalNodeIP,tcp,tp_dst=$LocalNodePort actions=ct(table=$DnatTable,zone=$DnatCTZone,nat)"

ovs-ofctl add-flow br-int "table=$DnatTable, cookie=$Cookie,priority=200,$markTrafficFromUplink,ip,nw_dst=$LocalNodeIP,tcp,tp_dst=$LocalNodePort,ct_state=+new+trk actions=ct(commit,table=$PreSnatTable,zone=$DnatCTZone,nat(dst=$VirtualSVCIP))"
ovs-ofctl add-flow br-int "table=$DnatTable, cookie=$Cookie,priority=200,$markTrafficFromUplink,ip,tcp,tp_dst=$LocalNodePort,ct_state=-new+trk actions=resubmit(,$PreSnatTable)"
ovs-ofctl add-flow br-int "table=$DnatTable, cookie=$Cookie,priority=0 actions=drop"

ovs-ofctl add-flow br-int "table=$PreSnatTable, cookie=$Cookie,priority=200,$markTrafficFromUplink,ip,nw_dst=$VirtualSVCIP,tcp,tp_dst=$LocalNodePort actions=ct(table=$SnatTable,zone=$SnatCTZone,nat)"
ovs-ofctl add-flow br-int "table=$PreSnatTable, cookie=$Cookie,priority=0 actions=drop"

ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=200,$markTrafficFromUplink,ip,nw_dst=$VirtualSVCIP,tcp,tp_dst=$LocalNodePort,ct_state=+new+trk actions=ct(commit,table=$PostSnatTable,zone=$SnatCTZone,nat(src=$GwIP))"
ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=200,$markTrafficFromUplink,ip,tcp,tp_dst=$LocalNodePort,ct_state=-new+trk actions=resubmit(,$PostSnatTable)"
ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=0 actions=drop"


ovs-ofctl add-flow br-int "table=$PostSnatTable, cookie=$Cookie,priority=200,ip,$markTrafficFromUplink actions=ct(table=$conntrackTable,zone=65500,nat)"
ovs-ofctl add-flow br-int "table=$PostSnatTable, cookie=$Cookie,priority=0 actions=drop"

ovs-ofctl add-flow br-int "table=$conntrackStateTable, cookie=$Cookie,priority=210,ip,$markTrafficFromUplink,tcp,tp_dst=$LocalNodePort,ct_state=+new+trk actions=resubmit(,$SVCDnatTable),resubmit(,$serviceLBTable)"
```

## Reply1

LocalPod(LocalPodIP, GwIP) --> d-DNAT(VIP, GwIP) --> d-SNAT(VIP, ExtIP) --> d-DNAT(LocalNodeIP, ExtIP) --> gw --> host

``` powershell
ovs-ofctl add-flow br-int "table=$L2ForwardingOutTable, cookie=$Cookie,priority=200,ip,nw_src=$VirtualSVCIP,nw_dst=$GwIP,tcp,tp_src=$LocalNodePort actions=ct(table=$SnatTable,zone=$SnatCTZone,nat)"

ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=200,ip,nw_src=$VirtualSVCIP,tcp,tp_src=$LocalNodePort,ct_state=-new+trk actions=ct(table=$DnatTable,zone=$DnatCTZone,nat)"

ovs-ofctl add-flow br-int "table=$DnatTable, cookie=$Cookie,priority=200,ip,nw_src=$LocalNodeIP,tcp,tp_src=$LocalNodePort,ct_state=-new+trk actions=$GwPort"
```

## Reply2

host(ExtIP, LocalNodeIP) --> br-int --> Uplink

``` Powershell
# No additional flows are needed
```

## Test: Success

```
root@a-ms-2000-0:/home/ubuntu/test-ymls# curl 10.176.25.244:31736
Hello Antrea!
Windows-10-10.0.17763-SP0
ServerIP: 172.16.2.4
ClientIP: 172.16.2.1
```
