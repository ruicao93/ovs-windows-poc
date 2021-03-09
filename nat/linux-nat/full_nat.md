## DNAT + SNAT in same zone test at same time

``` bash
gw_ip="192.168.185.1"
gw_ip_hex="0xC0A8B901"
gw_mac="9a:7f:7b:69:26:9b"
gw_mac_hex="0x9a7f7b69269b"


src_ip="192.168.185.2"
vsrc_ip="192.168.199.41"
src_mac="5e:f0:ca:95:d1:97"


dst_ip="192.168.185.3"
vdst_ip="192.168.199.42"
dst_mac="a2:f2:b5:9c:c4:58"

src_port=1
dst_port=2

ct_zone=10086
ct_zone_dnat=10087
ct_zone_snat=10088

dnat_ct_mark="0x520"
snat_ct_mark="0x521"
postsnat_ct_mark="0x522"
snat_done_mark="0x1"

Cookie="0x520"
CTZone="65520"


ip link add dev11  type veth peer name dev12
ip link add dev21  type veth peer name dev22
ip netns add n1                          
ip netns add n2
ip link set dev12 netns n1
ip link set dev22 netns n2

ip netns exec n1 ip addr add $src_ip/24 dev dev12
ip netns exec n1 ip link set dev12 up
ip netns exec n1 ip route add default via $gw_ip

ip netns exec n2 ip addr add $dst_ip/24 dev dev22
ip netns exec n2 ip link set dev22 up
ip netns exec n2 ip route add default via $gw_ip


ip link set dev11 up
ip link set dev21 up



ovs-vsctl add-br br-int
ovs-vsctl add-port br-int dev11 
ovs-vsctl add-port br-int dev21

ip netns exec n1 ping 192.168.185.3 -c 3
ip netns exec n2 ping 192.168.185.2 -c 3

ovs-ofctl del-flows br-int

ClassifierTable=0
ARPResponderTable=1
DnatTable=2
SnatTable=3
ForwardTable=4

ovs-ofctl add-flow br-int "table=$ClassifierTable, cookie=$Cookie,priority=180,in_port=$src_port,ip,nw_dst=$vdst_ip actions=ct(table=$DnatTable,zone=$CTZone,nat)"
ovs-ofctl add-flow br-int "table=$ClassifierTable, cookie=$Cookie,priority=200,in_port=$dst_port,ip,nw_dst=$vsrc_ip actions=ct(table=$DnatTable,zone=$CTZone,nat)"
ovs-ofctl add-flow br-int "table=$ClassifierTable, cookie=$Cookie,priority=200,arp,arp_tpa=$gw_ip,arp_op=1 actions=move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[],mod_dl_src:aa:bb:cc:dd:ee:ff,load:0x2->NXM_OF_ARP_OP[],move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[],load:$gw_mac_hex->NXM_NX_ARP_SHA[],move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[],load:$gw_ip_hex->NXM_OF_ARP_SPA[],IN_PORT"
ovs-ofctl add-flow br-int "table=$ClassifierTable, cookie=$Cookie,priority=0 actions=drop"

ovs-ofctl add-flow br-int "table=$DnatTable, cookie=$Cookie, priority=180, ct_state=+new+trk,ip,in_port=$src_port,nw_src=$src_ip,nw_dst=$vdst_ip actions=ct(table=$SnatTable,zone=$CTZone,nat(dst=$dst_ip))"
ovs-ofctl add-flow br-int "table=$DnatTable, cookie=$Cookie, priority=180, ct_state=-new+trk,ip actions=resubmit(,$ForwardTable)"
ovs-ofctl add-flow br-int "table=$DnatTable, cookie=$Cookie,priority=0 actions=drop"

ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie, priority=180, ct_state=+new+trk,ip,in_port=$src_port,nw_src=$src_ip,nw_dst=$dst_ip actions=ct(commit,table=$ForwardTable,zone=$CTZone,nat(src=$vsrc_ip))"
ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=0 actions=drop"

ovs-ofctl add-flow br-int "table=$ForwardTable, cookie=$Cookie, priority=180,in_port=$src_port,ip,nw_src:$vsrc_ip,nw_dst=$dst_ip actions=mod_dl_src:$gw_mac,mod_dl_dst:$dst_mac,output:$dst_port"
ovs-ofctl add-flow br-int "table=$ForwardTable, cookie=$Cookie, priority=180,in_port=$dst_port,ip,nw_src:$dst_ip,nw_dst=$vsrc_ip actions=mod_dl_src:$gw_mac,,mod_dl_dst:$src_mac,output:$src_port"
ovs-ofctl add-flow br-int "table=$ForwardTable, cookie=$Cookie,priority=0 actions=drop"


##################### Try:
ovs-ofctl add-flow br-int "table=$DnatTable, cookie=$Cookie, priority=180, ct_state=+new+trk,ip,in_port=$src_port,nw_src=$src_ip,nw_dst=$vdst_ip actions=ct(nat(dst=$dst_ip)),resubmit(,$SnatTable)"
ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie, priority=180, ct_state=+new+trk,ip,in_port=$src_port,nw_src=$src_ip,nw_dst=$dst_ip actions=ct(commit,table=$ForwardTable,zone=$CTZone,nat(src=$vsrc_ip,dst=$dst_ip))"
#####################

# ===========再次确认 same zone, DNAT + SNAT:=======================
# ======= 1. Req 方向 =========
# 0.先进入nat
ovs-ofctl add-flow br-int "cookie=$cookie,table=0,priority=250,in_port=$src_port,tcp,nw_dst=$vdst_ip actions=ct(table=1,zone=$ct_zone,nat)"
ovs-ofctl add-flow br-int "cookie=$cookie,table=0,priority=240,in_port=$src_port,tcp,nw_dst=$vdst_ip actions=drop"

# 1.check ct_mark
ovs-ofctl add-flow br-int "cookie=$cookie,table=1,priority=250,in_port=$src_port,ip,ct_state=+new+trk actions=resubmit(,2)"
ovs-ofctl add-flow br-int "cookie=$cookie,table=1,priority=250,in_port=$src_port,ip,ct_state=-new+trk,ct_mark=$dnat_ct_mark actions=ct(table=2,zone=$ct_zone,nat)"
ovs-ofctl add-flow br-int "cookie=$cookie,table=1,priority=250,in_port=$src_port,ip,ct_state=-new+trk,ct_mark=$postsnat_ct_mark actions=resubmit(,4)"

ovs-ofctl add-flow br-int "cookie=$cookie,table=1,priority=240 actions=drop"

# 2dnattable
ovs-ofctl add-flow br-int "cookie=$cookie,table=2,priority=250,in_port=$src_port,ip,nw_dst=$vdst_ip,ct_state=+new+trk actions=ct(table=3,zone=$ct_zone,nat(dst=$dst_ip),exec(load:$dnat_ct_mark->NXM_NX_CT_MARK[]))"

ovs-ofctl add-flow br-int "cookie=$cookie,table=2,priority=240 actions=resubmit(,3)"

# 3snattable
ovs-ofctl add-flow br-int "cookie=$cookie,table=3,priority=250,in_port=$src_port,ip,nw_dst=$dst_ip,ct_state=+new+trk+dnat actions=ct(commit,table=4,zone=$ct_zone,nat(src=$vsrc_ip),exec(load:$postsnat_ct_mark->NXM_NX_CT_MARK[]))"

ovs-ofctl add-flow br-int "cookie=$cookie,table=3,priority=240 actions=resubmit(,4)"

# 4outputtable
ovs-ofctl add-flow br-int "cookie=$cookie,table=4,priority=240,in_port=$src_port actions=mod_dl_src:$gw_mac,mod_dl_dst:$dst_mac,output:$dst_port"
ovs-ofctl add-flow br-int "cookie=$cookie,table=4,priority=240,in_port=$dst_port actions=mod_dl_src:$gw_mac,mod_dl_dst:$src_mac,output:$src_port"

# ovs-ofctl add-flow br-int "cookie=$cookie,table=4,priority=250,tcp,in_port=$src_port,nw_src=$src_ip,nw_dst=$dst_ip actions=drop"
# ovs-ofctl add-flow br-int "cookie=$cookie,table=4,priority=250,tcp,in_port=$src_port,nw_src=$src_ip,nw_dst=$dst_ip,ct_state=+new+trk+snat  actions=drop"
# ovs-ofctl add-flow br-int "cookie=$cookie,table=4,priority=250,tcp,in_port=$src_port,nw_src=$src_ip,nw_dst=$dst_ip,ct_state=-new+trk+snat  actions=drop"
# ovs-ofctl add-flow br-int "cookie=$cookie,table=4,priority=250,tcp,in_port=$src_port,nw_src=$src_ip,nw_dst=$dst_ip,ct_state=+new+trk  actions=drop"
# ovs-ofctl add-flow br-int "cookie=$cookie,table=4,priority=250,tcp,in_port=$src_port,nw_src=$src_ip,nw_dst=$dst_ip,ct_state=+new+trk+dnat  actions=drop"


#  =======  2.Reply 方向 ======
# 0先进入nat
ovs-ofctl add-flow br-int "cookie=$cookie,table=0,priority=250,in_port=$dst_port,tcp,nw_dst=$vsrc_ip actions=ct(table=1,zone=$ct_zone,nat)"
ovs-ofctl add-flow br-int "cookie=$cookie,table=0,priority=240,in_port=$dst_port,tcp,nw_dst=$vsrc_ip actions=drop"

# 1check ct_mark
ovs-ofctl add-flow br-int "cookie=$cookie,table=1,priority=250,in_port=$dst_port,ip,ct_state=-new+trk,ct_mark=$postsnat_ct_mark actions=ct(table=1,zone=$ct_zone,nat)"
ovs-ofctl add-flow br-int "cookie=$cookie,table=1,priority=250,in_port=$dst_port,ip,ct_state=-new+trk,ct_mark=$dnat_ct_mark actions=resubmit(,4)"
ovs-ofctl add-flow br-int "cookie=$cookie,table=1,priority=240,in_port=$dst_port,ip,ct_state=+new+trk actions=drop"
```