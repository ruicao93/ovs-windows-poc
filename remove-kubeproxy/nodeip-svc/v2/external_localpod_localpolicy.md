## (External, LocalPod)

Req: (ExtIP, LocalNodeIP)  --> Uplink --> DNAT(ExtIP, LocalPodIP) --> LocalPod
Repl: LocalPod --> (LocalPodIP, ExtIP) --> d-DNAT(LocalNodeIP, ExtIP) --> gw --> host --> br-int --> uplink

Add match for snatMarkRequire: MatchSrcIPNet(localSubnet)

MatchRepl: (LocalNodeIP, *) && from local


``` powershell

## Skip SNAT in NodePortFilterTables

$LocalNodePort="32373"

ovs-ofctl add-flow br-int "table=$NodePortFilterTable2, cookie=$Cookie,priority=200,ip,tcp,tp_dst=$LocalNodePort actions="

```