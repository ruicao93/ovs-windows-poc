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
        [parameter(Mandatory = $true)] [string] $OVSBridge,
        [parameter(Mandatory = $true)] [string] $OFPortRequest
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
    ovs-vsctl --no-wait add-port $OVSBridge $ContainerName -- set interface $ContainerName type=internal ofport_request=$OFPortRequest
}

function Replace-ContentOfFile() {
    Param(
        [parameter(Mandatory = $false)] [string] $Path,
        [parameter(Mandatory = $false)] [string] $Match,
        [parameter(Mandatory = $false)] [string] $Substitute 
    )
    ((Get-Content -Path $Path -Raw ) -replace "$Match","$Substitute") | Set-Content -Path $Path
}
