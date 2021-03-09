
(ExtIP, LocalNodeIP)  ==>  (GwIP, RemotePodIP)

Same with gwip_localPodIP

## Req1

(ExtIP, LocalNodeIP)  --> Uplink --> DNAT(ExtIP, VIP) --> SNAT(GwIP, VIP) --> DNAT(GwIP, LocalPodIP) --> LocalPod


``` powershell
$LocalNodeIP="10.176.25.244"
$LocalNodePort="30232"
$VirtualSVCIP="169.254.169.110"
$GwIP="172.16.2.1"
$GwPort="2"

$UplinkTable=5
$DnatTable=6
$PreSnatTable=7
$SnatTable=8
$PostSnatTable=9



$markTrafficFromTunnel="reg0=0x0/0xffff"
$markTrafficFromGateway="reg0=0x1/0xffff"
$markTrafficFromLocal="reg0=0x2/0xffff"
$markTrafficFromUplink="reg0=0x4/0xffff"
$markTrafficFromBridge="reg0=0x5/0xffff"

$conntrackTable=30
$conntrackStateTable=31
$SVCDnatTable=40
$serviceLBTable=41
$conntrackCommitTable=105
$L2ForwardingOutTable=110


$Cookie="0x520"

$DnatCTZone="52100"
$SnatCTZone="52200"

ovs-ofctl add-flow br-int "table=$UplinkTable, cookie=$Cookie,priority=200,$markTrafficFromUplink,ip,nw_dst=$LocalNodeIP,tcp,tp_dst=$LocalNodePort actions=ct(table=$DnatTable,zone=$DnatCTZone,nat)"

ovs-ofctl add-flow br-int "table=$DnatTable, cookie=$Cookie,priority=200,$markTrafficFromUplink,ip,nw_dst=$LocalNodeIP,tcp,tp_dst=$LocalNodePort,ct_state=+new+trk actions=ct(commit,table=$PreSnatTable,zone=$DnatCTZone,nat(dst=$VirtualSVCIP))"
ovs-ofctl add-flow br-int "table=$DnatTable, cookie=$Cookie,priority=200,$markTrafficFromUplink,ip,tcp,tp_dst=$LocalNodePort,ct_state=-new+trk actions=resubmit(,$PreSnatTable)"
ovs-ofctl add-flow br-int "table=$DnatTable, cookie=$Cookie,priority=0 actions=drop"

ovs-ofctl add-flow br-int "table=$PreSnatTable, cookie=$Cookie,priority=200,$markTrafficFromUplink,ip,nw_dst=$VirtualSVCIP,tcp,tp_dst=$LocalNodePort actions=ct(table=$SnatTable,zone=$SnatCTZone,nat)"
ovs-ofctl add-flow br-int "table=$PreSnatTable, cookie=$Cookie,priority=0 actions=drop"

ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=200,$markTrafficFromUplink,ip,nw_dst=$VirtualSVCIP,tcp,tp_dst=$LocalNodePort,ct_state=+new+trk actions=ct(commit,table=$PostSnatTable,zone=$SnatCTZone,nat(src=$GwIP))"
ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=200,$markTrafficFromUplink,ip,tcp,tp_dst=$LocalNodePort,ct_state=-new+trk actions=resubmit(,$PostSnatTable)"
ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=0 actions=drop"


ovs-ofctl add-flow br-int "table=$PostSnatTable, cookie=$Cookie,priority=200,ip,$markTrafficFromUplink actions=ct(table=$conntrackTable,zone=65500,nat)"
ovs-ofctl add-flow br-int "table=$PostSnatTable, cookie=$Cookie,priority=0 actions=drop"

ovs-ofctl add-flow br-int "table=$conntrackStateTable, cookie=$Cookie,priority=210,ip,$markTrafficFromUplink,nw_dst=$VirtualSVCIP,tcp,tp_dst=$LocalNodePort,ct_state=+new+trk actions=resubmit(,$SVCDnatTable),resubmit(,$serviceLBTable)"
```

## Reply1

RemotePod(LocalPodIP, GwIP) --> Tunnel --> d-DNAT(VIP, GwIP) --> d-SNAT(VIP, ExtIP) --> d-DNAT(LocalNodeIP, ExtIP) --> gw --> host

