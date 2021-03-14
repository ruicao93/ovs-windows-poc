

## Repl1

Req: (LocalNodeIP, LocalNodeIP) --> UserProxy: FullNAT(GwIP, VIP) --> gw --> DNAT(GwIP, LocalPodIP) --> LocalPod
Reply: LocalPod --> (LocalPodIP, GwIP) --> unDNAT(VIP, GwIP) --> gw --> UserProxy: unFullNat(LocalNodeIP, LocalNodeIP) --> source process

``` powershell

$VIP="169.254.169.110"
$LocalNodeIP="10.176.25.244"

New-NetRoute -InterfaceAlias antrea-gw0 -DestinationPrefix $VIP/32 -NextHop $GWIP

$VIPHex="0x"
$VIP -split "\." | ForEach-Object {$VIPHex=$VIPHex + ("{0:X2}" -f  [convert]::ToInt32($_, 10)) }
$GwMacSrc=(Get-NetAdapter -InterfaceAlias antrea-gw0).MacAddress
$GwMac=$GwMacSrc -replace "-",":"
$GwMacHex=$GwMacSrc -replace "-",""
$GwMacHex="0x$GwMacHex"

# ARP respondor flow
ovs-ofctl add-flow br-int "table=20,cookie=$Cookie,priority=210,arp,arp_tpa=$VIP,arp_op=1 actions=move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[],mod_dl_src:$GwMac,load:0x2->NXM_OF_ARP_OP[],move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[],load:$GwMacHex->NXM_NX_ARP_SHA[],move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[],load:$VIPHex->NXM_OF_ARP_SPA[],IN_PORT"


$TestPort="32373"
# add v4tov4 listenport= $TestPort [[connectaddress=] {IPv4Address | HostName}] [[connectport=] {Integer | ServiceName}] [[listenaddress=] {IPv4Address | HostName}] [[protocol=]tcp]
netsh interface portproxy add v4tov4 listenport=$TestPort connectport=$TestPort connectaddress=$VIP
# netsh interface portproxy delete v4tov4 listenport=$TestPort
# curl.exe 127.0.0.1:32373

PASS


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

