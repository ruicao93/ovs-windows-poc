

## Flows

### Common matches && actions && registers

Matchs:
- IP: nw_src, nw_dst
- MAC: dl_src, dl_dst

Actions:
- IP: mod_nw_src, mod_nw_dst
- MAC: mod_dl_src, mod_dl_dst
- output:1
- resubmit(,10)

Registers:
- NXM_NX_PKT_MARK/pkt_mark

### Resubmit to another table

ovs-ofctl add-flow br-ext "table=11,cookie=0x520,priority=190 actions=resubmit(,20)"

### ARP responder flow

``` powershell
$SVCIPHex="0xA6F2BC4" # 10.111.43.196
$SVCVMacHex="0xaabbccddeeff"

ovs-ofctl add-flow br-int "table=0,cookie=0x520,priority=200,arp,arp_tpa=$SVCIP,arp_op=1 actions=move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[],mod_dl_src:aa:bb:cc:dd:ee:ff,load:0x2->NXM_OF_ARP_OP[],move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[],load:$SVCVMacHex->NXM_NX_ARP_SHA[],move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[],load:$SVCIPHex->NXM_OF_ARP_SPA[],IN_PORT"
```

```
cookie=0x1020000000000, duration=345846.885s, table=20, n_packets=0, n_bytes=0, priority=200,arp,arp_tpa=172.18.0.1,arp_op=1 actions=move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_
DST[],mod_dl_src:aa:bb:cc:dd:ee:ff,load:0x2->NXM_OF_ARP_OP[],move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[],load:0xaabbccddeeff->NXM_NX_ARP_SHA[],move:NXM_OF_ARP_SPA[]->NXM_OF
_ARP_TPA[],load:0xac120001->NXM_OF_ARP_SPA[],IN_PORT
```

### Set tunnel dst endpoint IP

ovs-ofctl add-flow br-int "table=0,cookie=0x520,in_port=$PodPort,priority=200,ip,nw_dst=192.168.186.0/24 actions=load:0x0ab01967->NXM_NX_TUN_IPV4_DST[],output:$TunPort"

### ct_zone && ct_state && NAT

``` powershell
# Enter CT zone and prform NAT
ovs-ofctl add-flow br-ext "table=10,cookie=0x520,priority=200,ip actions=ct(table=11,zone=65520,nat)"

# Do NAT and commit connection to contrack
ovs-ofctl add-flow br-ext "table=11,cookie=0x520,priority=200,in_port=LOCAL,ip,nw_src=192.168.187.0/24,ct_state=+new+trk actions=ct(commit,table=20,zone=65520,nat(src=$NodeIP))"
```

### Output

ovs-ofctl add-flow br-int "table=0,cookie=0x520,in_port=$TunPort,priority=200,ip actions=mod_dl_src:$GwMac,mod_dl_dst=$PodMac,output:$PodPort"

## Others

### Trace

```
ovs-appctl ofproto/trace br-int  in_port=2,tcp,dl_src=e6:ac:cb:2e:30:93,dl_dst=1e:bd:09:83:af:a5,nw_src=10.244.1.1,nw_dst=10.244.1.8,tcp_dst=80,nw_ttl=255
```

### Create OVSDB file

``` bash
$OVSInstallDir="C:\openvswitch"
$OVS_DB_SCHEMA_PATH = "$OVSInstallDir\usr\share\openvswitch\vswitch.ovsschema"
$OVS_DB_PATH="c:\test\ovs.db"
ovsdb-tool create "$OVS_DB_PATH" "$OVS_DB_SCHEMA_PATH"
```

