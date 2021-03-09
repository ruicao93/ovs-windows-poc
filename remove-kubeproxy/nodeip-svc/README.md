
## NodeIP service

1. External --> NodeIP
(1) (Uplink IP)Node IP which is registered to kubernetes control plane.
(2) Other NodeIPs

2. Host --> NodeIP
(1) Main NodeIP
(2) Other NodeIPs

3. Host --> Node LocalIP(127.0.0.1)


## External --> NodeIP

### 1. Main NodeIP
- RemoteNode --> Main NodeIP:Port

方案1: uplink --> host --> OVS(gw)

```
$NodeIP="10.176.25.244"
$VirtualSVCIP="169.254.169.110"
$VirtualSVCIPHex="0xA9FEA96E" # 169.254.169.110
$VirtualSVCMacHex="0xaabbccddeeff"

## Add route for VirtualSVC
New-NetRoute -DestinationPrefix 169.254.169.110/32 -NextHop 169.254.169.110 -InterfaceAlias antrea-gw0

## Add ARP respondor flow for VirtualSVC
ovs-ofctl add-flow br-int "table=0,cookie=0x520,priority=200,arp,arp_tpa=$VirtualSVCIP,arp_op=1 actions=move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[],mod_dl_src:aa:bb:cc:dd:ee:ff,load:0x2->NXM_OF_ARP_OP[],move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[],load:$VirtualSVCMacHex->NXM_NX_ARP_SHA[],move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[],load:$VirtualSVCIPHex->NXM_OF_ARP_SPA[],IN_PORT"

## Add redirect flow for external access
ovs-ofctl add-flow br-int "table=5,cookie=0x520,priority=210,ip,nw_dst=$NodeIP,tcp,tp_dst=31278,reg0=0x4/0xffff actions=mod_nw_dst:$VirtualSVCIP,output:LOCAL"
ovs-ofctl add-flow br-int "table=5,cookie=0x520,priority=210,ip,nw_src=$VirtualSVCIP,tcp,tp_src=31278,reg0=0x2/0xffff actions=mod_nw_src:$NodeIP,output:3"
# ovs-ofctl del-flows br-int "table=5,cookie=0x520/-1"
#ovs-ofctl add-flow br-int "table=5,cookie=0x520,priority=200,ip,nw_dst=$NodeIP,tcp,tp_dst=31278,reg0=0x4/0xffff actions=mod_nw_src:172.16.2.1,mod_nw_dst:$VirtualSVCIP,output:LOCAL"
#ovs-ofctl add-flow br-int "table=5,cookie=0x520,priority=200,ip,nw_src=$VirtualSVCIP,tcp,tp_src=31278,reg0=0x2/0xffff actions=mod_nw_src:$VirtualSVCIP,mod_nw_dst:$NodeIP,output:3"

## Enable IP forwarding on br-int
Set-NetIPInterface -InterfaceAlias br-int -Forwarding Enabled
```

External --> mod_nw_dst:$VirtualSVCIP -->Host traffic is not forwarded to gw, instead sending back ICMP msg: `redirect network`.

We may need to try a new non-link-local VirtualIP:

```
$NodeIP="10.176.25.244"
$VirtualSVCIP="172.16.2.254"
$VirtualSVCIPHex="0xAC1002FE"
$VirtualSVCMacHex="0xaabbccddeeff"
```
CPU usage is high. Try to drop IGMP pkts:
```
ovs-ofctl add-flow br-int "table=0,cookie=0x520,priority=220,igmp actions=drop"
```

方案2： uplink --> mod_nw_dst:$VirtualSVCIP, LB --> EP
```
$NodeIP="10.176.25.244"
$NodePort="30232"
$VirtualSVCIP="169.254.169.110"

ovs-ofctl add-flow br-int "table=5,cookie=0x520,priority=210,ip,nw_dst=$NodeIP,tcp,tp_dst=$NodePort,reg0=0x4/0xffff actions=mod_nw_dst:$VirtualSVCIP,ct(table=30,zone=65500,nat)"
ovs-ofctl add-flow br-int "table=5,cookie=0x520,priority=210,ip,nw_src=$VirtualSVCIP,tcp,tp_src=$NodePort,reg0=0x2/0xffff actions=mod_nw_src:$NodeIP,output:3"

## Avoid ctstate drop pkts from uplink(by default)
ovs-ofctl add-flow br-int "table=31,cookie=0x520,priority=210,ct_state=+new+trk,ip,reg0=0x4/0xffff,nw_dst:$VirtualSVCIP actions=resubmit(,40),resubmit(,41)"
#ovs-ofctl add-flow br-int "table=31,cookie=0x520,priority=190,ct_state=+new+trk,ip actions=resubmit(,40),resubmit(,41)"
```

Trace flow for debug:
```
$ClientIP="10.176.26.36"
$ClientMac="00:50:56:a7:ca:77"
$ServerIP="10.176.25.244"
$ServerMac="00:50:56:A7:35:0B"
$TCPdst="30232"
$InPort="3"

ovs-appctl ofproto/trace br-int  in_port=$InPort,tcp,dl_src=$ClientMac,dl_dst=$ServerMac,nw_src=$ClientIP,nw_dst=$ServerIP,tcp_dst=$TCPdst,nw_ttl=255
```
Use linux NodePort service. Found on Linux Pod, the pks are forwarded to endpoint through tunnel. But the source IP is still SourceNodeIP
```
11:51:49.268993 0a:58:dd:bf:64:b9 > 4a:95:7b:d4:8d:5b, ethertype IPv4 (0x0800), length 74: 10.176.26.36.42828 > 172.16.0.32.8080: Flags [S], seq 1175812949, win 64240, options [mss 1460,sackOK,TS val 1588731546 ecr 0,nop,wscale 7], length 0
```

One more step, set source IP as GWIP
```
$SourceNodeIP="10.176.26.36"
# ovs-ofctl add-flow br-int "table=5,cookie=0x520,priority=210,ip,nw_dst=$NodeIP,tcp,tp_dst=$NodePort,reg0=0x4/0xffff actions=mod_nw_dst:$VirtualSVCIP,ct(table=30,zone=65500,nat)"
ovs-ofctl add-flow br-int "table=5,cookie=0x520,priority=210,ip,nw_dst=$NodeIP,tcp,tp_dst=$NodePort,reg0=0x4/0xffff actions=mod_nw_src:172.16.2.1,mod_nw_dst:$VirtualSVCIP,ct(table=30,zone=65500,nat)"
# ovs-ofctl add-flow br-int "table=5,cookie=0x520,priority=210,ip,nw_src=$VirtualSVCIP,tcp,tp_src=$NodePort,reg0=0x2/0xffff actions=mod_nw_src:$NodeIP,output:3"
ovs-ofctl add-flow br-int "table=5,cookie=0x520,priority=210,ip,nw_src=$VirtualSVCIP,tcp,tp_src=$NodePort,reg0=0x5/0xffff actions=mod_nw_src:$NodeIP,output:3"
```