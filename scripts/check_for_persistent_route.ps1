Remove-Variable * -ErrorAction SilentlyContinue
<#
# ---------------------------------------------------------------------------------------------------------------------------------------
#
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
# ---------------------------------------------------------------------------------------------------------------------------------------
# Changelog
#
# check_for_persistent_route.ps1  :   check if a persistent route is present on server
#
# 2024-10-15  Initial release ( benny.skov@kyndryl.com )
# -----------------------------------------------------------------------------------------------------------------
#>
# ----------------------------------------------------------------------------------------------------------------------------
# functions
# ----------------------------------------------------------------------------------------------------------------------------
function Test-Persistent {
    # Run the route print command and capture the output
    $routeOutput = route print

    # Convert the output to a string and split it into an array of lines
    $routeLines = $routeOutput -split "`n"

    # Find the index of the "Persistent Routes" section
    $persistentRoutesIndex = $routeLines.IndexOf("Persistent Routes")

    if ($persistentRoutesIndex -ge 0) {
        # Extract the lines after "Persistent Routes"
        $persistentRoutes = $routeLines[$persistentRoutesIndex + 2..$routeLines.Length]

        # Filter out any empty lines
        $persistentRoutes = $persistentRoutes | Where-Object { $_ -ne "" }

        # Output the persistent routes
        $Persistent = $true
    } else {
        $Persistent = $false
        $IsPersistent = "No persistent routes found"
    }

    return $Persistent,$persistentRoutes

}
# Function to check if a reboot is pending
function Test-PendingReboot {
    $rebootPending = $false

    # Check the registry for pending file rename operations
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
    $regValue = "PendingFileRenameOperations"
    if (Test-Path "$regPath\$regValue") {
        $rebootPending = $true
    }

    # Check the registry for pending computer rename
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName"
    $regValue = "ComputerName"
    if ((Get-ItemProperty -Path $regPath).ComputerName -ne (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName").ComputerName) {
        $rebootPending = $true
    }

    # Check the registry for pending Windows Update reboot
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    if (Test-Path $regPath) {
        $rebootPending = $true
    }

    # Check the WMI class for pending reboot (using a different approach)
    $wmiRebootPending = (Get-WmiObject -Class Win32_OperatingSystem).RebootPending | Select-Object -ExpandProperty RebootPending -ErrorAction Stop
    if ( $wmiRebootPending -ne $null ) {
        $rebootPending = $true
    }

    return $rebootPending
}
function Test-IPPort2 {
    param ($target,$port)
        $TCPtimeout = 100
        $tcpobject = new-Object system.Net.Sockets.TcpClient
        $connect = $tcpobject.BeginConnect($target,$port,$null,$null)
        $wait = $connect.AsyncWaitHandle.WaitOne($TCPtimeout,$false)
        If(!$wait) {
            $tcpobject.Close()
            $ReturnArray['rc'] = $False
            $ReturnArray['result'] = "$target ($port) Timeout"
        } Else {
            $error.Clear()
            $tcpobject.EndConnect($connect) | out-Null
            If($error[0]){
                [string]$string = ($error[0].exception).message
                $message = (($string.split(":")[1]).replace('"',"")).TrimStart()
                $failed = $true
            }
            $tcpobject.Close()
            If($failed){
                $ReturnArray['rc'] = $False
                $ReturnArray['result'] = "$target ($port) $message"
            } Else{
                $ReturnArray['rc'] = $true
                $ReturnArray['result'] = "$target ($port)"
            }
        }
        return $ReturnArray
}
# ----------------------------------------------------------------------------------------------------------------------------
# Ping and check ports
# ----------------------------------------------------------------------------------------------------------------------------
$now                = (get-date -format "yyyy-MM-dd HH:mm:ss.fff")
$x64                = (Get-WmiObject -Class Win32_OperatingSystem).OSArchitecture -like '64-bit'
$hostIp             = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPENABLED=TRUE | Select-Object IPAddress |select-object -expandproperty IPAddress | select-object -first 1
[int]$psvers        = $PSVersionTable.PSVersion | select-object -ExpandProperty major
$hostname           = hostname
$hostname           = $hostname.ToLower()
$CPU                = Get-CimInstance -Class Win32_Processor
$CPUInfo            = $CPU.Name
$CPUMaxSpeed        = ($CPU[0].MaxClockSpeed/1000).tostring()
$CPUcount           = (Get-CimInstance -ClassName Win32_Processor | Measure-Object -Property NumberOfCores -Sum).Sum.ToString()
$CPUCores           = (Get-CimInstance -ClassName Win32_Processor | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum.ToString()
$PhysicalMemory     = (Get-CimInstance -class Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).Sum
$TotalAvailMemory   = ([math]::round(($PhysicalMemory / 1GB),2))
$TotalMem = "{0:N2}" -f $TotalAvailMemory
[string]$TotalMem   = $TotalMem
[string]$TotalAvailMemory = $TotalAvailMemory
[string]$PhysicalMemory = $PhysicalMemory
$systemroot         = $env:SystemRoot
$diskspace          = get-WmiObject Win32_Volume -ErrorAction SilentlyContinue | Where-Object { $_.drivetype -eq '3' -and $_.driveletter } | Select-Object driveletter,@{Name='freespace';Expression={[math]::round($_.freespace/1GB, 2)}},@{Name='capacity';Expression={[math]::round($_.capacity/1GB, 2)}}
$diskspace          = $diskspace | ConvertTo-Json -Compress
$OperatingSystem    = Get-CimInstance -ClassName Win32_OperatingSystem
$OperatingSystem    = $OperatingSystem.caption + " " + $OperatingSystem.OSArchitecture + " SP " + $OperatingSystem.ServicePackMajorVersion
$lastBootTime       = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
if (Test-PendingReboot) {
    $PendingReboot  =  "A reboot is pending"
} else {
    $PendingReboot  = "No reboot is pending"
}
$Persistent,$persistentRoutes = Test-Persistent
if ($Persistent) {
    $Persistent  = $persistentRoutes
} else {
    $Persistent  = "No persistent routes found"
}
$ReturnArray        = @{}
$iparray = @(
"84.255.75.1",
"84.255.75.2"
)
$text= "localhost;Persistent;hostIP;port;remoteIP;status;result;testtime;OperatingSystem;x64;psvers;Systemroot;lastBootTime;PendingReboot;diskspace;CPUMaxSpeed;CPUcount;CPUCores;TotalMem;TotalAvailMemory;PhysicalMemory"
$cleanString = $text -replace "`r`n", "" -replace "`n", "" -replace "`r", ""
$cleanString
$iparray | foreach-object {
    $remoteIP= "$_"
    $port = 3001
    $ReturnArray = Test-IPPort2 -target $_ -port $port
    $status = $ReturnArray['rc']
    $result = $ReturnArray['result']
    if ( $status ) {
        $status = "open"
    } else {
        $status = "closed"
    }
    $text= "${hostname};${Persistent};${hostIp};${port};${remoteIP};${status};${result};${now};${OperatingSystem};${x64};${psvers};${Systemroot};${lastBootTime};${PendingReboot};${diskspace};${CPUMaxSpeed};${CPUcount};${CPUCores};${TotalMem};${TotalAvailMemory};${PhysicalMemory}"
    $text
}
