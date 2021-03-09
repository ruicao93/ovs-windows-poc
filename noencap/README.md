


## How linux handle invalid TCP checksum?

<https://www.cs.unh.edu/cnrg/people/gherrin/linux-net.html>

```
>>> DEVICE_rx() - device dependent, drivers/net/DEVICE.c
  (gets control from interrupt)
  performs status checks to make sure it should be receiving
  calls dev_alloc_skb() to reserve space for packet
  gets packet off of system bus
  calls eth_type_trans() to determine protocol type
  calls netif_rx()
  updates card status
  (returns from interrupt)

inet_recvmsg() - net/ipv4/af_inet.c (764)
  extracts pointer to socket sock
  checks socket to make sure it is accepting
  verifies protocol pointer
  returns sk->prot[tcp/udp]->recvmsg()

ip_rcv() - net/ipv4/ip_input.c (395)
  examines packet for errors:
    invalid length (too short or too long)
    incorrect version (not 4)    
    invalid checksum                        <==========================
  calls __skb_trim() to remove padding
  defrags packet if necessary
  calls ip_route_input() to route packet
  examines and handle IP options
  returns skb->dst->input() [= tcp_rcv,udp_rcv()]
```