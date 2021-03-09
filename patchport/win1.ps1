function Get-HNSNetworkByName() {
    Param(
        [parameter(Mandatory = $true)] [string] $NetworkName
    )
    $Network = Get-HnsNetwork | Where-Object { ($_.Name -eq $NetworkName) }
    return $Network
    foreach($Net in $Networks) {
        if ($Net.Name -eq $NetworkName) {
            return $Net
        }
    }
    return $null
}

function Get-NetCompartmentByContainerId() {
    Param(
        [parameter(Mandatory = $true)] [string] $ContainerId
    )
    $CompartmentDescription = "\Container_$ContainerId"
    return Get-NetCompartment | Where-Object  { ($_.CompartmentDescription -eq "$CompartmentDescription" ) }
}

function New-Container() {
    Param(
        [parameter(Mandatory = $false)] [string] $NetworkName,
        [parameter(Mandatory = $false)] [string] $NetworkId,
        [parameter(Mandatory = $true)] [string] $ContainerName,
        [parameter(Mandatory = $true)] [string] $ContainerImage="caorui/hello-antrea:latest",
        [parameter(Mandatory = $true)] [string] $ContainerCommand,
        [parameter(Mandatory = $true)] [string] $IPAddress,
        [parameter(Mandatory = $true)] [string] $Gateway,
        [parameter(Mandatory = $true)] [string] $OVSBridge
    )
    if ($NetworkName) {
        $Network = Get-HNSNetworkByName -NetworkName $NetworkName
    } else {
        $Network = Get-HNSNetwork -NetworkId $NetworkId
    }
    $ContainerId = docker run -d --name $ContainerName  --network none $ContainerImage python /server.py
    $Endpoint = New-HnsEndpoint -Name $ContainerName  -NetworkId $Network.Id -IPAddress $IPAddress -Gateway $Gateway
    $NetCompartment = Get-NetCompartmentByContainerId -ContainerId $ContainerId
    Attach-HnsEndpoint -EndpointID $Endpoint.Id -ContainerID $ContainerId  -CompartmentID $NetCompartment.CompartmentId
    ovs-vsctl --no-wait add-port $OVSBridge $ContainerName -- set interface $ContainerName type=internal
}

#1. Create HNSNetwork(Transparent)
#192.168.184.0/21
#>> 192.168.184.0/24
#>> 192.168.185.0/24
#>> 192.168.186.0/24
#>> 192.168.187.0/24
# docker network create -d transparent --subnet 172.16.0.0/24 --gateway 127.16.0.1 -o com.docker.network.windowshim.interface="Ethernet0 2" external
New-HNSNetwork -Type Transparent -Name antrea-hnsnetwork -AddressPrefix "192.168.186.0/24" -Gateway 192.168.186.1 -AdapterName "Ethernet0"
#New-HNSNetwork -Type Transparent -Name antrea-hnsnetwork -AddressPrefix "192.168.187.0/24" -Gateway 192.168.187.1 -AdapterName "Ethernet0"
Get-VMSwitch -Name antrea-hnsnetwork  | Set-VMSwitch -AllowManagementOS $false
Get-VMSwitch -SwitchType External | Enable-VMSwitchExtension "Open vSwitch Extension"


#2.  Create br-ext + br-int
ovs-vsctl --no-wait add-br br-ext
ovs-vsctl --no-wait add-br br-int
Set-NetAdapterAdvancedProperty -Name br-ext -RegistryKeyword NetworkAddress -RegistryValue 005056A7769A

#3. Add uplink and gw0
ovs-vsctl add-port br-ext "Ethernet0"
Enable-NetAdapter -InterfaceAlias br-ext

ovs-vsctl.exe add-port br-int gw0 -- set interface gw0 type=internal
Enable-NetAdapter -InterfaceAlias gw0
New-NetIPAddress -InterfaceAlias gw0 -IPAddress 192.168.186.1 -PrefixLength 24
Set-NetIPInterface -InterfaceAlias gw0 -Forwarding Enabled
$PodMac = $(Get-HNSEndpoint | Where-Object {($_.Name -eq "Test")}).MacAddress
$PodMac = $PodMac -replace "-",":"

#4. Link two bridges with patch port
ovs-vsctl.exe add-port br-int patch-ext -- set interface patch-ext type=patch options:peer=patch-int
ovs-vsctl.exe add-port br-ext patch-int -- set interface patch-int type=patch options:peer=patch-ext

#5.Add a docker container and attach it to br-int
New-Container -NetworkName antrea-hnsnetwork -OVSBridge br-int -ContainerName test -ContainerImage "caorui/hello-antrea:latest" -ContainerCommand "python /server.py" -IPAddress 192.168.186.2 -Gateway 192.168.186.1

#6. Test connection: Container --> external
# Default flow:
# - Uplink --> OVS(br-ext) --> br-ext
# - br-ext --> OVS(br-ext) --> uplink
$UplinkPort=1
ovs-ofctl add-flow br-ext "table=0,cookie=0x520,in_port=$UplinkPort,priority=190 actions=output:LOCAL"
ovs-ofctl add-flow br-ext "table=0,cookie=0x520,in_port=LOCAL,priority=190 actions=output:$UplinkPort"
ovs-ofctl add-flow br-ext "table=0,cookie=0x520,in_port=$UplinkPort,priority=200,ip actions=resubmit(,10)"

