

## Windows container --> Linux Container: no cksum error

192.168.187.6.49174 > 192.168.184.2.8080: correct

On Container:
```
root@a-ms-1000-0:/home/ubuntu# tcpdump -i eth0 -ne host 192.168.187.6 -vvv
tcpdump: listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
00:35:27.346547 ca:4d:01:c2:40:e5 > 2e:7c:d4:ef:c5:42, ethertype IPv4 (0x0800), length 66: (tos 0x2,ECT(0), ttl 126, id 860, offset 0, flags [DF], proto TCP (6), length 52)
    192.168.187.6.49174 > 192.168.184.2.8080: Flags [SEW], cksum 0xeb5a (correct), seq 1320707403, win 64240, options [mss 1460,nop,wscale 8,nop,nop,sackOK], length 0
00:35:27.346580 2e:7c:d4:ef:c5:42 > ca:4d:01:c2:40:e5, ethertype IPv4 (0x0800), length 66: (tos 0x0, ttl 64, id 0, offset 0, flags [DF], proto TCP (6), length 52)
    192.168.184.2.8080 > 192.168.187.6.49174: Flags [S.], cksum 0xf480 (incorrect -> 0x64ea), seq 2306669417, ack 1320707404, win 64860, options [mss 1410,nop,nop,sackOK,nop,wscale 7], length 0
00:35:27.348409 ca:4d:01:c2:40:e5 > 2e:7c:d4:ef:c5:42, ethertype IPv4 (0x0800), length 54: (tos 0x0, ttl 126, id 861, offset 0, flags [DF], proto TCP (6), length 40)
    192.168.187.6.49174 > 192.168.184.2.8080: Flags [.], cksum 0x82e4 (correct), seq 1, ack 1, win 8195, length 0
00:35:27.348445 ca:4d:01:c2:40:e5 > 2e:7c:d4:ef:c5:42, ethertype IPv4 (0x0800), length 136: (tos 0x0, ttl 126, id 862, offset 0, flags [DF], proto TCP (6), length 122)
    192.168.187.6.49174 > 192.168.184.2.8080: Flags [P.], cksum 0x96b6 (correct), seq 1:83, ack 1, win 8195, length 82: HTTP, length: 82
	GET / HTTP/1.1
	Host: 192.168.184.2:8080
	User-Agent: curl/7.55.1
	Accept: */*
	
00:35:27.348458 2e:7c:d4:ef:c5:42 > ca:4d:01:c2:40:e5, ethertype IPv4 (0x0800), length 54: (tos 0x0, ttl 64, id 47269, offset 0, flags [DF], proto TCP (6), length 40)
    192.168.184.2.8080 > 192.168.187.6.49174: Flags [.], cksum 0xf474 (incorrect -> 0xa09a), seq 1, ack 83, win 507, length 0
00:35:27.348753 2e:7c:d4:ef:c5:42 > ca:4d:01:c2:40:e5, ethertype IPv4 (0x0800), length 129: (tos 0x0, ttl 64, id 47270, offset 0, flags [DF], proto TCP (6), length 115)
    192.168.184.2.8080 > 192.168.187.6.49174: Flags [P.], cksum 0xf4bf (incorrect -> 0x9ece), seq 1:76, ack 83, win 507, length 75: HTTP, length: 75
	HTTP/1.1 200 OK
	Date: Tue, 09 Mar 2021 00:35:27 GMT
	Content-Length: 0
	
00:35:27.349366 ca:4d:01:c2:40:e5 > 2e:7c:d4:ef:c5:42, ethertype IPv4 (0x0800), length 54: (tos 0x0, ttl 126, id 863, offset 0, flags [DF], proto TCP (6), length 40)
    192.168.187.6.49174 > 192.168.184.2.8080: Flags [F.], cksum 0x8246 (correct), seq 83, ack 76, win 8195, length 0
00:35:27.349443 2e:7c:d4:ef:c5:42 > ca:4d:01:c2:40:e5, ethertype IPv4 (0x0800), length 54: (tos 0x0, ttl 64, id 47271, offset 0, flags [DF], proto TCP (6), length 40)
    192.168.184.2.8080 > 192.168.187.6.49174: Flags [F.], cksum 0xf474 (incorrect -> 0xa04d), seq 76, ack 84, win 507, length 0
00:35:27.350045 ca:4d:01:c2:40:e5 > 2e:7c:d4:ef:c5:42, ethertype IPv4 (0x0800), length 54: (tos 0x0, ttl 126, id 864, offset 0, flags [DF], proto TCP (6), length 40)
    192.168.187.6.49174 > 192.168.184.2.8080: Flags [.], cksum 0x8245 (correct), seq 84, ack 77, win 8195, length 0
```

