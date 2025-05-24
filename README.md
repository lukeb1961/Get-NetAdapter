Extend the Get-NetAdapter cmdlet and add Linux/Mac/FreeBSD support

Gets the basic network adapter properties plus IP address info
on Linux from "ip addr show" and also looks for ethtool output
on FreeBSD and MacOS, all from "ifconfig"
on Windows via Get_NetAdapter and Get-NetIPaddress