``` powershell
ovs-ofctl add-flow br-int "table=$L2ForwardingOutTable, cookie=$Cookie,priority=200,ip,nw_src=$VirtualSVCIP,nw_dst=$GwIP,tcp,tp_src=$LocalNodePort actions=ct(table=$SnatTable,zone=$SnatCTZone,nat)"

ovs-ofctl add-flow br-int "table=$SnatTable, cookie=$Cookie,priority=200,ip,nw_src=$VirtualSVCIP,tcp,tp_src=$LocalNodePort,ct_state=-new+trk actions=ct(table=$DnatTable,zone=$DnatCTZone,nat)"

ovs-ofctl add-flow br-int "table=$DnatTable, cookie=$Cookie,priority=200,ip,nw_src=$LocalNodeIP,tcp,tp_src=$LocalNodePort,ct_state=-new+trk actions=$GwPort"

```

## Reply2

host(ExtIP, LocalNodeIP) --> br-int --> Uplink

``` Powershell
# No additional flows are needed
```

## Test: Success

```
root@a-ms-2000-0:/home/ubuntu/test-ymls# curl 10.176.25.244:31736
Hello Antrea!
Windows-10-10.0.17763-SP0
ServerIP: 172.16.2.4
ClientIP: 172.16.2.1
```



Linux success request pkts on endpoint container:
```
root@a-ms-2000-0:/home/ubuntu# tcpdump -i eth0 -en port 8080
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
04:53:36.353399 0a:58:dd:bf:64:b9 > 4a:95:7b:d4:8d:5b, ethertype IPv4 (0x0800), length 74: 172.16.0.1.44860 > 172.16.0.32.8080: Flags [S], seq 938866061, win 64240, options [mss 1460,sackOK,TS val 4158912320 ecr 0,nop,wscale 7], length 0
04:53:36.353444 4a:95:7b:d4:8d:5b > 0a:58:dd:bf:64:b9, ethertype IPv4 (0x0800), length 74: 172.16.0.32.8080 > 172.16.0.1.44860: Flags [S.], seq 3736389015, ack 938866062, win 64308, options [mss 1410,sackOK,TS val 1857172179 ecr 4158912320,nop,wscale 7], length 0
04:53:36.354098 0a:58:dd:bf:64:b9 > 4a:95:7b:d4:8d:5b, ethertype IPv4 (0x0800), length 66: 172.16.0.1.44860 > 172.16.0.32.8080: Flags [.], ack 1, win 502, options [nop,nop,TS val 4158912321 ecr 1857172179], length 0
04:53:36.354230 0a:58:dd:bf:64:b9 > 4a:95:7b:d4:8d:5b, ethertype IPv4 (0x0800), length 143: 172.16.0.1.44860 > 172.16.0.32.8080: Flags [P.], seq 1:78, ack 1, win 502, options [nop,nop,TS val 4158912321 ecr 1857172179], length 77: HTTP: GET / HTTP/1.1
04:53:36.354255 4a:95:7b:d4:8d:5b > 0a:58:dd:bf:64:b9, ethertype IPv4 (0x0800), length 66: 172.16.0.32.8080 > 172.16.0.1.44860: Flags [.], ack 78, win 502, options [nop,nop,TS val 1857172180 ecr 4158912321], length 0
04:53:36.354606 4a:95:7b:d4:8d:5b > 0a:58:dd:bf:64:b9, ethertype IPv4 (0x0800), length 197: 172.16.0.32.8080 > 172.16.0.1.44860: Flags [P.], seq 1:132, ack 78, win 502, options [nop,nop,TS val 1857172180 ecr 4158912321], length 131: HTTP: HTTP/1.1 200 OK
04:53:36.354695 0a:58:dd:bf:64:b9 > 4a:95:7b:d4:8d:5b, ethertype IPv4 (0x0800), length 66: 172.16.0.1.44860 > 172.16.0.32.8080: Flags [.], ack 132, win 501, options [nop,nop,TS val 4158912321 ecr 1857172180], length 0
04:53:36.354852 0a:58:dd:bf:64:b9 > 4a:95:7b:d4:8d:5b, ethertype IPv4 (0x0800), length 66: 172.16.0.1.44860 > 172.16.0.32.8080: Flags [F.], seq 78, ack 132, win 501, options [nop,nop,TS val 4158912322 ecr 1857172180], length 0
04:53:36.355378 4a:95:7b:d4:8d:5b > 0a:58:dd:bf:64:b9, ethertype IPv4 (0x0800), length 66: 172.16.0.32.8080 > 172.16.0.1.44860: Flags [F.], seq 132, ack 79, win 502, options [nop,nop,TS val 1857172181 ecr 4158912322], length 0
04:53:36.355442 0a:58:dd:bf:64:b9 > 4a:95:7b:d4:8d:5b, ethertype IPv4 (0x0800), length 66: 172.16.0.1.44860 > 172.16.0.32.8080: Flags [.], ack 133, win 501, options [nop,nop,TS val 4158912322 ecr 1857172181], length 0
^C
10 packets captured
10 packets received by filter
0 packets dropped by kernel
```