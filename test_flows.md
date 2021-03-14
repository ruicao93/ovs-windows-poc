``` powershell

$DstIP="10.98.46.84"
ovs-ofctl add-flow br-int "table=31,cookie=$TestCookie,priority=220,ip,nw_dst=$DstIP,ct_state=+new+trk actions=resubmit(,40),resubmit(,41)"


$Dst1IP="192.168.184.3"
$Dst2IP="192.168.185.6"

ovs-ofctl add-flow br-int "table=70,cookie=$TestCookie,priority=230,ip,nw_dst=$Dst1IP actions=drop"
ovs-ofctl add-flow br-int "table=70,cookie=$TestCookie,priority=230,ip,nw_dst=$Dst2IP actions=drop"

ovs-ofctl add-flow br-int "table=110,cookie=$TestCookie,priority=230,ip,nw_dst=$Dst1IP actions=drop"
ovs-ofctl add-flow br-int "table=110,cookie=$TestCookie,priority=230,ip,nw_dst=$Dst2IP actions=drop"


ovs-ofctl add-flow br-int "table=110,cookie=$TestCookie,priority=230,ip,nw_dst=$Dst1IP actions=drop"
ovs-ofctl add-flow br-int "table=110,cookie=$TestCookie,priority=230,ip,nw_dst=$Dst2IP actions=drop"

$SrcIP="10.176.25.103"
ovs-ofctl add-flow br-int "table=110,cookie=$TestCookie,priority=230,ip,nw_src=$SrcIP,reg0=0x1/0xffff actions=in_port"


ovs-ofctl add-flow br-int "table=110,cookie=$TestCookie,priority=230,ip,nw_src=$GwIP,reg0=0x1/0xffff,nw_dst=$Dst1IP actions=in_port"
ovs-ofctl add-flow br-int "table=110,cookie=$TestCookie,priority=230,ip,nw_src=$GwIP,reg0=0x1/0xffff,nw_dst=$Dst2IP actions=in_port"

ovs-ofctl add-flow br-int "table=30,cookie=$TestCookie,priority=230,ip,nw_dst=$GwIP,reg0=0x4/0xffff actions=drop"
ovs-ofctl add-flow br-int "table=31,cookie=$TestCookie,priority=230,ip,nw_dst=$GwIP,reg0=0x4/0xffff,ct_state=-new+trk actions=2"

ovs-ofctl add-flow br-int "table=110,cookie=$TestCookie,priority=230,ip,nw_dst=$GwIP,reg0=0x4/0xffff actions=2"
ovs-ofctl add-flow br-int "table=70,cookie=$TestCookie,priority=230,ip,nw_dst=$GwIP,reg0=0x4/0xffff actions=2"



$DstIP="192.168.187.1"
$DstIPHex="0x"
$DstIP -split "\." | ForEach-Object {$DstIPHex=$DstIPHex + ("{0:X2}" -f  [convert]::ToInt32($_, 10)) }
$DstMac="00:15:5D:19:67:2F"
$DstMacHex="0x" + $DstMac -replace ":",""
ovs-ofctl add-flow br-int "table=20,cookie=$Cookie,priority=210,arp,arp_tpa=$DstIP,arp_op=1 actions=move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[],mod_dl_src:$DstMac,load:0x2->NXM_OF_ARP_OP[],move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[],load:$DstMacHex->NXM_NX_ARP_SHA[],move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[],load:$DstIPHex->NXM_OF_ARP_SPA[],IN_PORT"
```