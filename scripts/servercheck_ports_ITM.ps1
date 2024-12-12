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
        $target_IP,
        [int]$target_port
    )
    $TCPtimeout = 100
    $tcpobject = New-Object System.Net.Sockets.TcpClient
    try {
        $connect = $tcpobject.BeginConnect($target_IP, $target_port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne($TCPtimeout, $false)
        if (!$wait) {
            $tcpobject.Close()
            $result = "timeout - closed"
        } else {
            $tcpobject.EndConnect($connect) | Out-Null
            $tcpobject.Close()
            $result = "success - open"
        }
    } catch {
        $tcpobject.Close()
        Write-Host "An error occurred: $($_.Exception.Message)"
        $errorDetails = $_
        if ($errorDetails) {
            Write-Host "Error details: $($errorDetails.Exception)"
        }
        $result = "error - closed ($result)"
    }

    return $result
}
$target_tool='ITM'
$target_port=3660
$from_hostname = $env:COMPUTERNAME.ToLower()
$NetworkAdapterConfiguration= Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPENABLED=TRUE
[string]$from_IPAddress = $NetworkAdapterConfiguration.IPAddress[0]
[string]$from_IPSubnet = $NetworkAdapterConfiguration.IPSubnet
[string]$from_IPGateway = $NetworkAdapterConfiguration.DefaultIPGateway
$scriptdir = "C:/Windows/Temp/servercheck/"
$newlist = @()
$csvObjects = Import-Csv -Path "${scriptdir}hub_rtems_2024.csv" -Delimiter ';'
$csvObjects | foreach-object {
    $target_Ci = $_.rtemsCi
	$target_Ci = $target_Ci.Trim()
	$target_Ci = $target_Ci.ToLower()
	$target_IP = $_.rtemsIP
	$rtemsPairs = $_.rtemsPairs
	$rtemsEnvir = $_.rtemsEnvir
	$rtemsShore = $_.rtemsShore
    if ( $target_Ci -imatch "^kmdlnxrls.*" ) {
        $now = (get-date -format "yyyy-MM-dd HH:mm:ss.fff")
        $result = get-IPPort -target_IP $target_IP -target_port $target_port
        $new = @()
        $new = New-Object System.Object
        $new | add-member -membertype noteproperty -name from_hostname          -value $from_hostname -force
        $new | add-member -membertype noteproperty -name from_IPAddress         -value $from_IPAddress -force
        $new | add-member -membertype noteproperty -name from_IPSubnet          -value $from_IPSubnet -force
        $new | add-member -membertype noteproperty -name from_IPGateway         -value $from_IPGateway -force
        $new | add-member -membertype noteproperty -name target_port            -value $target_port -force
        $new | add-member -membertype noteproperty -name target_Ci              -value $target_Ci -force
        $new | add-member -membertype noteproperty -name target_IP              -value $target_IP -force
        $new | add-member -membertype noteproperty -name target_tool            -value $target_tool -force
        $new | add-member -membertype noteproperty -name result                 -value $result -force
        $new | add-member -membertype noteproperty -name ITM_envir              -value $rtemsEnvir -force
        $new | add-member -membertype noteproperty -name ITM_near_onshore       -value $rtemsShore -force
        $new | add-member -membertype noteproperty -name ITM_pairs              -value $rtemsPairs -force
        $new | add-member -membertype noteproperty -name test_Time              -value $now -force
        $newlist += $new
    }
}
$scriptdir = "C:/Windows/Temp/servercheck/"
$portFilename = "${scriptdir}/servercheck_aeven_portitm.csv"
$newlist | Format-Table * | Out-string -Width 300
if ([bool](Test-Path $scriptdir)) {
    $newlist | Export-Csv $portFilename -NoTypeInformation -Encoding UTF8 -Delimiter ';'
}
exit($exitcode)