## (External, LocalPod): PASS

Req: (ExtIP, LocalNodeIP)  --> Uplink --> DNAT(ExtIP, VIP) --> DNAT(ExtIP, LocalPodIP) --> LocalPod
Repl: LocalPod --> (LocalPodIP, ExtIP) --> unDNAT(VIP, ExtIP) --> unDNAT(LocalNodeIP, ExtIP)--> gw --> host --> br-int --> uplink

Add match for snatMarkRequire: MatchSrcIPNet(localSubnet)

MatchRepl: (LocalNodeIP, *) && from local


``` powershell

## Skip SNAT in NodePortFilterTables

$LocalPolicyNodePort="32373"

# Include basic flows
ovs-ofctl add-flow br-int "table=$UplinkTable, cookie=$Cookie,priority=210,$markTrafficFromUplink,ip,nw_dst=$LocalNodeIP,tcp,tp_dst=$LocalPolicyNodePort actions=resubmit(,$NodePortFilterTable1)"
ovs-ofctl add-flow br-int "table=$NodePortFilterTable2, cookie=$Cookie,priority=200,ip,tcp,tp_dst=$LocalPolicyNodePort actions=ct(table=$DnatTable,zone=$DnatCTZone,nat)"
# ++Flow Especially for local policy to skip SNAT(GwIP)
ovs-ofctl add-flow br-int "table=$PostDnatTable, cookie=$Cookie,priority=200,ip,tcp,tp_dst=$LocalPolicyNodePort actions=resubmit(,$PostSnatTable)"

```

Test:
curl 10.176.25.244:32373