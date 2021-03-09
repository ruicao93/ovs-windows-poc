# arp 代答
cookie=0x1020000000000, duration=345846.885s, table=20, n_packets=0, n_bytes=0, priority=200,arp,arp_tpa=172.18.0.1,arp_op=1 actions=move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_
DST[],mod_dl_src:aa:bb:cc:dd:ee:ff,load:0x2->NXM_OF_ARP_OP[],move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[],load:0xaabbccddeeff->NXM_NX_ARP_SHA[],move:NXM_OF_ARP_SPA[]->NXM_OF
_ARP_TPA[],load:0xac120001->NXM_OF_ARP_SPA[],IN_PORT

# nat interface: 00:15:5D:18:D3:66
ovs-ofctl add-flow br-int "table=0,priority=200,arp,arp_tpa=192.168.187.1,arp_op=1 actions=move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[],mod_dl_src:00:15:5D:18:D3:66,load:0x2->NXM_OF_ARP_OP[],move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[],load:0x00155D18D366->NXM_NX_ARP_SHA[],move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[],load:0xc0a8bb01->NXM_OF_ARP_SPA[],IN_PORT"


$GwMac="00:15:5D:18:D3:66"
ovs-ofctl add-flow br-int "table=0,cookie=0x520,in_port=$PodPort,priority=200,ip,nw_dst=192.168.186.0/24 actions=load:0x0ab01967->NXM_NX_TUN_IPV4_DST[],output:$TunPort"
ovs-ofctl add-flow br-int "table=0,cookie=0x520,in_port=$TunPort,priority=200,ip actions=mod_dl_src:$GwMac,mod_dl_dst=$PodMac,output:$PodPort"