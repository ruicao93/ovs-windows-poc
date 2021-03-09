## Overview

By policy:
- External Policy(SNAT source IP to GW IP)
  - By source:
    - ExternalIP
    - LocalNodePortIP
    - LocalPodIP
  - By Endpoint:
    - Pod:
      - LocalPod
      - RemotePod
    - HostNetwork
      - Local Node
      - Remote Node

- Local Policy(Keep source IP)
  - By source:
    - ExternalIP
    - LocalNodePortIP
    - LocalPodIP
  - By Endpoint:
    - Pod:
      - LocalPod
    - HostNetwork
      - Local Node

Total cases: 3 * 4 + 3 * 2 = 18
