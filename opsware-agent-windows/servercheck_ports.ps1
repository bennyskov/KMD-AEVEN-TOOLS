Remove-Variable * -ErrorAction SilentlyContinue
<# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
#
#                                                                             dddddddd
#   kkkkkkkk                                                                  d::::::d                                        lllllll
#   k::::::k                                                                  d::::::d                                        l:::::l
#   k::::::k                                                                  d::::::d                                        l:::::l
#   k::::::k                                                                  d:::::d                                         l:::::l
#   k:::::k    kkkkkkkyyyyyyy           yyyyyyynnnn  nnnnnnnn        ddddddddd:::::drrrrr   rrrrrrrrryyyyyyy           yyyyyyyl::::l
#   k:::::k   k:::::k  y:::::y         y:::::y n:::nn::::::::nn    dd::::::::::::::dr::::rrr:::::::::ry:::::y         y:::::y l::::l
#   k:::::k  k:::::k    y:::::y       y:::::y  n::::::::::::::nn  d::::::::::::::::dr:::::::::::::::::ry:::::y       y:::::y  l::::l
#   k:::::k k:::::k      y:::::y     y:::::y   nn:::::::::::::::nd:::::::ddddd:::::drr::::::rrrrr::::::ry:::::y     y:::::y   l::::l
#   k::::::k:::::k        y:::::y   y:::::y      n:::::nnnn:::::nd::::::d    d:::::d r:::::r     r:::::r y:::::y   y:::::y    l::::l
#   k:::::::::::k          y:::::y y:::::y       n::::n    n::::nd:::::d     d:::::d r:::::r     rrrrrrr  y:::::y y:::::y     l::::l
#   k:::::::::::k           y:::::y:::::y        n::::n    n::::nd:::::d     d:::::d r:::::r               y:::::y:::::y      l::::l
#   k::::::k:::::k           y:::::::::y         n::::n    n::::nd:::::d     d:::::d r:::::r                y:::::::::y       l::::l
#   k::::::k k:::::k           y:::::::y          n::::n    n::::nd::::::ddddd::::::ddr:::::r                 y:::::::y       l::::::l
#   k::::::k  k:::::k           y:::::y           n::::n    n::::n d:::::::::::::::::dr:::::r                  y:::::y        l::::::l
#   k::::::k   k:::::k         y:::::y            n::::n    n::::n  d:::::::::ddd::::dr:::::r                 y:::::y         l::::::l
#   kkkkkkkk    kkkkkkk       y:::::y             nnnnnn    nnnnnn   ddddddddd   dddddrrrrrrr                y:::::y          llllllll
#                            y:::::y                                                                        y:::::y
#                           y:::::y                                                                        y:::::y
#                          y:::::y                                                                        y:::::y
#                         y:::::y                                                                        y:::::y
#                        yyyyyyy                                                                        yyyyyyy
#
#
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# servercheck_ports.ps1  :   collect server information data
#
# 2023-04-30  Initial release ( Benny.Skov@kyndryl.dk )
#
#>
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# test ports
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function get-IPPort {
    param (
        [string]$toolName,
        [string]$target,
        [int]$port
    )
    $now = (get-date -format "yyyy-MM-dd HH:mm:ss.fff")
    $TCPtimeout = 100
    $tcpobject = New-Object System.Net.Sockets.TcpClient
    try {
        $connect = $tcpobject.BeginConnect($target, $port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne($TCPtimeout, $false)
        if (!$wait) {
            $tcpobject.Close()
            $message = "timeout - closed"
        } else {
            $tcpobject.EndConnect($connect) | Out-Null
            $tcpobject.Close()
            $message = "success - open"
        }
    } catch {
        $tcpobject.Close()
        Write-Host "An error occurred: $($_.Exception.Message)"
        $errorDetails = $_
        if ($errorDetails) {
            Write-Host "Error details: $($errorDetails.Exception)"
        }
        $message = "error - closed ($message)"
    }
    [string]$target = $target
    [string]$port = $port
    [string]$message = $message
    [string]$hostname = $env:COMPUTERNAME.ToLower()

    $NetworkAdapterConfiguration= Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPENABLED=TRUE
    [string]$IPAddress = $NetworkAdapterConfiguration.IPAddress[0]
    [string]$IPSubnet = $NetworkAdapterConfiguration.IPSubnet
    [string]$IPGateway = $NetworkAdapterConfiguration.DefaultIPGateway
    $message   = ( "{0,-23} ; {1,-20}  ; {2,-20} ; {3,-20} ; {4,-20} ; {5,-20} ; {6,-20} ; {7,-20}; {8,23}" -f $hostname, $IPAddress, $IPSubnet, $IPGateway, $toolName, $target, $port, $message, $now)
    return $message
}
$messageAarray = @()
# MSA             : 84.255.75.1:3001,84.255.75.2:3001
# BTA DFK/KRFO    : 10.233.70.1:3001,10.233.70.2:3001
# BTA Eboks       : 10.226.80.1:3001,10.226.80.2:3001
# BTA LMST        : 10.233.78.1:3001,10.233.78.2:3001
$message   = ( "{0,-23} ; {1,-20}  ; {2,-20} ; {3,-20} ; {4,-20} ; {5,-20} ; {6,-20} ; {7,-20}; {8,-23}" -f "hostname", "IPAddress", "IPSubnet", "IPGateway", "toolName", "target", "port", "message", "test Time")
$messageAarray += $message

$toolName  = 'Opsware-MSA-1'; $target = '84.255.75.1'; $port = 3001
$message   = get-IPPort -toolName $toolName target $target -target $target -port $port
$messageAarray += $message

$toolName   = 'Opsware-MSA-2'; $target = '84.255.75.2'; $port = 3001
$message    = get-IPPort -toolName $toolName target $target -target $target -port $port
$messageAarray += $message

$toolName   = 'Opsware-BTA-DFK-1'; $target = '10.233.70.1'; $port = 3001
$message    = get-IPPort -toolName $toolName target $target -target $target -port $port
$messageAarray += $message

$toolName   = 'Opsware-BTA-DFK-2'; $target = '10.233.70.2'; $port = 3001
$message    = get-IPPort -toolName $toolName target $target -target $target -port $port
$messageAarray += $message

$toolName   = 'Opsware-BTA-Eboks-1'; $target = '10.226.80.1'; $port = 3001
$message    = get-IPPort -toolName $toolName target $target -target $target -port $port
$messageAarray += $message

$toolName   = 'Opsware-BTA-Eboks-2'; $target = '10.226.80.2'; $port = 3001
$message    = get-IPPort -toolName $toolName target $target -target $target -port $port
$messageAarray += $message

$toolName   = 'Opsware-BTA-LMST-1'; $target = '10.233.78.1'; $port = 3001
$message    = get-IPPort -toolName $toolName target $target -target $target -port $port
$messageAarray += $message

$toolName   = 'Opsware-BTA-LMST-2'; $target = '10.233.78.2'; $port = 3001
$message    = get-IPPort -toolName $toolName target $target -target $target -port $port
$messageAarray += $message

$toolName   = 'Opsware-3'; $target = '84.255.75.1'; $port = 1002
$message    = get-IPPort -toolName $toolName target $target -target $target -port $port
$messageAarray += $message

$toolName   = 'Opsware-4'; $target = '84.255.75.2'; $port = 1002
$message    = get-IPPort -toolName $toolName target $target -target $target -port $port
$messageAarray += $message

$toolName   = 'OMI-1'; $target = '84.255.75.1'; $port = 383
$message    = get-IPPort -toolName $toolName target $target -target $target -port $port
$messageAarray += $message

$toolName   = 'OMI-2'; $target = '84.255.75.2'; $port = 383
$message    = get-IPPort -toolName $toolName target $target -target $target -port $port
$messageAarray += $message

$toolName   = 'OMI-3'; $target = '84.255.75.1'; $port = 3128
$message    = get-IPPort -toolName $toolName target $target -target $target -port $port
$messageAarray += $message

$toolName   = 'OMI-4'; $target = '84.255.75.2'; $port = 3128
$message    = get-IPPort -toolName $toolName target $target -target $target -port $port
$messageAarray += $message

$toolName   = 'UCMDB-1'; $target = '84.255.75.4'; $port = 2738
$message    = get-IPPort -toolName $toolName target $target -target $target -port $port
$messageAarray += $message

$toolName   = 'UCMDB-2'; $target = '84.255.75.5'; $port = 2738
$message    = get-IPPort -toolName $toolName target $target -target $target -port $port
$messageAarray += $message

$toolName   = 'ansible-1'; $target = '84.255.94.31'; $port = 8081
$message    = get-IPPort -toolName $toolName target $target -target $target -port $port
$messageAarray += $message

$toolName   = 'ansible-2'; $target = '84.255.94.33'; $port = 8081
$message    = get-IPPort -toolName $toolName target $target -target $target -port $port
$messageAarray += $message

$toolName   = 'ansible-3'; $target = 'localhost'; $port = 5985
$message    = get-IPPort -toolName $toolName target $target -target $target -port $port
$messageAarray += $message

$messageAarray
$scriptdir                  = "C:/Windows/Temp/servercheck/"
$portFilename               = "${scriptdir}/servercheck_aeven_portcheck.csv"
if ([bool](Test-Path $scriptdir)) {
    $messageAarray | Out-File -FilePath $portFilename -Encoding utf8 -ErrorAction SilentlyContinue
}
exit($exitcode)