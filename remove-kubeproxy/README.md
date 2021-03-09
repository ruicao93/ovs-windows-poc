1. ClusterIP SVC
(1) LocalPod --> SVC (AntreaProxy)
(2) LocalNode --> SVC (Kube-proxy)
(NodeIP, SVCIP) --> OVS(br-int, gw)

2. NodePort SVC
(1) External --> Local SVC (kube-proxy)
External --> Uplink --> OVS
?
- multiple node ips

(2) LocalNode --> Local SVC (kube-proxy)
(NodeIP, NodeIPPort)
(,127.0.0.1:NodePort)