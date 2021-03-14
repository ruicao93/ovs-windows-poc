
## Overview

service.spec.externalTrafficPolicy

(1) External --> NodePort serice

- UplinkTable: Redirect to NodePortFilterTables to check if the pkts are to NodePort service.
- +NodePortFilterTable1: Filter NodePort IPs
- +NodePortFilterTable2: Filter NodePort ports (Conjunction)
- +DnatTables: Set dst ip to VIP.
- +SnatTables: For cluster externalTrafficPolicy, do SNAT

nw_dst=VIP,tcp_dst=NodePort  --> LB

(ExtIP, LocalNodeIP)                               (ExtIP, VIP)    (GwIP, VIP)         (GwIP, EndpointIP)
Request: client --> NodePortFilterTables --> DnatTables --> SnatTables --> serviceLBTable(DNAT) --> Endpoint
Reply: Endpoint --> serviceLBTable(unDNAT) --> SnatTables(unSNAT) --> DnatTables(unDNAT) --> client
(EndpointIP, GwIP)                     (VIP, GwIP)            (VIP, ExtIP)         (LocalNodeIP, ExtIP)

--> gw --> host(route) --> br-int --> OVS --> uplink

``` powershell

$VIP="169.254.169.110"
$LocalNodeIP="10.176.25.244"
$LocalNodePort="31736"
$GwIP=(Get-NetIPAddress -InterfaceAlias antrea-gw0 -AddressFamily IPv4).IPAddress
$GwPort="2"

$GwMacSrc=(Get-NetAdapter -InterfaceAlias antrea-gw0).MacAddress
$GwMac=$GwMacSrc -replace "-",":"

$markTrafficFromTunnel="reg0=0x0/0xffff"
$markTrafficFromGateway="reg0=0x1/0xffff"
$markTrafficFromLocal="reg0=0x2/0xffff"
$markTrafficFromUplink="reg0=0x4/0xffff"
$markTrafficFromBridge="reg0=0x5/0xffff"

$conntrackTable=30
$conntrackStateTable=31
$SVCDnatTable=40
$serviceLBTable=41
$l3ForwardingTable=70
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




## Request packets
## Redirect pkts from uplink to NodePortFilterTables
ovs-ofctl add-flow br-int "table=$UplinkTable, cookie=$Cookie,priority=210,$markTrafficFromUplink,ip,nw_dst=$LocalNodeIP,tcp,tp_dst=$LocalNodePort actions=resubmit(,$NodePortFilterTable1)"
# ovs-ofctl add-flow br-int "table=$UplinkTable, cookie=$TestCookie,priority=210,$markTrafficFromUplink,ip,nw_dst=$LocalNodeIP,tcp,tp_dst=$LocalNodePort actions=load:0x21->NXM_NX_PKT_MARK[],resubmit(,$NodePortFilterTable1)"
## Product flow: ovs-ofctl add-flow br-int "table=$UplinkTable, cookie=$Cookie,priority=200,$markTrafficFromUplink,ip,nw_dst=$LocalNodeIP actions=resubmit(,$NodePortFilterTable1)"

## Filter NodePort service traffic, redirect it into SNAT tables
ovs-ofctl add-flow br-int "table=$NodePortFilterTable1, cookie=$Cookie,priority=200,ip,nw_dst=$LocalNodeIP actions=resubmit(,$NodePortFilterTable2)"
ovs-ofctl add-flow br-int "table=$NodePortFilterTable1, cookie=$Cookie,priority=190 actions=resubmit(,$PostSnatTable)"

ovs-ofctl add-flow br-int "table=$NodePortFilterTable2, cookie=$Cookie,priority=200,ip,tcp,tp_dst=$LocalNodePort actions=ct(table=$DnatTable,zone=$DnatCTZone,nat)"
ovs-ofctl add-flow br-int "table=$NodePortFilterTable2, cookie=$Cookie,priority=190 actions=resubmit(,$PostSnatTable)"

## DnatTable
ovs-ofctl add-flow br-int "table=$DnatTable, cookie=$Cookie,priority=190,ip,ct_state=+new+trk actions=load:0x1->NXM_NX_REG8[],ct(commit,table=$PostDnatTable,zone=$DnatCTZone,nat(dst=$VIP))"
ovs-ofctl add-flow br-int "table=$DnatTable, cookie=$Cookie,priority=190,ip,ct_state=-new+trk actions=load:0x1->NXM_NX_REG8[],resubmit(,$PostDnatTable)"
ovs-ofctl add-flow br-int "table=$DnatTable, cookie=$Cookie,priority=200,ip,reg8=0x2/0xffff actions=output:$GwPort"
ovs-ofctl add-flow br-int "table=$DnatTable, cookie=$Cookie,priority=0 actions=drop"

# Post DnatTable
ovs-ofctl add-flow br-int "table=$PostDnatTable, cookie=$Cookie,priority=190,ip actions=ct(table=$SnatTable,zone=$SnatCTZone,nat)"
ovs-ofctl add-flow br-int "table=$PostDnatTable, cookie=$Cookie,priority=0 actions=drop"

## For NodePort service traffic, enter SNAT tables and mark request direction pkts with reg8=0x1/0xffff
ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=190,reg8=0x1/0xffff,ip,tcp,ct_state=+new+trk actions=ct(commit,table=$PostSnatTable,zone=$SnatCTZone,nat(src=$GwIP))"
ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=190,reg8=0x1/0xffff,ip,ct_state=-new+trk actions=resubmit(,$PostSnatTable)"
ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=190,ip,reg8=0x2/0xffff,ct_state=-new+trk actions=ct(table=$DnatTable,zone=$DnatCTZone,nat)"
# For LocalNode --> LocalNodePort case
ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$TestCookie,priority=190,ip,reg8=0x2/0xffff,ct_state=+new+trk actions=$GwPort"
ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=0 actions=drop"

## The default next hop is conntrackTable
ovs-ofctl add-flow br-int "table=$PostSnatTable,cookie=$Cookie,priority=200,ip,reg8=0x2/0xffff,nw_dst=$GwIP actions=ct(table=$SnatTable,zone=$SnatCTZone,nat)"
ovs-ofctl add-flow br-int "table=$PostSnatTable,cookie=$Cookie,priority=190,ip,reg8=0x2/0xffff actions=ct(table=$DnatTable,zone=$DnatCTZone,nat)"
ovs-ofctl add-flow br-int "table=$PostSnatTable,cookie=$Cookie,priority=0,ip actions=ct(table=$conntrackTable,zone=65500,nat)"


## Pass NodePort service traffic to following pipeline
ovs-ofctl add-flow br-int "table=$conntrackStateTable, cookie=$Cookie,priority=210,ip,$markTrafficFromUplink,ct_state=+new+trk,reg8=0x1/0xffff actions=resubmit(,$SVCDnatTable),resubmit(,$serviceLBTable)"

## Reply
# The source IP of reply raffic after unDNAT is VIP, mark the reply direction packets with reg8=0x2/0xffff
ovs-ofctl add-flow br-int "table=$L2ForwardingOutTable, cookie=$Cookie,priority=220,ip,nw_src=$VIP  actions=load:0x2->NXM_NX_REG8[],resubmit(,$PostSnatTable)"

```

