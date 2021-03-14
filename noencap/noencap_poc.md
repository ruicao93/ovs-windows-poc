
## Final fix

- Enable noencap feature for Windows.
- Add routes for peer nodes.
- Forward reply packages received from uplink to sender Pod directly for non-service connection.


0. Pod --> Pod, inra node
1. Pod --> Pod, inter nodes
(1) Local Pod --> Remote Pod
Req: ClientPod --> OVS --> GW --> Host(routing), decide next hop --> br-int --> uplink
Reply: ServerPod --> Uplink --> OVS --> ClientPod

Jianjun: Host connection track.


++ flow
``` powershell
$Cookie="0x520"
ovs-ofctl add-flow br-int "table=31,cookie=$Cookie,priority=220,ip,reg0=0x4/0xfff,nw_dst=192.168.187.0/24,ct_state=-new+trk actions=load:0x1->NXM_NX_REG0[19],resubmit(,50)"
ovs-ofctl add-flow br-int "table=31,cookie=$Cookie,priority=220,ip,reg0=0x4/0xfff,nw_dst=192.168.186.0/24,ct_state=-new+trk actions=load:0x1->NXM_NX_REG0[19],resubmit(,50)"
```

(2) Remote Pod --> Local Pod
Req: RemoteClientPod --> Uplink --> OVS 

++ flow
``` powershell
ovs-ofctl add-flow br-int "table=31,cookie=$Cookie,priority=220,ip,reg0=0x4/0xfff,nw_dst=192.168.187.0/24,ct_state=+new+trk actions=load:0x1->NXM_NX_REG0[19],resubmit(,50)"
ovs-ofctl add-flow br-int "table=31,cookie=$Cookie,priority=220,ip,reg0=0x4/0xfff,nw_dst=192.168.186.0/24,ct_state=+new+trk actions=load:0x1->NXM_NX_REG0[19],resubmit(,50)"
```


Merge two new flows:
``` powershell
$LcoalPodCIDR="192.168.187.0/24"
ovs-ofctl add-flow br-int "table=31,cookie=$Cookie,priority=210,ip,reg0=0x4/0xfff,nw_dst=$LcoalPodCIDR actions=load:0x1->NXM_NX_REG0[19],resubmit(,50)"
```


2. Pod --> Service
(1) Endpoint is local Pod
Same with case0.

(2) Endpoint is remote Pod
Req: ClientPod --> OVS --> DNAT(select endpoint) --> GW --> Host(routing), decide next hop --> br-int --> uplink
Reply: ServerPod --> Uplink --> OVS --> d-DNAT --> ClientPod

(3) From remotePod

(4) From remote host
Req: RemoteNode(NodeIP) --> Uplink --> OVS --> LocalPod
Reply: LocalPod --> OVS --> gw --> host --> br-int --> OVS --> Uplink


2. Host --> Local Pod
Req: Host(GwIP)  --> Gw --> OVS --> ServerPod
Reply: ServerPod --> OVS --> Gw --> Host(GwIP)

3. Host --> Remote Pod
Req: Host(GwIP)  --> br-int --> OVS --> Uplink --> ServerPod
Reply: ServerPod --> Uplink --> OVS --> br-int --> Host(GwIP)

4. Host --> Service
(1) Endpoint is local Pod
Req: Host(?) --> kube-proxy(Endpoint selection) --> Gw --> OVS --> ServerPod
Reply: ServerPod --> OVS --> Gw --> kube-proxy --> Host

(2) Endpoint is remote Pod
Req: Host(?) --> kube-proxy(Endpoint selection) --> br-int --> OVS --> uplink --> ServerPod
Reply: ServerPod --> Uplink --> OVS --> br-int --> kube-proxy --> Host


## Basic patch 

branch: noencap_v2:
- Enable noencap feature for Windows.
- Add routes for peer nodes.
- (Need to be removed)Forward reply packages received from uplink to sender Pod directly.


## Test

- Remove `Forward reply packages received from uplink to sender Pod directly.`
- Enable IP forwarding on br-int
- For reply pkts of service endpoint, add flow to let the pkts be forwarded to br-int firstly.
- Remove following flow for noencap: pkg/agent/openflow/pipeline.go:743
```
		flows = append(flows, c.pipeline[conntrackStateTable].BuildFlow(priorityHigh).
			MatchProtocol(ipProtocol).
			MatchCTStateNew(false).MatchCTStateTrk(true).
			MatchCTMark(ServiceCTMark, nil).
			MatchRegRange(int(marksReg), markTrafficFromUplink, binding.Range{0, 15}).
			Action().LoadRegRange(int(marksReg), macRewriteMark, macRewriteMarkRange).
			Action().GotoTable(EgressRuleTable).
			Cookie(c.cookieAllocator.Request(cookie.Service).Raw()).
			Done())
```


``` powershell
$TestCookie="0x999"
```

``` powershell
# Disable cksum offload on uplink interface
Disable-NetAdapterChecksumOffload -Name "Ethernet0 2" -TcpIPv4
Disable-NetAdapterChecksumOffload -Name "Ethernet0 2" -IPIPv4

#Disable-NetAdapterChecksumOffload -Name Ethernet0 -TcpIPv4
#Disable-NetAdapterChecksumOffload -Name Ethernet0 -IPIPv4

# Disable cksum offload on antrea interfaces: br-int && antrea-gw0
Disable-NetAdapterChecksumOffload -Name br-int -IPIPv4
Disable-NetAdapterChecksumOffload -Name br-int -TcpIPv4
Disable-NetAdapterChecksumOffload -Name antrea-gw0 -IPIPv4
Disable-NetAdapterChecksumOffload -Name antrea-gw0 -TcpIPv4

# Enable IP forwarding on br-int
Set-NetIPInterface -InterfaceAlias br-int -Forwarding enabled
Get-NetIPInterface -InterfaceAlias br-int | Select-Object -Property forwarding

# Disable cksum offload on container interfaces
Disable-NetAdapterChecksumOffload -Name "vEthernet (winpy-7b-5dbc7f)" -IPIPv4
Disable-NetAdapterChecksumOffload -Name "vEthernet (winpy-7b-5dbc7f)" -TcpIPv4

# For reply pkts of service endpoint, add flow to let the pkts be forwarded to br-int firstly.
ovs-ofctl add-flow br-int "table=31,cookie=$TestCookie,priority=220,ip,reg0=0x4/0xfff,nw_dst=192.168.187.0/24,ct_state=-new+trk actions=load:0x1->NXM_NX_REG0[19],resubmit(,50)"
# ovs-ofctl add-flow br-int "table=5,cookie=$TestCookie,priority=210,ip,reg0=0x4/0xfff,nw_dst=192.168.187.0/24 actions=LOCAL"
# ovs-ofctl del-flows br-int "table=5,cookie=$TestCookie/-1"
```

Test result:

Checksum incorrect until 3 retries.

## Disable br-int forwarding and let reply pkts direct to pod is ok




## Test enable IP forward

ovs-vswitchd CPU usage:
- Before enable: 
- After enable: 2.9%