On Host:
```
root@a-ms-1000-0:/home/ubuntu# tcpdump -i ens192 -ne host 192.168.187.6 -vvv
tcpdump: listening on ens192, link-type EN10MB (Ethernet), capture size 262144 bytes
00:35:27.346189 00:50:56:a7:76:9a > 00:50:56:a7:ff:18, ethertype IPv4 (0x0800), length 66: (tos 0x2,ECT(0), ttl 127, id 860, offset 0, flags [DF], proto TCP (6), length 52)
    192.168.187.6.49174 > 192.168.184.2.8080: Flags [SEW], cksum 0xeb5a (correct), seq 1320707403, win 64240, options [mss 1460,nop,wscale 8,nop,nop,sackOK], length 0
00:35:27.346719 00:50:56:a7:ff:18 > 00:50:56:a7:76:9a, ethertype IPv4 (0x0800), length 66: (tos 0x0, ttl 63, id 0, offset 0, flags [DF], proto TCP (6), length 52)
    192.168.184.2.8080 > 192.168.187.6.49174: Flags [S.], cksum 0x64ea (correct), seq 2306669417, ack 1320707404, win 64860, options [mss 1410,nop,nop,sackOK,nop,wscale 7], length 0
00:35:27.348271 00:50:56:a7:76:9a > 00:50:56:a7:ff:18, ethertype IPv4 (0x0800), length 60: (tos 0x0, ttl 127, id 861, offset 0, flags [DF], proto TCP (6), length 40)
    192.168.187.6.49174 > 192.168.184.2.8080: Flags [.], cksum 0x82e4 (correct), seq 1, ack 1, win 8195, length 0
00:35:27.348327 00:50:56:a7:76:9a > 00:50:56:a7:ff:18, ethertype IPv4 (0x0800), length 136: (tos 0x0, ttl 127, id 862, offset 0, flags [DF], proto TCP (6), length 122)
    192.168.187.6.49174 > 192.168.184.2.8080: Flags [P.], cksum 0x96b6 (correct), seq 1:83, ack 1, win 8195, length 82: HTTP, length: 82
	GET / HTTP/1.1
	Host: 192.168.184.2:8080
	User-Agent: curl/7.55.1
	Accept: */*
	
00:35:27.348485 00:50:56:a7:ff:18 > 00:50:56:a7:76:9a, ethertype IPv4 (0x0800), length 54: (tos 0x0, ttl 63, id 47269, offset 0, flags [DF], proto TCP (6), length 40)
    192.168.184.2.8080 > 192.168.187.6.49174: Flags [.], cksum 0xf474 (incorrect -> 0xa09a), seq 1, ack 83, win 507, length 0
00:35:27.348775 00:50:56:a7:ff:18 > 00:50:56:a7:76:9a, ethertype IPv4 (0x0800), length 129: (tos 0x0, ttl 63, id 47270, offset 0, flags [DF], proto TCP (6), length 115)
    192.168.184.2.8080 > 192.168.187.6.49174: Flags [P.], cksum 0xf4bf (incorrect -> 0x9ece), seq 1:76, ack 83, win 507, length 75: HTTP, length: 75
	HTTP/1.1 200 OK
	Date: Tue, 09 Mar 2021 00:35:27 GMT
	Content-Length: 0
	
00:35:27.349343 00:50:56:a7:76:9a > 00:50:56:a7:ff:18, ethertype IPv4 (0x0800), length 60: (tos 0x0, ttl 127, id 863, offset 0, flags [DF], proto TCP (6), length 40)
    192.168.187.6.49174 > 192.168.184.2.8080: Flags [F.], cksum 0x8246 (correct), seq 83, ack 76, win 8195, length 0
00:35:27.349472 00:50:56:a7:ff:18 > 00:50:56:a7:76:9a, ethertype IPv4 (0x0800), length 54: (tos 0x0, ttl 63, id 47271, offset 0, flags [DF], proto TCP (6), length 40)
    192.168.184.2.8080 > 192.168.187.6.49174: Flags [F.], cksum 0xf474 (incorrect -> 0xa04d), seq 76, ack 84, win 507, length 0
00:35:27.350026 00:50:56:a7:76:9a > 00:50:56:a7:ff:18, ethertype IPv4 (0x0800), length 60: (tos 0x0, ttl 127, id 864, offset 0, flags [DF], proto TCP (6), length 40)
    192.168.187.6.49174 > 192.168.184.2.8080: Flags [.], cksum 0x8245 (correct), seq 84, ack 77, win 8195, length 0
```