## Add new NodePort(External)


### external_remotepod
``` powershell
$LocalNodePortNew="30232"

ovs-ofctl add-flow br-int "table=$UplinkTable, cookie=$Cookie,priority=210,$markTrafficFromUplink,ip,nw_dst=$LocalNodeIP,tcp,tp_dst=$LocalNodePortNew actions=resubmit(,$NodePortFilterTable1)"
ovs-ofctl add-flow br-int "table=$NodePortFilterTable2, cookie=$Cookie,priority=200,ip,tcp,tp_dst=$LocalNodePortNew actions=ct(table=$DnatTable,zone=$DnatCTZone,nat)"
# ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=200,$markTrafficFromUplink,ip,tcp,tp_dst=$LocalNodePortNew,ct_state=+new+trk actions=ct(commit,table=$PostSnatTable,zone=$SnatCTZone,nat(src=$GwIP))"

curl 10.176.25.244:30232
```

### external_remotenode
``` powershell
$LocalNodePortNew="32287"

ovs-ofctl add-flow br-int "table=$UplinkTable, cookie=$Cookie,priority=210,$markTrafficFromUplink,ip,nw_dst=$LocalNodeIP,tcp,tp_dst=$LocalNodePortNew actions=resubmit(,$NodePortFilterTable1)"
ovs-ofctl add-flow br-int "table=$NodePortFilterTable2, cookie=$Cookie,priority=200,ip,tcp,tp_dst=$LocalNodePortNew actions=ct(table=$DnatTable,zone=$DnatCTZone,nat)"
#ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=200,$markTrafficFromUplink,ip,tcp,tp_dst=$LocalNodePortNew,ct_state=+new+trk actions=ct(commit,table=$PostSnatTable,zone=$SnatCTZone,nat(src=$GwIP))"
```





