
## Test Topo

Client --> OVS(DNAT) --> Server

``` powershell
$ClientPort=6
$ClientIP="192.168.0.2"
$ClientMac="00:15:5D:F3:60:22"
$ServerPort=7
$ServerIP="192.168.100.2"
$ServerMac="00:15:5D:10:01:0D"
$VIP="192.168.0.10"
$VIP2="192.168.100.10"


$GwIP="192.168.0.1"
$GwIPHex="0xC0A80001"
$GwMac="aa:bb:cc:dd:ee:ff"
$GwMacHex="0xaabbccddeeff"
$Gw2IP="192.168.100.1"
$Gw2IPHex="0xC0A86401"
$Gw2Mac="ff:ee:dd:cc:bb:aa"
$Gw2MacHex="0xffeeddccbbaa"
$ClassifierTable=0
$ARPResponderTable=1
$CTTable=2
$ForwardTable=3
$CTZone=65520
$Cookie="cookie=0x198"


#New-NetIPAddress -InterfaceAlias gw0 -IPAddress 192.168.187.1 -PrefixLength 24

#New-NetRoute -InterfaceAlias 38 -DestinationPrefix 192.168.0.0/24 -NextHop 192.168.0.1
#New-NetRoute -InterfaceAlias 39 -DestinationPrefix 192.168.100.0/24 -NextHop 192.168.100.1

# Request direction
ovs-ofctl add-flow br-int "table=$ClassifierTable, $Cookie,priority=180,ip actions=ct(table=$CTTable,zone=$CTZone,nat)"

ovs-ofctl add-flow br-int "table=$ClassifierTable, $Cookie,priority=200,arp,arp_tpa=$GwIP,arp_op=1 actions=move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[],mod_dl_src:aa:bb:cc:dd:ee:ff,load:0x2->NXM_OF_ARP_OP[],move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[],load:$GwMacHex->NXM_NX_ARP_SHA[],move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[],load:$GwIPHex->NXM_OF_ARP_SPA[],IN_PORT"
ovs-ofctl add-flow br-int "table=$ClassifierTable, $Cookie,priority=200,arp,arp_tpa=$Gw2IP,arp_op=1 actions=move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[],mod_dl_src:aa:bb:cc:dd:ee:ff,load:0x2->NXM_OF_ARP_OP[],move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[],load:$Gw2MacHex->NXM_NX_ARP_SHA[],move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[],load:$Gw2IPHex->NXM_OF_ARP_SPA[],IN_PORT"
ovs-ofctl add-flow br-int "table=$ClassifierTable, $Cookie,priority=0 actions=drop"
ovs-ofctl add-flow br-int "table=$CTTable, $Cookie, priority=180, ct_state=+new+trk,ip,in_port=$ClientPort,nw_src=$ClientIP,nw_dst=$VIP actions=ct(commit,table=$ForwardTable,zone=$CTZone,nat(dst=$ServerIP))"
ovs-ofctl add-flow br-int "table=$CTTable, $Cookie, priority=180, ct_state=-new+trk,ip actions=resubmit(,$ForwardTable)"
ovs-ofctl add-flow br-int "table=$CTTable, $Cookie,priority=0 actions=drop"

ovs-ofctl add-flow br-int "table=$ForwardTable, $Cookie, priority=180,in_port=$ClientPort actions=mod_nw_src:$VIP2,mod_dl_src:$Gw2Mac,mod_dl_dst:$ServerMac,output:$ServerPort"
ovs-ofctl add-flow br-int "table=$ForwardTable, $Cookie, priority=180,in_port=$ServerPort actions=mod_dl_src:$GwMac,,mod_dl_dst:$ClientMac,output:$ClientPort"
ovs-ofctl add-flow br-int "table=$ForwardTable, $Cookie,priority=0 actions=drop"

ovs-ofctl add-flow br-int "table=$ClassifierTable, $Cookie,priority=200,in_port=$ServerPort,ip,nw_dst=$VIP2 actions=mod_nw_dst:$ClientIP,ct(table=$CTTable,zone=$CTZone,nat)"
ovs-ofctl add-flow br-int "table=$ForwardTable, $Cookie, priority=180,in_port=$ClientPort actions=mod_nw_src:$VIP2,mod_dl_src:$Gw2Mac,mod_dl_dst:$ServerMac,output:$ServerPort"
```