## Windows container --> NAT(svc) --> Linux Container: cksum error found

On dst host
```
root@a-ms-1000-1:/home/ubuntu/noencap# tcpdump -i ens192 -ne host 192.168.187.6 -vvv
tcpdump: listening on ens192, link-type EN10MB (Ethernet), capture size 262144 bytes
00:41:19.749445 00:50:56:a7:76:9a > 00:50:56:a7:f5:d0, ethertype IPv4 (0x0800), length 66: (tos 0x2,ECT(0), ttl 127, id 28702, offset 0, flags [DF], proto TCP (6), length 52)
    192.168.187.6.49177 > 192.168.185.5.8080: Flags [SEW], cksum 0xf152 (correct), seq 3633108088, win 64240, options [mss 1460,nop,wscale 8,nop,nop,sackOK], length 0
00:41:19.750177 00:50:56:a7:f5:d0 > 00:50:56:a7:76:9a, ethertype IPv4 (0x0800), length 66: (tos 0x0, ttl 63, id 0, offset 0, flags [DF], proto TCP (6), length 52)
    192.168.185.5.8080 > 192.168.187.6.49177: Flags [S.], cksum 0x6bbb (correct), seq 2416833535, ack 3633108089, win 64860, options [mss 1410,nop,nop,sackOK,nop,wscale 7], length 0
00:41:19.751647 00:50:56:a7:76:9a > 00:50:56:a7:f5:d0, ethertype IPv4 (0x0800), length 60: (tos 0x0, ttl 127, id 28703, offset 0, flags [DF], proto TCP (6), length 40)
    192.168.187.6.49177 > 192.168.185.5.8080: Flags [.], cksum 0x89b5 (correct), seq 1, ack 1, win 8195, length 0
00:41:19.751710 00:50:56:a7:76:9a > 00:50:56:a7:f5:d0, ethertype IPv4 (0x0800), length 131: (tos 0x0, ttl 127, id 28704, offset 0, flags [DF], proto TCP (6), length 117)
    192.168.187.6.49177 > 192.168.185.5.8080: Flags [P.], cksum 0x6fb7 (incorrect -> 0xf748), seq 1:78, ack 1, win 8195, length 77: HTTP, length: 77
	GET / HTTP/1.1
	Host: 10.111.66.168
	User-Agent: curl/7.55.1
	Accept: */*
	
00:41:19.772306 00:50:56:a7:76:9a > 00:50:56:a7:f5:d0, ethertype IPv4 (0x0800), length 131: (tos 0x0, ttl 127, id 28705, offset 0, flags [DF], proto TCP (6), length 117)
    192.168.187.6.49177 > 192.168.185.5.8080: Flags [P.], cksum 0x6fb7 (incorrect -> 0xf748), seq 1:78, ack 1, win 8195, length 77: HTTP, length: 77
	GET / HTTP/1.1
	Host: 10.111.66.168
	User-Agent: curl/7.55.1
	Accept: */*
	
00:41:19.822508 00:50:56:a7:76:9a > 00:50:56:a7:f5:d0, ethertype IPv4 (0x0800), length 131: (tos 0x0, ttl 127, id 28706, offset 0, flags [DF], proto TCP (6), length 117)
    192.168.187.6.49177 > 192.168.185.5.8080: Flags [P.], cksum 0x6fb7 (incorrect -> 0xf748), seq 1:78, ack 1, win 8195, length 77: HTTP, length: 77
	GET / HTTP/1.1
	Host: 10.111.66.168
	User-Agent: curl/7.55.1
	Accept: */*
    .......
	
00:41:34.857735 00:50:56:a7:f5:d0 > 00:50:56:a7:76:9a, ethertype IPv4 (0x0800), length 54: (tos 0x0, ttl 63, id 19733, offset 0, flags [DF], proto TCP (6), length 40)
    192.168.185.5.8080 > 192.168.187.6.49177: Flags [.], cksum 0xa7be (correct), seq 0, ack 1, win 507, length 0
00:41:34.859101 00:50:56:a7:76:9a > 00:50:56:a7:f5:d0, ethertype IPv4 (0x0800), length 60: (tos 0x0, ttl 127, id 28714, offset 0, flags [DF], proto TCP (6), length 40)
    192.168.187.6.49177 > 192.168.185.5.8080: Flags [.], cksum 0x01d7 (incorrect -> 0x8968), seq 78, ack 1, win 8195, length 0
00:41:38.698537 00:50:56:a7:76:9a > 00:50:56:a7:f5:d0, ethertype IPv4 (0x0800), length 60: (tos 0x0, ttl 127, id 28715, offset 0, flags [DF], proto TCP (6), length 40)
    192.168.187.6.49177 > 192.168.185.5.8080: Flags [R.], cksum 0x21d6 (incorrect -> 0xa967), seq 78, ack 1, win 0, length 0
00:41:49.961695 00:50:56:a7:f5:d0 > 00:50:56:a7:76:9a, ethertype IPv4 (0x0800), length 54: (tos 0x0, ttl 63, id 19734, offset 0, flags [DF], proto TCP (6), length 40)
    192.168.185.5.8080 > 192.168.187.6.49177: Flags [.], cksum 0xa7be (correct), seq 0, ack 1, win 507, length 0
00:41:49.963391 00:50:56:a7:76:9a > 00:50:56:a7:f5:d0, ethertype IPv4 (0x0800), length 60: (tos 0x0, ttl 127, id 28716, offset 0, flags [DF], proto TCP (6), length 40)
    192.168.187.6.49177 > 192.168.185.5.8080: Flags [R], cksum 0x80cc (correct), seq 3633108089, win 0, length 0
^C
18 packets captured
19 packets received by filter
0 packets dropped by kernel

```

