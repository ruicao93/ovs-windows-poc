## Pod --> External

Pod: agnhost--3eb7fb
31(agnhost--3eb7fb)

IP=172.16.0.32
Mac="4a:95:7b:d4:8d:5b"
Port=31
GwMac="0a:58:dd:bf:64:b9"

```
## Trace
ovs-appctl ofproto/trace br-int  in_port=$Port,tcp,dl_src=$Mac,dl_dst=$GwMac,nw_src=$IP,nw_dst=8.8.8.8,tcp_dst=80,nw_ttl=255
```