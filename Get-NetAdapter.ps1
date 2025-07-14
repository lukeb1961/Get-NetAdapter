<#
        .NAME
         Get-NetAdapter

        .SYNOPSIS
        Extend the Get-NetAdapter cmdlet and add Linux/Mac/FreeBSD support

        .DESCRIPTION
        Gets the basic network adapter properties plus IP address info
         on Linux from "ip addr show" and also looks for ethtool output
         on FreeBSD, all from "ifconfig"
         on Windows via Get_NetAdapter and Get-NetIPaddress

        .INPUTS
        None.

        .OUTPUTS
        a custom object

        .EXAMPLE
        PS> $AdapterInfo=Get-NetAdapter

#>

function Get-NetAdapterLinux {
       
    $adapters = @()
    $pattern1 ='(?<IFINDEX>^\d+):\s(?<NAME>.+):\s\<.+(,?)(?<UPSTATE>UP)(,?)(.*?)>.+mtu\s(?<MTUSIZE>\d+).+\sstate\s'
    $pattern2 = '(?<MEDIATYPE>^[\w\/]+)\s(?<MACADDRESS>[\d\w:]+)\sbrd'
    $pattern3 = 'inet\s(?<INET4>[\d.]+)\/\d+\s'
    $pattern4 = 'inet6\s(?<INET6>[\d:\w]+)\/\d+\s'
       
    $interfaces = (Get-ChildItem /sys/class/net).name

    foreach ($interface in $interfaces) {
        $adapterInfo = (ip addr show $interface)
        $Inet4 = $Inet6 = @()
        for ($i = 0; $i -lt $adapterInfo.length; $i++) {
            $line = $adapterInfo[$i].tostring().trim()

            if ($line -match $pattern1) {
                $ifindex     = $MATCHES.IFINDEX
                $adapterName = $MATCHES.NAME
                $status      = $MATCHES.UPSTATE
                $MTUsize     = $MATCHES.MTUSIZE
            }

            if ($line -match $pattern2) {
                $mediaType  = $MATCHES.MEDIATYPE
                $macAddress = $MATCHES.MACADDRESS
                $macAddress = $macAddress.replace(":", "-")
                if ($mediaType -eq "link/ether") {
                    $mediaType = $mediaType.replace("link/ether","802.3")
                }
                elseif ($mediaType -eq "link/ieee802.11") {
                    $mediaType = $mediaType.replace("link/ieee802.11","Native 802.11")
                }
                elseif ($mediaType -eq "link/loopback") {
                    $mediaType = $mediaType.replace("link/loopback","802.3")
                }
            }

            if ($line -match $pattern3) { $Inet4 += $MATCHES.INET4 }
            if ($line -match $pattern4) { $Inet6 += $MATCHES.INET6 }
        }
        if (Get-Command ethtool -ErrorAction SilentlyContinue) {
            $pattern11 = '^driver:\s(?<DRIVER>\w+)$'
            $pattern12 = '^version:\s(?<VERSION>.+)$'
            if ($adapterName -NE 'lo') {
                $info = (ethtool -i $adapterName)
                if ( $info[0] -match $pattern11 ) { $driver        = $MATCHES.DRIVER }
                if ( $info[1] -match $pattern12 ) { $driverVersion = $MATCHES.VERSION }
            }
        }
        $pathName = Join-Path (Join-Path "/sys/class/net" $adapterName) "speed"
        if (Test-Path $pathName) { $Speed= Get-Content -Path $pathName -EA Silentlycontinue }

        $adapter = New-Object -Type PSObject -Property ([ordered] @{
                Name          = $adapterName
                ifIndex       = $ifindex
                Status        = $status
                MacAddress    = $macAddress
                MediaType     = $mediaType
                MTUsize       = $MTUsize
                INET4         = $Inet4
                INET6         = $Inet6
                Driver        = $driver
                DriverVersion = $driverVersion
                LinkSpeed     = $Speed
            })

        $adapters += $adapter
    }
    $adapters | sort-object -Property ifIndex
}


function Get-NetAdapterFreeBSD {

    $ifIndex = 0  # do our own
    $adapters = @()
   
    $pattern1 = '(?<NAME>.+):\sflags=\d+\<.+(,?)(?<UPSTATE>UP)(,?)(.*?)>.+mtu\s(?<MTUSIZE>\d+)'
    $pattern2 = 'ether\s(?<MACADDRESS>[\d\w:]+)$'
    $pattern3 = 'media:\s(?<IFDESCR>.+)$'
    $pattern4 = '.+\((?<LINKSPEED>[\d\w-]+)\s'

    $interfaces = (ifconfig -l) -split ' '

    foreach ($interface in $interfaces) {
        $adapterInfo = (ifconfig $interface)
        $ifIndex++
        for ($i = 0; $i -lt $adapterInfo.length; $i++) {
            $line = $adapterInfo[$i].tostring().trim()
            if ($line -match $pattern1) {
                $adapterName = $MATCHES.NAME
                $status      = $MATCHES.UPSTATE
                $MTUsize     = $MATCHES.MTUSIZE
            }
            if ($line -match $pattern2) {
                $macAddress = $MATCHES.MACADDRESS
                $macAddress = $macAddress.replace(":", "-")
            }
            if ($line -match $pattern3) {
              $ifDescr = $MATCHES.IFDESCR
              if ($ifDescr -match $pattern4) {$LinkSpeed = $MATCHES.LINKSPEED}
            }
        }
        $adapter = New-Object -Type PSObject -Property ([ordered] @{
                Name       = $adapterName
                ifIndex    = $ifindex
                Status     = $status
                MacAddress = $macAddress
                MediaType  = $mediaType
                MTUsize    = $MTUsize
                ifDescr    = $ifDescr
                LinkSpeed  = $LinkSpeed
            })
        $adapters += $adapter
    }
    $adapters
}