On antrea-gw0:
```
root@a-ms-1000-1:/home/ubuntu/noencap# tcpdump -i antrea-gw0 -ne host 192.168.187.6 -vvv
tcpdump: listening on antrea-gw0, link-type EN10MB (Ethernet), capture size 262144 bytes

00:41:19.749495 9a:7f:7b:69:26:9b > 6a:d2:05:b2:a0:b4, ethertype IPv4 (0x0800), length 66: (tos 0x2,ECT(0), ttl 126, id 28702, offset 0, flags [DF], proto TCP (6), length 52)
    192.168.187.6.49177 > 192.168.185.5.8080: Flags [SEW], cksum 0xf152 (correct), seq 3633108088, win 64240, options [mss 1460,nop,wscale 8,nop,nop,sackOK], length 0
00:41:19.750160 6a:d2:05:b2:a0:b4 > 9a:7f:7b:69:26:9b, ethertype IPv4 (0x0800), length 66: (tos 0x0, ttl 64, id 0, offset 0, flags [DF], proto TCP (6), length 52)
    192.168.185.5.8080 > 192.168.187.6.49177: Flags [S.], cksum 0x6bbb (correct), seq 2416833535, ack 3633108089, win 64860, options [mss 1410,nop,nop,sackOK,nop,wscale 7], length 0
00:41:19.751665 9a:7f:7b:69:26:9b > 6a:d2:05:b2:a0:b4, ethertype IPv4 (0x0800), length 54: (tos 0x0, ttl 126, id 28703, offset 0, flags [DF], proto TCP (6), length 40)
    192.168.187.6.49177 > 192.168.185.5.8080: Flags [.], cksum 0x89b5 (correct), seq 1, ack 1, win 8195, length 0
00:41:34.857707 6a:d2:05:b2:a0:b4 > 9a:7f:7b:69:26:9b, ethertype IPv4 (0x0800), length 54: (tos 0x0, ttl 64, id 19733, offset 0, flags [DF], proto TCP (6), length 40)
    192.168.185.5.8080 > 192.168.187.6.49177: Flags [.], cksum 0xa7be (correct), seq 0, ack 1, win 507, length 0
00:41:49.961666 6a:d2:05:b2:a0:b4 > 9a:7f:7b:69:26:9b, ethertype IPv4 (0x0800), length 54: (tos 0x0, ttl 64, id 19734, offset 0, flags [DF], proto TCP (6), length 40)
    192.168.185.5.8080 > 192.168.187.6.49177: Flags [.], cksum 0xa7be (correct), seq 0, ack 1, win 507, length 0
00:41:49.963413 9a:7f:7b:69:26:9b > 6a:d2:05:b2:a0:b4, ethertype IPv4 (0x0800), length 54: (tos 0x0, ttl 126, id 28716, offset 0, flags [DF], proto TCP (6), length 40)
    192.168.187.6.49177 > 192.168.185.5.8080: Flags [R], cksum 0x80cc (correct), seq 3633108089, win 0, length 0
```

