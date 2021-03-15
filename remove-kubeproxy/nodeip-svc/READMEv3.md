## Overview

<https://kubernetes.io/docs/tutorials/services/source-ip/>
<https://kubernetes.io/docs/concepts/services-networking/service/>


### NodePort cases

By policy:
- Cluster Policy(SNAT source IP to GW IP)
  - By source:
    - External
    - LocalNode
    - LocalPod
  - By Endpoint:
    - Pod:
      - LocalPod
      - RemotePod
    - HostNetwork
      - Local Node(p1)
      - Remote Node

- Local Policy(Keep source IP)
  - By source:
    - External
    - LocalNode
    - LocalPod
  - By Endpoint:
    - Pod:
      - LocalPod
    - HostNetwork
      - Local Node(p1)

Total cases: 3 * 4 + 3 * 2 - 3(p1) - 3(p1) = 12

TBD: NoEncap

### NodePort service filter tables

Table1: Match NodePort IPs
Table2: Match NodePort ports

Table1 * Table2: Match NodePort service access: mark NodePort service connection and DNAT(VIP)

## Cluster Policy cases

1. (External, LocalPod): PASS

Request: (ExtIP, LocalNodeIP)  --> Uplink --> DNAT(ExtIP, VIP) -->  SNAT(GwIP, VIP) --> DNAT(GwIP, LocalPodIP) --> LocalPod
Reply: LocalPod --> (LocalPodIP, GwIP) --> unDNAT(VIP, GwIP) --> unSNAT(VIP, ExtIP) --> unDNAT(LocalNodeIP, ExtIP) --> gw --> host --> br-int --> uplink

ReplyMatch: (VIP, GwIP) && from local

2. (External, RemotePod): HalfSuccess(Incorrect TCP sequence)

Request: (ExtIP, LocalNodeIP)  --> Uplink --> DNAT(ExtIP, VIP) -->  SNAT(GwIP, VIP) --> DNAT(GwIP, RemotePodIP) --> Tunnel --> RemotePodIP
Reply: RemotePodIP --> Tunnel --> (RemotePodIP, GwIP) --> unDNAT(VIP, GwIP) --> unSNAT(VIP, ExtIP) --> unDNAT(LocalNodeIP, ExtIP) --> gw --> host --> br-int --> uplink

ReplyMatch: (VIP, GwIP) && from tunnel

3. P1:(External, LocalHostNetworkEndpoint)

Req: (ExtIP, LocalNodeIP)  --> Uplink --> DNAT(ExtIP, VIP) --> SNAT(GwIP, VIP) --> DNAT(GwIP, LocalHostNetworkEndpointIPPort) --> gw --> LocalHostNetworkEndpoint(Host)
Repl: LocalHostNetworkEndpoint --> br-int(LocalHostNetworkEndpointIPPort, GwIP) --> unDNAT(VIP, GwIP) --> unSNAT(VIP, ExtIP) --> unDNAT(LocalNodeIP, ExtIP) --> gw --> host --> br-int --> uplink

ReplyMatch: (VIP, GwIP) && from bridge

4. (External, RemoteHostNetworkEndpoint): Fail, unknown issue

Req1: (ExtIP, LocalNodeIP)  --> Uplink --> DNAT(ExtIP, VIP) -->  SNAT(GwIP, VIP) --> DNAT(GwIP, RemoteNodeIP) --> SNAT(LocalNodeIP, RemoteNodeIP) --> gw --> host --> br-int --> RemoteNode
Repl1: RemoteNode --> (RemoteNodeIP, LocalNodeIP) --> uplink  --> unSNAT(RemoteNodeIP, GwIP) --> unDNAT(VIP, GwIP) --> unSNAT(VIP, ExtIP) --> unDNAT(LocalNodeIP, ExtIP) --> Gw --> host --> br-int --> uplink

ReplyMatch: (LocalNodeIP, GwIP) && from local

5. TBD (LocalPod, LocalEndpointPod)

- Option1: Prefer
Req: (LocalPodIP, LocalNodeIP)  --> Gw --> UserProxy: DNAT(LocalNodeIP, VIP) --> ...
Req: (LocalPodIP, LocalNodeIP)  --> Gw  ==>  (Access NodePort service from host)

Reply: ... UserProxy --> unDNAT(LocalNodeIP, LocalPodIP) --> br-int --> Source local pod


- Option2:
Req: (LocalPodIP, LocalNodeIP)  --> DNAT(LocalPodIP, VIP) -->  SNAT(GwIP, VIP) --> DNAT(GwIP, LocalEndpointPodIP) --> LocalPod
Reply: (LocalEndpointPodIP, GwIP) --> unDNAT(VIP, GwIP) --> unSNAT(VIP, LocalPodIP) --> unDNAT(LocalNodeIP, LocalPodIP) --> ?Source Pod? 



6. (LocalNode, LocalEndpointPod): PASS

Req: (LocalNodeIP, LocalNodeIP) --> UserProxy: FullNAT(GwIP, VIP) --> gw --> DNAT(GwIP, LocalPodIP) --> LocalPod
Reply: LocalPod --> (LocalPodIP, GwIP) --> unDNAT(VIP, GwIP) --> gw --> UserProxy: unFullNat(LocalNodeIP, LocalNodeIP) --> source process


- Option2: UserProxy

7. (LocalNode, RemotePod)

Req: (LocalNodeIP, LocalNodeIPPort) --> UserProxy: FullNAT(GwIP, VIP) --> gw --> DNAT(GwIP, RemotePodIP) --> RemotePod
Reply: RemotePod --> (RemotePodIP, GwIP) --> unDNAT(VIP, GwIP) --> gw --> UserProxy: unFullNat(LocalNodeIP, LocalNodeIP) --> source process


8. (LocalNode, RemoteNode)

Req: (LocalNodeIP, LocalNodeIP) --> UserProxy: FullNAT(GwIP, VIP) --> gw --> DNAT(GwIP, RemoteNodeIP) --> SNAT(LocalNodeIP, RemoteNodeIP) --> RemoteNode
Reply: RemoteNode --> (RemoteNodeIP, LocalNodeIP) --> unSNAT(RemoteNodeIP, GwIP) -->  unDNAT(VIP, GwIP) --> gw --> UserProxy: unFullNat(LocalNodeIP, LocalNodeIP) --> source process


## Local Policy cases

1. (External, LocalPod): PASS

Req: (ExtIP, LocalNodeIP)  --> Uplink --> DNAT(ExtIP, LocalPodIP) --> LocalPod
Repl: LocalPod --> (LocalPodIP, ExtIP) --> unDNAT(LocalNodeIP, ExtIP) --> gw --> host --> br-int --> uplink

Add match for snatMarkRequire: MatchSrcIPNet(localSubnet)

MatchRepl: (LocalNodeIP, *) && from local

