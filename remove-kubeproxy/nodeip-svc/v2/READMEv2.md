## Overview

### NodePort cases

By policy:
- External Policy(SNAT source IP to GW IP)
  - By source:
    - External
    - LocalNode
    - LocalPod
  - By Endpoint:
    - Pod:
      - LocalPod
      - RemotePod
    - HostNetwork
      - Local Node
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
      - Local Node

Total cases: 3 * 4 + 3 * 2 = 18

TBD: NoEncap

### NodePort service filter tables

Table1: Match NodePort IPs
Table2: Match NodePort ports

Table1 * Table2: Match NodePort service access and mark NodePort service connection

## External Policy cases

1. (External, LocalPod)

Req: (ExtIP, LocalNodeIP)  --> Uplink --> SNAT(GwIP, LocalNodeIP) --> DNAT(GwIP, LocalPodIP) --> LocalPod
Repl: LocalPod --> (LocalPodIP, GwIP) --> d-DNAT(LocalNodeIP, GwIP) --> d-SNAT(LocalNodeIP, ExtIP) --> gw --> host --> br-int --> uplink

ReplyMatch: (LocalNodeIP, GwIP) && from local

2. (External, RemotePod)

Req: (ExtIP, LocalNodeIP)  --> Uplink --> SNAT(GwIP, LocalNodeIP) --> DNAT(GwIP, RemotePodIP) --> Tunnel --> RemotePod
Repl: RemotePod --> Tunnel(RemotePodIP, GwIP) --> d-DNAT(LocalNodeIP, GwIP) --> d-SNAT(LocalNodeIP, ExtIP) --> gw --> host --> br-int --> uplink

ReplyMatch: (LocalNodeIP, GwIP) && from tunnel

3. (External, LocalHostNetworkEndpoint)

Req: (ExtIP, LocalNodeIP)  --> Uplink --> SNAT(GwIP, LocalNodeIP) --> DNAT(GwIP, LocalHostNetworkEndpointIPPort) --> gw --> LocalHostNetworkEndpoint
Repl: LocalHostNetworkEndpoint --> br-int(LocalHostNetworkEndpointIPPort, GwIP) --> d-DNAT(LocalNodeIP, GwIP) --> d-SNAT(LocalNodeIP, ExtIP) --> gw --> host --> br-int --> uplink

ReplyMatch: (LocalNodeIP, GwIP) && from bridge

4. (External, RemoteHostNetworkEndpoint)

Req: (ExtIP, LocalNodeIP)  --> Uplink --> SNAT(GwIP, LocalNodeIP) --> DNAT(GwIP, RemoteHostNetworkEndpointIPPort) --> SNAT(LocalNodeIP, RemoteHostNetworkEndpointIPPort) --> gw --> host --> br-int --> RemoteHostNetworkEndpoint
Reply: RemoteHostNetworkEndpoint --> uplink(RemoteHostNetworkEndpointIPPort, LocalNodeIP) --> d-SNAT(RemoteHostNetworkEndpointIPPort, GwIP) --> d-DNAT(LocalNodeIP, GwIP) --> d-SNAT(LocalNodeIP, ExtIP) --> gw --> host --> uplink

ReplyMatch: (LocalNodeIP, GwIP) && from local

5. TBD (LocalPod, LocalPod)

Req: (LocalPodIP, LocalNodeIP)  --> OVS --> gw --> SNAT(GwIP, LocalNodeIP) --> DNAT(GwIP, LocalPodIP) --> LocalPod

6. (LocalNode, LocalPod)

- Option1:
Req: (LocalNodeIP, LocalNodeIP) --> UserProxy --> DNAT(LocalNodeIP, VIP) --> br-int --> SNAT(GwIP, VIP) --> DNAT(GwIP, LocalHostNetworkEndpointIPPort) --> gw --> LocalHostNetworkEndpoint
Reply: LocalHostNetworkEndpoint -->  br-int(LocalHostNetworkEndpointIPPort, GwIP) --> d-DNAT(VIP, GwIP) --> d-SNAT(VIP, LocalNodeIP) --> br-int --> UserProxy --> d-DNAT(LocalNodeIP, LocalNodeIP) --> src process

ReqMatch: (*, VIP) && from bridge
ReplyMatch: (VIP, GwIP) && from bridge

- Option2: UserProxy


## Local Policy cases

1. (External, LocalPod)

Req: (ExtIP, LocalNodeIP)  --> Uplink --> DNAT(ExtIP, LocalPodIP) --> LocalPod
Repl: LocalPod --> (LocalPodIP, ExtIP) --> d-DNAT(LocalNodeIP, ExtIP) --> gw --> host --> br-int --> uplink

Add match for snatMarkRequire: MatchSrcIPNet(localSubnet)

MatchRepl: (LocalNodeIP, *) && from local