On container:
```
root@a-ms-1000-1:/home/ubuntu/noencap# tcpdump -i eth0 -ne host 192.168.187.6 -vvv
tcpdump: listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
00:41:19.750016 9a:7f:7b:69:26:9b > 6a:d2:05:b2:a0:b4, ethertype IPv4 (0x0800), length 66: (tos 0x2,ECT(0), ttl 126, id 28702, offset 0, flags [DF], proto TCP (6), length 52)
    192.168.187.6.49177 > 192.168.185.5.8080: Flags [SEW], cksum 0xf152 (correct), seq 3633108088, win 64240, options [mss 1460,nop,wscale 8,nop,nop,sackOK], length 0
00:41:19.750059 6a:d2:05:b2:a0:b4 > 9a:7f:7b:69:26:9b, ethertype IPv4 (0x0800), length 66: (tos 0x0, ttl 64, id 0, offset 0, flags [DF], proto TCP (6), length 52)
    192.168.185.5.8080 > 192.168.187.6.49177: Flags [S.], cksum 0xf583 (incorrect -> 0x6bbb), seq 2416833535, ack 3633108089, win 64860, options [mss 1410,nop,nop,sackOK,nop,wscale 7], length 0
00:41:19.751798 9a:7f:7b:69:26:9b > 6a:d2:05:b2:a0:b4, ethertype IPv4 (0x0800), length 54: (tos 0x0, ttl 126, id 28703, offset 0, flags [DF], proto TCP (6), length 40)
    192.168.187.6.49177 > 192.168.185.5.8080: Flags [.], cksum 0x89b5 (correct), seq 1, ack 1, win 8195, length 0
00:41:34.857327 6a:d2:05:b2:a0:b4 > 9a:7f:7b:69:26:9b, ethertype IPv4 (0x0800), length 54: (tos 0x0, ttl 64, id 19733, offset 0, flags [DF], proto TCP (6), length 40)
    192.168.185.5.8080 > 192.168.187.6.49177: Flags [.], cksum 0xf577 (incorrect -> 0xa7be), seq 0, ack 1, win 507, length 0
00:41:49.961316 6a:d2:05:b2:a0:b4 > 9a:7f:7b:69:26:9b, ethertype IPv4 (0x0800), length 54: (tos 0x0, ttl 64, id 19734, offset 0, flags [DF], proto TCP (6), length 40)
    192.168.185.5.8080 > 192.168.187.6.49177: Flags [.], cksum 0xf577 (incorrect -> 0xa7be), seq 0, ack 1, win 507, length 0
00:41:49.963612 9a:7f:7b:69:26:9b > 6a:d2:05:b2:a0:b4, ethertype IPv4 (0x0800), length 54: (tos 0x0, ttl 126, id 28716, offset 0, flags [DF], proto TCP (6), length 40)
    192.168.187.6.49177 > 192.168.185.5.8080: Flags [R], cksum 0x80cc (correct), seq 3633108089, win 0, length 0
```