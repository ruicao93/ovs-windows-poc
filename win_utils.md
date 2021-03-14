
## Setup netadapter

### Enable/Disable netadapter

Enable-NetAdapter -InterfaceAlias gw0

### Add IP Address

New-NetIPAddress -InterfaceAlias gw0 -IPAddress 192.168.187.1 -PrefixLength 24

### Set MAC address

``` powershell
Set-NetAdapterAdvancedProperty -Name br-ext -RegistryKeyword NetworkAddress -RegistryValue 005056A7769A
$GwMac = $(Get-NetAdapter gw0).MacAddress
$GwMac = $GwMac -replace "-",":"
# Take effect after enable interface
```
### Enable forwarding

Set-NetIPInterface -InterfaceAlias gw0 -Forwarding Enabled
Get-NetIPInterface  | Select-Object -Property InterfaceAlias,Forwarding

###  Disable ICMP redirect

``` powershell
Set-NetIPv4Protocol -IcmpRedirects disabled
```

### Show interface parameters
```
netsh interface ipv4 show interface antrea-gw0
```


## Create Docker container and attach it to OVS bridge

Import-Module Helper.psm1
New-Container -NetworkName antrea-hnsnetwork -OVSBridge br-int -ContainerName test -ContainerImage "caorui/hello-antrea:latest" -ContainerCommand "python /server.py" -IPAddress 192.168.187.2 -Gateway 192.168.187.1 -OFPortRequest $PodPort

## Add route

New-NetRoute -InterfaceAlias gw0 -DestinationPrefix 192.168.187.0/24 -NextHop 192.168.187.1

route add 192.168.184.0 mask 255.255.255.0 10.176.25.49
> When the if parameter is omitted, the interface is determined from the gateway address.

## HNSNetwork && VMSwitch

### Create HNSNetwork

New-HNSNetwork -Type Transparent -Name antrea-hnsnetwork -AddressPrefix "192.168.187.0/24" -Gateway 192.168.187.1 -AdapterName "Ethernet0 2"

### Remove management interfface

Get-VMSwitch -Name antrea-hnsnetwork  | Set-VMSwitch -AllowManagementOS $false

### Enable VMSwitch extension

Get-VMSwitch -SwitchType External | Enable-VMSwitchExtension "Open vSwitch Extension"

### Get Switch extension
``` powershell
Get-VMSystemSwitchExtension -Name "Open vSwitch Extension"

Id            : 583CC151-73EC-4A6A-8B47-578297AD7623                                                                                                                                                                       
Name          : Open vSwitch Extension                                                                                                                                                                                     
Vendor        : The Linux Foundation (R)                                                                                                                                                                                   
Version       : 2.13.1.38433                                                                                                                                                                            
ExtensionType : Forwarding                                                                                                                                                                                                 
CimSession    : CimSession: .                                                                                                                                                                                              
ComputerName  : A-MS-2000-WIN-0                                                                                                                                                                                            
IsDeleted     : False
```


## Powershell utils

### Select object property

Get-NetIPInterface  | Select-Object -Property InterfaceAlias,Forwarding

### Filter object by property

Get-HnsEndpoint | Where-Object  { ($_.Name -eq "winpy-64dbb5") } 

## Match string

``` powershell
$str="1234"
$str.Contains("1") # return matched index
```

## Replace file content

``` powershell
((Get-Content -Path $Path -Raw ) -replace "$Match","$Substitute") | Set-Content -Path $Path
```
## Get/Set Checksum offload

- Get-NetAdapterChecksumOffload
- Disable-NetAdapterChecksumOffload -Name br-int  -TcpIPv4
- Set-NetAdapterChecksumOffload -Name "MyAdapter" -IpIPv4Enabled RxTxEnabled -TcpIpv4Enabled RxTxEnabled -UdpIpv4Enabled RxTxEnabled
- Set-NetAdapterChecksumOffload -Name antrea-gw0 -IpIPv4Enabled Disabled

``` powershell
PS C:\cygwin\home\Administrator> get-NetAdapterChecksumOffload                                                                                                          
                                                                                                                                                                        
Name                           IpIPv4Enabled   TcpIPv4Enabled  TcpIPv6Enabled  UdpIPv4Enabled  UdpIPv6Enabled                                                           
----                           -------------   --------------  --------------  --------------  --------------                                                           
vEthernet (KubeProxyInterna... RxTxEnabled     RxTxEnabled     RxTxEnabled     RxTxEnabled     RxTxEnabled                                                              
antrea-gw0                     RxTxEnabled     Disabled        RxTxEnabled     RxTxEnabled     RxTxEnabled                                                              
br-int                         RxTxEnabled     Disabled        RxTxEnabled     RxTxEnabled     RxTxEnabled                                                              
vEthernet (winpy-7b-923cf6)    RxTxEnabled     RxTxEnabled     RxTxEnabled     RxTxEnabled     RxTxEnabled                                                              
vEthernet (HNS Internal NIC)   RxTxEnabled     RxTxEnabled     RxTxEnabled     RxTxEnabled     RxTxEnabled                                                              
Ethernet0                      RxTxEnabled     Disabled        RxTxEnabled     RxTxEnabled     RxTxEnabled 
```

## Install Windows updates

<https://docs.microsoft.com/en-us/windows-server/administration/server-core/server-core-servicing>

```
Wuauclt /detectnow

Restart-computer 
```

## Get-AuthenticodeSignature

``` powershell
PS > Get-AuthenticodeSignature .\OVSExt.sys


    目录: D:\bugs


SignerCertificate                         Status                                 Path
-----------------                         ------                                 ----
6C83CD9531F7BC98D288E596341C06326B94B21B  UnknownError                           OVSExt.sys
```

<https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/get-authenticodesignature?view=powershell-7.1>

<https://docs.microsoft.com/en-us/dotnet/api/system.management.automation.signaturestatus?view=powershellsdk-7.0.0>

## Windows TCP statistics

``` powershell
netstat -n -s -p tcp
```

