

``` powershell
ovs-ofctl add-flow br-int "table=$L2ForwardingOutTable, cookie=$Cookie,priority=210,$markTrafficFromTunnel,ip,nw_src=$LocalNodeIP,nw_dst=$GwIP  actions=ct(table=$SnatTable,zone=$SnatCTZone,nat)"

ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=180,$markTrafficFromTunnel,ip,ct_state=-new+trk actions=$GwPort"
```