## Deprecated flows

``` powershell
## DnatTable(Deprecated)
ovs-ofctl add-flow br-int "table=$DnatTable, cookie=$Cookie,priority=200,$markTrafficFromUplink,ip,ct_state=+new+trk actions=load:0x1->NXM_NX_REG8[],ct(commit,table=$PostDnatTable,zone=$DnatCTZone,nat(dst=$VIP))"
ovs-ofctl add-flow br-int "table=$DnatTable, cookie=$Cookie,priority=200,$markTrafficFromUplink,ip,ct_state=-new+trk actions=load:0x1->NXM_NX_REG8[],resubmit(,$PostDnatTable)"
ovs-ofctl add-flow br-int "table=$DnatTable, cookie=$Cookie,priority=190,$markTrafficFromLocal,ip,ct_state=-new+trk actions=output:$GwPort"
ovs-ofctl add-flow br-int "table=$DnatTable, cookie=$Cookie,priority=0 actions=drop"

## For NodePort service traffic, enter SNAT tables and mark NodePort pkt_mark(Deprecated)
ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=200,$markTrafficFromUplink,ip,tcp,tp_dst=$LocalNodePort,ct_state=+new+trk actions=ct(commit,table=$PostSnatTable,zone=$SnatCTZone,nat(src=$GwIP))"
ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=200,$markTrafficFromUplink,ip,ct_state=-new+trk actions=load:0x1->NXM_NX_REG8[],resubmit(,$PostSnatTable)"
#ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=200,$markTrafficFromUplink,ip,ct_state=-new+trk actions=load:0x21->NXM_NX_PKT_MARK[],resubmit(,$PostSnatTable)"
ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=190,$markTrafficFromLocal,ip,ct_state=-new+trk actions=ct(table=$DnatTable,zone=$DnatCTZone,nat)"
ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=0 actions=drop"

## The default next hop is conntrackTable(Deprecated)
ovs-ofctl add-flow br-int "table=$PostSnatTable,cookie=$Cookie,priority=200,ip,$markTrafficFromUplink actions=ct(table=$conntrackTable,zone=65500,nat)"
ovs-ofctl add-flow br-int "table=$PostSnatTable,cookie=$Cookie,priority=200,ip,$markTrafficFromLocal,nw_dst=$GwIP actions=ct(table=$SnatTable,zone=$SnatCTZone,nat)"
ovs-ofctl add-flow br-int "table=$PostSnatTable,cookie=$Cookie,priority=200,ip,$markTrafficFromTunnel,nw_dst=$GwIP actions=ct(table=$SnatTable,zone=$SnatCTZone,nat)"
ovs-ofctl add-flow br-int "table=$PostSnatTable,cookie=$Cookie,priority=190,ip,$markTrafficFromLocal actions=ct(table=$DnatTable,zone=$DnatCTZone,nat)"
ovs-ofctl add-flow br-int "table=$PostSnatTable,cookie=$Cookie,priority=190,ip,$markTrafficFromTunnel  actions=ct(table=$DnatTable,zone=$DnatCTZone,nat)"
# ovs-ofctl add-flow br-int "table=$PostSnatTable,cookie=$TestCookie,priority=210,ip,pkt_mark=0x21/0xffff actions=drop"
```