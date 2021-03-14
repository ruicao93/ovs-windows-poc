
## Req1

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



# cookie=0x3060000000000, duration=2983.650s, table=5, n_packets=896873, n_bytes=216312991, priority=200,ip,reg0=0x4/0xffff actions=ct(table=30,zone=65500,nat)

## Redirect pkts from uplink to NodePortFilterTables
ovs-ofctl add-flow br-int "table=$UplinkTable, cookie=$Cookie,priority=210,$markTrafficFromUplink,ip,nw_dst=$LocalNodeIP,tcp,tp_dst=$LocalNodePort actions=resubmit(,$NodePortFilterTable1)"
# ovs-ofctl add-flow br-int "table=$UplinkTable, cookie=$TestCookie,priority=210,$markTrafficFromUplink,ip,nw_dst=$LocalNodeIP,tcp,tp_dst=$LocalNodePort actions=load:0x21->NXM_NX_PKT_MARK[],resubmit(,$NodePortFilterTable1)"
## Product flow: ovs-ofctl add-flow br-int "table=$UplinkTable, cookie=$Cookie,priority=200,$markTrafficFromUplink,ip,nw_dst=$LocalNodeIP actions=resubmit(,$NodePortFilterTable1)"

## Filter NodePort service traffic, redirect it into SNAT tables
ovs-ofctl add-flow br-int "table=$NodePortFilterTable1, cookie=$Cookie,priority=200,ip,nw_dst=$LocalNodeIP actions=resubmit(,$NodePortFilterTable2)"
ovs-ofctl add-flow br-int "table=$NodePortFilterTable1, cookie=$Cookie,priority=180 actions=resubmit(,$PostSnatTable)"

ovs-ofctl add-flow br-int "table=$NodePortFilterTable2, cookie=$Cookie,priority=200,ip,tcp,tp_dst=$LocalNodePort actions=ct(table=$SnatTable,zone=$SnatCTZone,nat)"
ovs-ofctl add-flow br-int "table=$NodePortFilterTable2, cookie=$Cookie,priority=180 actions=resubmit(,$PostSnatTable)"

## For NodePort service traffic, enter SNAT tables and mark NodePort pkt_mark
ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=200,$markTrafficFromUplink,ip,tcp,tp_dst=$LocalNodePort,ct_state=+new+trk actions=load:0x1->NXM_NX_REG8[],ct(commit,table=$PostSnatTable,zone=$SnatCTZone,nat(src=$GwIP)"
ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=200,$markTrafficFromUplink,ip,ct_state=-new+trk actions=load:0x1->NXM_NX_REG8[],resubmit(,$PostSnatTable)"
#ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=200,$markTrafficFromUplink,ip,ct_state=-new+trk actions=load:0x21->NXM_NX_PKT_MARK[],resubmit(,$PostSnatTable)"
ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=180,$markTrafficFromLocal,ip,ct_state=-new+trk actions=$GwPort"
ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=0 actions=drop"

## The default next hop is conntrackTable
ovs-ofctl add-flow br-int "table=$PostSnatTable,cookie=$Cookie,priority=200,ip actions=ct(table=$conntrackTable,zone=65500,nat)"
# ovs-ofctl add-flow br-int "table=$PostSnatTable,cookie=$TestCookie,priority=210,ip,pkt_mark=0x21/0xffff actions=drop"

## Pass NodePort service traffic to following pipeline
ovs-ofctl add-flow br-int "table=$conntrackStateTable, cookie=$Cookie,priority=210,ip,$markTrafficFromUplink,ct_state=+new+trk,reg8=0x1/0xffff actions=resubmit(,$SVCDnatTable),resubmit(,$serviceLBTable)"
# ovs-ofctl add-flow br-int "table=$conntrackStateTable, cookie=$TestCookie,priority=220,reg8=0x1/0xffff actions=drop"
#ovs-ofctl add-flow br-int "table=$conntrackStateTable, cookie=$Cookie,priority=210,ip,$markTrafficFromUplink,ct_state=+new+trk,pkt_mark=0x21/0xffff actions=resubmit(,$SVCDnatTable),resubmit(,$serviceLBTable)"


```

## Add new NodePort

``` powershell
$LocalNodePortNew="30232"

ovs-ofctl add-flow br-int "table=$UplinkTable, cookie=$Cookie,priority=210,$markTrafficFromUplink,ip,nw_dst=$LocalNodeIP,tcp,tp_dst=$LocalNodePortNew actions=resubmit(,$NodePortFilterTable1)"

ovs-ofctl add-flow br-int "table=$NodePortFilterTable2, cookie=$Cookie,priority=200,ip,tcp,tp_dst=$LocalNodePortNew actions=ct(table=$SnatTable,zone=$SnatCTZone,nat)"

ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=200,$markTrafficFromUplink,ip,tcp,tp_dst=$LocalNodePortNew,ct_state=+new+trk actions=load:0x1->NXM_NX_REG8[],ct(commit,table=$PostSnatTable,zone=$SnatCTZone,nat(src=$GwIP)"
```