# Request: Pod --> OVS(br-int) --> gw0 --> br-ext --> OVS(br-ext) --> SNAT --> uplink 
# Reply: Uplink --> OVS(br-ext) --> d-SNAt --> patch-int --> OVS (br-int) --> Pod
$PatchExtPort=1
$GwPort=2
$PodPort=3
$PodMac="00:15:5D:93:6F:9B"

$PatchIntPort=2
$NodeIP="10.176.25.103"
# 0x0ab01967

# new-netroute -InterfaceAlias gw0 -DestinationPrefix 192.168.186.0/24 -NextHop 192.168.186.1

ovs-ofctl add-flow br-int "table=0,cookie=0x520,in_port=$PodPort,priority=190 actions=output:$GwPort"
ovs-ofctl add-flow br-int "table=0,cookie=0x520,in_port=$GwPort,priority=190 actions=output:$PodPort"
ovs-ofctl add-flow br-int "table=0,cookie=0x520,in_port=$GWPort,priority=200,ip actions=mod_dl_src:$GwMac,mod_dl_dst=$PodMac,output:$PodPort"
ovs-ofctl add-flow br-int "table=0,cookie=0x520,in_port=$PatchExtPort,priority=200,ip actions=mod_dl_src:$GwMac,mod_dl_dst=$PodMac,output:$PodPort"

ovs-ofctl add-flow br-ext "table=0,cookie=0x520,in_port=LOCAL,priority=200,ip,nw_src=192.168.186.0/24 actions=resubmit(,10)"
ovs-ofctl add-flow br-ext "table=0,cookie=0x520,in_port=LOCAL,priority=200,ip,nw_dst=192.168.186.0/24 actions=$PatchIntPort"
# CT table
ovs-ofctl add-flow br-ext "table=10,cookie=0x520,priority=200,ip actions=ct(table=11,zone=65520,nat)"
ovs-ofctl add-flow br-ext "table=11,cookie=0x520,priority=200,in_port=LOCAL,ip,nw_src=192.168.186.0/24,ct_state=+new+trk actions=ct(commit,table=20,zone=65520,nat(src=$NodeIP))"
ovs-ofctl add-flow br-ext "table=11,cookie=0x520,priority=190 actions=resubmit(,20)"

# Forward table
# The reply pkts from host to Pod is recieved from br-ext <<<<<<<<<<<(Source selection)
ovs-ofctl add-flow br-ext "table=20,cookie=0x520,priority=200,in_port=$UplinkPort,ip,nw_dst=192.168.186.0/24 actions=$PatchIntPort"
ovs-ofctl add-flow br-ext "table=20,cookie=0x520,in_port=LOCAL,priority=190 actions=output:$UplinkPort"
ovs-ofctl add-flow br-ext "table=20,cookie=0x520,in_port=$UplinkPort,priority=190 actions=output:LOCAL"

#7. Test NXM_NX_PKT_MARK
ovs-ofctl add-flow br-ext "table=20,cookie=0x520,priority=200,in_port=$UplinkPort,ip,nw_src=10.176.26.107,nw_dst=192.168.186.0/24 actions=load:0x1->NXM_NX_PKT_MARK[],output:$PatchIntPort"
ovs-ofctl add-flow br-int "table=0,cookie=0x520,in_port=$PatchExtPort,priority=200,ip,nw_src=10.176.26.107,pkt_mark=0x1/0xffff actions=mod_dl_src:$GwMac,mod_dl_dst=$PodMac,output:$PodPort"

# It NXM_NX_PKT_MARK is persisted cross bridges:
#  cookie=0x520, duration=8.937s, table=20, n_packets=0, n_bytes=0, priority=200,ip,in_port=Ethernet0,nw_src=10.176.26.107,nw_dst=192.168.186.0/24 actions=load:0x1->NXM_NX_PKT_MARK[],output:"patch-int"
#  cookie=0x520, duration=30.932s, table=0, n_packets=8, n_bytes=592, priority=200,pkt_mark=0x1/0xffff,ip,in_port="patch-ext",nw_src=10.176.26.107 actions=mod_dl_src:00:15:5d:19:67:39,mod_dl_dst:00:15:5d:93:6f:9b,output:test 

#8. Add tunnel on br-int
$TunPort=4
ovs-vsctl add-port br-int tun -- set interface tun ofport_request=$TunPort type=geneve options:local_ip=$NodeIP options:remote_ip=flow options:key=flow


#9. Test tunnel
ovs-ofctl add-flow br-int "table=0,cookie=0x520,in_port=$PodPort,priority=200,ip,nw_dst=192.168.187.0/24 actions=load:0x0ab01ace->NXM_NX_TUN_IPV4_DST[],output:$TunPort"
ovs-ofctl add-flow br-int "table=0,cookie=0x520,in_port=$TunPort,priority=200,ip actions=mod_dl_src:$GwMac,mod_dl_dst=$PodMac,output:$PodPort"