function Get-NetAdapterMacOS{

    $ifIndex = 0  # do our own
    $adapters = @()
   
    $pattern1 = '(?<NAME>.+):\sflags=\d+\<.+(,?)(?<UPSTATE>UP)(,?)(.*?)>.+mtu\s(?<MTUSIZE>\d+)'
    $pattern2 = 'ether\s(?<MACADDRESS>[\d\w:]+)$'
    $pattern3 = 'media:\s(?<IFDESCR>.+)$'
    $pattern4 = '.+\((?<LINKSPEED>[\d\w-]+)\s'

    $interfaces = (ifconfig -l) -split ' '

    foreach ($interface in $interfaces) {
        $adapterInfo = (ifconfig $interface)
        $ifIndex++
        for ($i = 0; $i -lt $adapterInfo.length; $i++) {
            $line = $adapterInfo[$i].tostring().trim()
            if ($line -match $pattern1) {
                $adapterName = $MATCHES.NAME
                $status      = $MATCHES.UPSTATE
                $MTUsize     = $MATCHES.MTUSIZE
            }
            if ($line -match $pattern2) {
                $macAddress = $MATCHES.MACADDRESS
                $macAddress = $macAddress.replace(":", "-")
            }
            if ($line -match $pattern3) {
              $ifDescr = $MATCHES.IFDESCR
              if ($ifDescr -match $pattern4) {$LinkSpeed = $MATCHES.LINKSPEED}
            }
        }
        $adapter = New-Object -Type PSObject -Property ([ordered] @{
                Name       = $adapterName
                ifIndex    = $ifindex
                Status     = $status
                MacAddress = $macAddress
                MediaType  = $mediaType
                MTUsize    = $MTUsize
                ifDescr    = $ifDescr
                LinkSpeed  = $LinkSpeed
            })
        $adapters += $adapter
    }
    $adapters
}


function Get-NetAdapterWindows {

 $adapterInfo = (Get-NetAdapter)
 foreach ($adapter in $adapterInfo) {
   $NetIPs=Get-NetIPaddress -ifIndex $adapter.ifIndex -EA SilentlyContinue
   $Inet4 = @();$Inet6 = @()
   foreach ($AddrInfo in $NetIPs) {
    if ($AddrInfo.AddressFamily -eq 'IPv6') { $Inet6 += $AddrInfo.IPAddress }
    if ($AddrInfo.AddressFamily -eq 'IPv4') { $Inet4 += $AddrInfo.IPAddress }
   }
   $adapter | Add-Member -MemberType NoteProperty -Name INET4 -Value $Inet4
   $adapter | Add-Member -MemberType NoteProperty -Name INET6 -Value $Inet6
 }
 $adapterInfo | Sort-Object -Property ifIndex
}



function Test-Platform {
    PARAM ([Parameter(Mandatory = $true)][ValidateSet('Windows', 'Linux', 'MacOS', 'FreeBSD')][string]$OS)

    if ($PSversionTable.PSversion.Major -gt 5) {
        $IsLinuxEnv   = (Get-Variable -Name 'IsLinux'   -ErrorAction Ignore) -and $IsLinux
        $IsMacOSEnv   = (Get-Variable -Name 'IsMacOS'   -ErrorAction Ignore) -and $IsMacOS
        $IsWindowsenv = (Get-Variable -Name 'IsWindows' -ErrorAction Ignore) -and $IsWindows
        $IsFreeBSDEnv = (Get-Variable -Name 'IsFreeBSD' -ErrorAction Ignore) -and $IsFreeBSD
        if (-NOT ($IsLinuxEnv -or $IsMacOSEnv -or $IsWindowsenv -or $IsFreeBSDEnv)) {
         if (Get-Command uname) {if ((uname) -eq 'FreeBSD') {$IsFreeBSDEnv = $true}}
        }
    }
    else { $IsWindowsenv=$True;$IsLinuxEnv=$false;$IsMacOSEnv=$false;$IsFreeBSDEnv=$false }

    switch ($OS) {
        'Windows' { if ($IsWindowsEnv) { return $true } }
        'Linux'   { if ($IsLinuxEnv)   { return $true } }
        'MacOS'   { if ($IsMacOSEnv)   { return $true } }
        'FreeBSD' { if ($IsFreeBSDEnv) { return $true } }
    }

    return $false
}


if (Test-Platform 'Windows') { Get-NetAdapterWindows }
if (Test-Platform 'Linux')   { Get-NetAdapterLinux   }
if (Test-Platform 'FreeBSD') { Get-NetAdapterFreeBSD }
if (Test-Platform 'MacOS')   { Get-NetAdapterMacOS   }
