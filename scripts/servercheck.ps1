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
# servercheck.ps1  :   collect server information data
#
# 2023-04-30  Initial release ( Benny.Skov@kyndryl.dk )
#
#>
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# INIT
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function f_log {
   Param ([string]$logMsg, $step)
   $now = (get-date -format "yyyy-MM-dd HH:mm:ss.fff")
   $text = ( "{0,-23} : step {1:d4} : {2,-60} : {3}" -f $now, $step, $logMsg, "" )
   Write-Host -NoNewline $text
}
Function f_logOK {
    Param ([string]$logMsg="OK - success.")
    Write-Host "$logMsg"
}
Function f_logError {
    Param ([string]$logMsg="Error - step failed!")
    Write-Host "$logMsg"
}
$rc = $false; $result=""
$text = "begin -----------------------------------------------------"; $step++; f_log -logMsg $text -step $step;f_logOK
$text = "INIT"; $step++; f_log -logMsg $text -step $step
try {
    $begin                      = (get-date -format "yyyy-MM-dd HH:mm:ss.fff")
    $xml                        = @{}
    $xml['date']                = $begin
    # $scriptdir                  = (Get-Location).Path
    # $scriptdir                 = [System.Text.RegularExpressions.Regex]::Replace($scriptdir,"`\","/")
    # $scriptname                 = ($myinvocation).mycommand.Name
    # if ( [string]::IsNullOrEmpty($scriptdir) ) {
    #     $scriptdir              = "C:/Windows/Temp/servercheck/"
    #     $scriptname             = 'servercheck'
    # } else {
    #     $scriptname             = [System.Text.RegularExpressions.Regex]::Replace($scriptname,"`.ps1","")
    # }
    $scriptdir                  = "C:/Windows/Temp/servercheck/"
    $scriptname                 = 'servercheck'
    # $xml['scriptname']          = $scriptname
    # $xml['xmlFile']             = $scriptdir+$scriptname+".xml"

    $defaultServices            = Import-Csv -Path "$scriptdir/servercheckExclude_services.csv" -Delimiter ';'
    $defaultSoftware            = Import-Csv -Path "$scriptdir/servercheckExclude_software.csv" -Delimiter ';'
    f_logOK
} catch {

    Write-Host "An error occurred: $($_.Exception.Message)"
    $errorDetails = $_
    if ($errorDetails) {
        Write-Host "Error details: $($errorDetails.Exception)"
    }
    f_logError
}
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# functions
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function f_get-software {
    param ($defaultSoftware,$xml)
    $rc = $false; $result=""
    try {

        $X64_software   = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -ne $null } | Select-Object PSChildName, DisplayName, DisplayVersion, Publisher, @{Name='InstallDate';Expression={[datetime]::ParseExact($_.InstallDate, 'yyyyMMdd', $null).ToString('yyyy-MM-dd')}}
        $X32_software   = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -ne $null } | Select-Object PSChildName, DisplayName, DisplayVersion, Publisher, @{Name='InstallDate';Expression={[datetime]::ParseExact($_.InstallDate, 'yyyyMMdd', $null).ToString('yyyy-MM-dd')}}
        $softwareList   = $X64_software + $X32_software
        $uniquesoftware = $softwareList | Group-Object DisplayName | ForEach-Object { $_.Group | Select-Object -First 1 }
        $allSoftwareList= $uniquesoftware | Sort-Object DisplayName | Select-Object DisplayName, DisplayVersion, Publisher, @{Name='InstallDate';Expression={[datetime]::ParseExact($_.InstallDate, 'yyyyMMdd', $null).ToString('yyyy-MM-dd')}}
        $filteredSoftware= foreach ($product in $allSoftwareList) {
            if ($defaultSoftware.DisplayName -inotcontains $product.DisplayName ) {
                $product
            }
        }
        if ( [string]::IsNullOrEmpty($filteredSoftware) ) {
            $rc = $False
            $result = "Error - get-software step failed!"
        } else {
            $rc = $true
            $result = "OK - softwareList is collected."
        }
    } catch {
        Write-Host "An error occurred: $($_.Exception.Message)"
        $errorDetails = $_
        if ($errorDetails) {
            Write-Host "Error details: $($errorDetails.Exception)"
            $result = "Error - get-software step failed!"
        }
        $rc = $false
        $result = "Error - get-software step failed!"
    }
    return $rc, $result, $filteredSoftware, $allSoftwareList
}
function f_get-services {
    param ($defaultServices)
    $rc = $false; $result=""
    try {

        $allServices = Get-Service | Select-Object Name, DisplayName | Sort-Object DisplayName
        $allServicesList = $allServices
        $filteredServices = foreach ($service in $allServices) {
            if ($defaultServices.Name -inotcontains $service.Name ) {
                $service
            }
        }
        if ( [string]::IsNullOrEmpty($filteredServices) ) {
            $rc = $False
            $result = "Error - f_get-services step failed!"
        } else {
            $rc = $true
            $result = "OK - services list is collected."
        }
    } catch {
        Write-Host "An error occurred: $($_.Exception.Message)"
        $errorDetails = $_
        if ($errorDetails) {
            Write-Host "Error details: $($errorDetails.Exception)"
            $result = "Error - f_get-services step failed!"
        }
        $rc = $false
        $result = "Error - f_get-services step failed!"
    }
    return $rc, $result, $filteredServices, $allServicesList
}
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# functions
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function f_get-machineInfo {
    param ($xml)
    $rc = $false; $result=""

    try {
        $hostname                   = $env:COMPUTERNAME.ToLower()
        $xml['hostname']            = $hostname

        $OperatingSystem            = Get-CimInstance -ClassName Win32_OperatingSystem
        $OperatingSystem            = $OperatingSystem.caption + " " + $OperatingSystem.OSArchitecture + " SP " + $OperatingSystem.ServicePackMajorVersion
        $xml['OperatingSystem']     = $OperatingSystem

        $OSname                     = (Get-WmiObject Win32_OperatingSystem).Caption
        $xml['OSname']              = $OSname

        $OSversion                  = (Get-WmiObject Win32_OperatingSystem).version
        $xml['OSname']              = $OSversion

        [string]$OSservicePack      = (Get-WmiObject Win32_OperatingSystem).ServicePackMajorVersion
        $xml['OSservicePack']       = $OSservicePack

        [string]$windir             = $env:WINDIR
        [string]$xml['windir']      = $windir

        $systemroot                 = $env:SystemRoot
        $xml['systemroot']          = $systemroot

        $systemdrive                = $env:SystemDrive
        $xml['systemdrive']         = $systemdrive

        $x64                        = (Get-WmiObject -Class Win32_OperatingSystem).OSArchitecture -like '64-bit'
        $xml['x64']                 = $x64

        $IPaddress                  = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPENABLED=TRUE | Select-Object IPAddress |select-object -expandproperty IPAddress | select-object -first 1
        $xml['IPaddress']           = $IPaddress

        $CPU                        = Get-CimInstance -Class Win32_Processor
        $xml['CPU']                 = $CPU[0].Name
        $xml['CPUCaption']          = $CPU[0].Description
        $xml['CPUManufacturer']     = $CPU[0].Manufacturer
        $xml['CPUspeed']            = ($CPU[0].MaxClockSpeed/1000).tostring()
        $xml['CPUcount']            = ($CPU | Measure-Object -Property NumberOfCores -Sum).Sum.ToString()
        $xml['CPUcores']            = ($CPU | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum.ToString()
        $xml['CPUsockets']          = ($CPU | Select-Object -ExpandProperty SocketDesignation | Measure-Object).Count.ToString()

        [string]$IPaddress          = ([System.Net.DNS]::GetHostAddresses([System.Net.Dns]::GetHostName())|Where-Object {$_.AddressFamily -eq 'InterNetwork'} | select-object IPAddressToString)[0].IPAddressToString
        [string]$MACAddress         = (Get-WmiObject -Class Win32_NetworkAdapterConfiguration | Where-Object { $_.IpAddress -eq $IPaddress }).MACAddress
        $xml['MACAddress']          = $MACAddress

        $PhysicalMemory             = (Get-CimInstance -class Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).Sum
        $TotalAvailMemory           = ([math]::round(($PhysicalMemory / 1GB),2))
        $TotalMem                   = "{0:N2}" -f $TotalAvailMemory
        [string]$TotalMem           = $TotalMem
        [string]$TotalAvailMemory   = $TotalAvailMemory
        [string]$PhysicalMemory     = $PhysicalMemory
        $xml['TotalMem']            = $TotalMem
        $xml['TotalAvailMemory']    = $TotalAvailMemory
        $xml['PhysicalMemory']      = $PhysicalMemory

        $TotalPhysicalMemory        = (Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory
        $TotalPhysicalMemory        = ([math]::round(($TotalPhysicalMemory / 1GB),2))
        $xml['TotalPhysicalMemory'] = "{0:N2}" -f $TotalPhysicalMemory

        $FQDN                       = ([System.Net.Dns]::GetHostEntry([System.Net.Dns]::GetHostName())).HostName
        $xml['FQDN']                = $FQDN

        $Domain                     = (Get-WmiObject Win32_ComputerSystem).Domain
        $xml['Domain']              = $Domain

        $diskspace                  = get-WmiObject Win32_Volume -ErrorAction SilentlyContinue | Where-Object { $_.drivetype -eq '3' -and $_.driveletter } | Select-Object driveletter,@{Name='freespace';Expression={[math]::round($_.freespace/1GB, 2)}},@{Name='capacity';Expression={[math]::round($_.capacity/1GB, 2)}}
        $xml['diskspace']           = $diskspace | ConvertTo-Json -Compress

        $DiskSpaceSum               =0
        $DiskSpaceSum               =Get-WmiObject Win32_Volume -Filter "DriveType='3'" | ForEach-Object {$DiskSpaceSum += [Math]::Round(($_.Capacity / 1GB),0)}
        $xml['DiskSpaceSum']        = $DiskSpaceSum

        $serialnumber               = (Get-WmiObject Win32_BIOS).SerialNumber
        $xml['SerialNumber']        = $SerialNumber

        $biosVersion                = (Get-WmiObject Win32_BIOS).Version
        $xml['biosVersion']         = $biosVersion

        $biosName                   = (Get-WmiObject Win32_BIOS).Name
        $xml['biosName']            = $biosName

        $Manufacturer               = (Get-WmiObject Win32_ComputerSystem).Manufacturer
        $xml['Manufacturer']        = $Manufacturer

        $model                      = (Get-WmiObject Win32_ComputerSystem).Model
        $xml['model']               = $model

        $PrimaryOwnerName           = (Get-WmiObject Win32_ComputerSystem).PrimaryOwnerName
        $xml['PrimaryOwnerName']    = $PrimaryOwnerName

        $IsVirtual                  = $false
        if ( $SerialNumber -icontains "*VMware*") {
            $IsVirtual = $true
        } else {
            switch -wildcard ( $biosVersion ) {
                'VIRTUAL'   { $IsVirtual = $true }
                'A M I'     { $IsVirtual = $true }
                '*Xen*'     { $IsVirtual = $true }
            }
        }
        if ( -not $IsVirtual ) {
            if      ( $Manufacturer -icontains "*Microsoft*")  { $IsVirtual = $true }
            elseif  ( $Manufacturer -icontains "*VMWare*")     { $IsVirtual = $true }
            elseif  ( $model -icontains "*Virtual*")           { $IsVirtual = $true }
        }
        $xml['IsVirtual']           = $IsVirtual

        $rc = $true
        $result = "OK - machineInfo is collected."

    } catch {

        Write-Host "An error occurred: $($_.Exception.Message)"
        $errorDetails = $_
        if ($errorDetails) {
            Write-Host "Error details: $($errorDetails.Exception)"
        }

        $rc = $false
        $result = "Error - machineInfo step failed!"
    }
    return $rc, $result, $xml
}
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# test ports
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function get-IPPort {
    param (
        [string]$target,
        [int]$port
    )
    $rc = $false; $result=""

    $TCPtimeout = 100
    $tcpobject = New-Object System.Net.Sockets.TcpClient

    try {
        $connect = $tcpobject.BeginConnect($target, $port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne($TCPtimeout, $false)

        if (!$wait) {
            $tcpobject.Close()
            $result = "$target`:$port Timeout - closed"
        } else {
            $tcpobject.EndConnect($connect) | Out-Null
            $tcpobject.Close()
            $result = "$target`:$port success - open"
        }
        $rc = $true
    } catch {
        $tcpobject.Close()

        Write-Host "An error occurred: $($_.Exception.Message)"
        $errorDetails = $_
        if ($errorDetails) {
            Write-Host "Error details: $($errorDetails.Exception)"
        }
        $result =  "$target`:$port failed - closed ($message)"
        $rc = $false
    }
    return $rc, $result
}
function f_get-ports {
    param ($xml)
    $rc = $false; $result=""

    try {

        $toolName                   = 'Opsware-#1'; $target = '84.255.75.1'; $port = 3001
        $rc, $result                = get-IPPort -target $target -port $port
        $xml[$toolName]             = "$result"

        $toolName                   = 'Opsware-#2'; $target = '84.255.75.2'; $port = 3001
        $rc, $result                = get-IPPort -target $target -port $port
        $xml[$toolName]             = "$result"

        $toolName                   = 'Opsware-#3'; $target = '84.255.75.1'; $port = 1002
        $rc, $result                = get-IPPort -target $target -port $port
        $xml[$toolName]             = "$result"

        $toolName                   = 'Opsware-#4'; $target = '84.255.75.2'; $port = 1002
        $rc, $result                = get-IPPort -target $target -port $port
        $xml[$toolName]             = "$result"

        $toolName                   = 'ansible-#1'; $target = '84.255.94.31'; $port = 8081
        $rc, $result                = get-IPPort -target $target -port $port
        $xml[$toolName]             = "$result"

        $toolName                   = 'ansible-#2'; $target = '84.255.94.33'; $port = 8081
        $rc, $result                = get-IPPort -target $target -port $port
        $xml[$toolName]             = "$result"

        $toolName                   = 'ansible-#3'; $target = 'localhost'; $port = 5985
        $rc, $result                = get-IPPort -target $target -port $port
        $xml[$toolName]             = "$result"

        $result = "OK - get-ports step succeeded."
        $rc = $true

    } catch {

        Write-Host "An error occurred: $($_.Exception.Message)"
        # $errorDetails = $_
        # if ($errorDetails) {
        #     Write-Host "Error details: $($errorDetails.Exception)"
        # }

        $rc = $false
        $result = "Error - get-ports step failed!"
    }
    return $rc, $result, $xml
}
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# f_get-RebootPending
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function f_get-RebootPending {
    param (
        $xml
    )
    $rc = $false; $result=""
    $element = 'rebootPending'

    try {
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

        if ($rebootPending) {
            $result  = "Warn - A reboot is pending!"
        } else {
            $result  = "OK - No reboot is pending."
        }
        $rc = $true
    } catch {

        Write-Host "An error occurred: $($_.Exception.Message)"
        # $errorDetails = $_
        # if ($errorDetails) {
        #     Write-Host "Error details: $($errorDetails.Exception)"
        # }

        $rc = $false
        $result  = "Error - RebootPending step failed!"
    }
    $xml[$element] = $result
    return $rc, $result, $xml
}
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# f_get-miscellaneous
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function f_get-miscellaneous {
    param (
        $xml
    )
    $rc = $false; $result=""
    try {
        $SAAgent                    = [Bool](Get-Service -Name OpswareAgent -ErrorAction SilentlyContinue)
        $xml['SAAgent']             = $SAAgent

        $kmdpaas                    = [Bool](Get-Service -Name kmdpaas -ErrorAction SilentlyContinue)
        $xml['kmdpaas']             = $kmdpaas

        $webhostingminion           = [Bool](Get-Service -Name webhostingminion -ErrorAction SilentlyContinue)
        $xml['webhostingminion']    = $webhostingminion

        $saltminion                 = [Bool](Get-Service -Name salt-minion -ErrorAction SilentlyContinue)
        $xml['salt-minion']         = $saltminion

        $SAAgent                    = [Bool](get-service -name 'SA Agent' -ErrorAction SilentlyContinue )
        $xml['SA Agent']            = $SAAgent

        $OvCtrl                     = [Bool](get-service -name OvCtrl -ErrorAction SilentlyContinue )
        $xml['OvCtrl']              = $OvCtrl

        $TSMclassic                 = [Bool](get-service -DisplayName 'TSM client*' -ErrorAction SilentlyContinue)
        $xml['TSMclassic']          = $TSMclassic

        $TSMspectum                 = [Bool](get-service -Name 'TSM Sched*' -ErrorAction SilentlyContinue)
        $xml['TSMspectum']          = $TSMspectum

        $Commvault                  = [Bool](get-service -Name '*ClMgrS*' -ErrorAction SilentlyContinue)
        $xml['Commvault']           = $Commvault

        [int]$PSVersion             = $PSVersionTable.PSVersion | select-object -ExpandProperty major
        $xml['PSVersion']           = $PSVersion

        $MaxMemoryPerShellMB        = (Get-Item WSMan:\\localhost\\Shell\\MaxMemoryPerShellMB).Value
        $xml['MaxMemoryPerShellMB'] = "$MaxMemoryPerShellMB"

        $FireWallEnabled            = (get-netfirewallprofile -ErrorAction SilentlyContinue | Where-Object {$_.Name -imatch 'Domain|Private|Public' }).Enabled
        $xml['FireWallEnabled']     = "$FireWallEnabled"

        $EnableLUA                  = (Get-ItemProperty -Path HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\system -Name EnableLUA).EnableLUA.tostring()
        $xml['EnableLUA']           = "$EnableLUA"

        $WSMan                      = [bool](Test-WSMan -ErrorAction SilentlyContinue).ToString()
        $xml['WSMan']               = "$WSMan"

        $WinRMService               = (Get-Service winrm -ErrorAction SilentlyContinue).status | ConvertTo-Json -Compress
        $xml['WinRMService']        = "$WinRMService"

        $winrm_listener             = (winrm enumerate winrm/config/Listener) | ConvertTo-Json -Compress
        $xml['winrm_listener']       = "$winrm_listener"

        $DotNetVersion              = (Get-ChildItem 'HKLM:\\SOFTWARE\\Microsoft\\NET Framework Setup\\NDP' -recurse | Get-ItemProperty -name Version -EA 0).Version | ConvertTo-Json -Compress
        $xml['DotNetVersion']      = "$DotNetVersion"

        $rc = $true
        $result = "OK - miscellaneous is collected."
    } catch {

        Write-Host "An error occurred: $($_.Exception.Message)"
        # $errorDetails = $_
        # if ($errorDetails) {
        #     Write-Host "Error details: $($errorDetails.Exception)"
        # }

        $rc = $false
        $result = "Error - miscellaneous step failed!"
    }
    return $rc, $result, $xml
}
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# get-pimUsers
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function f_get-pimUsers {
    param ($xml)
    $rc = $false; $result=""

    try {
        $pimusers                   = (Get-LocalUser | Where-Object { $_.Name -match '^(kmdwiat|pimadm).*' }).Name
        $pimusers | foreach-object {
            $waldo                  = [Bool](Get-Localuser -Name $_ -ErrorAction SilentlyContinue)
            $fred                   = [Bool](Get-LocalGroupMember -Group 'Administrators' -member $_ -ErrorAction SilentlyContinue)
            $xml[$_]                = "User:$waldo,Administrators:$fred"
        }
        $rc = $true
        $result = "OK - pim_users is collected."
    } catch {

        Write-Host "An error occurred: $($_.Exception.Message)"
        # $errorDetails = $_
        # if ($errorDetails) {
        #     Write-Host "Error details: $($errorDetails.Exception)"
        # }

        $rc = $false
        $result = "Error - pimUsers step failed!"
    }
    return $rc, $result, $xml
}
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# f_get-Persistent
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function f_get-Persistent {
    param (
        [string]$PolicyStore,
        [string]$DestPrefix,
        $xml
    )
    $rc = $false; $result=""
    [string]$element = "route-$PolicyStore-$DestPrefix"
    try {
        $routes                 = (Get-NetRoute -PolicyStore "$PolicyStore" | Where-Object { $_.DestinationPrefix -imatch "${DestPrefix}." }).DestinationPrefix
        if ( -not [string]::IsNullOrEmpty($routes) ) {
            $PersistentRoutes = @();
            $routes | foreach-object {
                [string]$route = $_
                $PersistentRoutes += $route
            }
            $PersistentRoutes           = $PersistentRoutes | Sort-Object -Unique
            [string]$PersistentString   = $PersistentRoutes -join ","
            $result                     = $PersistentString
            $xml[$element]              = $PersistentString
            $rc                         = $true
        } else {
            $rc                         = $true
            $result                     = "No routes found for $DestPrefix in $PolicyStore."
            $xml[$element]              = $result
        }
    } catch {
        Write-Host "An error occurred: $($_.Exception.Message)"
        $errorDetails = $_
        if ($errorDetails) {
            Write-Host "Error details: $($errorDetails.Exception)"
        }
        $rc     = $false
        $result = "Error - Persistent step failed!"
    }
    return $rc, $result, $xml
}
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#
#
#   BEGIN
#
#
#
#
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# get-Persistent
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
$PolicyStore = @("ActiveStore","PersistentStore")
$routeAarray = @(
    "84.225.67",
    "84.255.124",
    "84.255.126",
    "84.255.75",
    "84.255.92"
)
$PolicyStore | foreach-object {
    $PolicyStore = "$_"
    $routeAarray | foreach-object {
        $DestPrefix         = "$_"
        $text               = "get-Persistent $PolicyStore for $DestPrefix"; $step++; f_log -logMsg $text -step $step
        $rc, $result, $xml  = f_get-Persistent -DestPrefix $DestPrefix -PolicyStore $PolicyStore -xml $xml
        if ( $rc ) { f_logOK -logMsg $result  } else { f_logError -logMsg $result }
    }
}
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# get-ports
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
$text               = "get-ports"; $step++; f_log -logMsg $text -step $step
$rc, $result, $xml  = f_get-ports -xml $xml
if ( $rc ) { f_logOK -logMsg $result  } else { f_logError -logMsg $result }
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# get-machineInfo
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
$text               = "get-machineInfo"; $step++; f_log -logMsg $text -step $step
$rc, $result, $xml  = f_get-machineInfo -xml $xml
if ( $rc ) { f_logOK -logMsg $result  } else { f_logError -logMsg $result }
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# get-RebootPending
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
$text               = "get-RebootPending"; $step++; f_log -logMsg $text -step $step
$rc, $result, $xml  = f_get-RebootPending -xml $xml
if ( $rc ) { f_logOK -logMsg $result  } else { f_logError -logMsg $result }
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# get-miscellaneous
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
$text               = "get-miscellaneous"; $step++; f_log -logMsg $text -step $step
$rc, $result, $xml  = f_get-miscellaneous -xml $xml
if ( $rc ) { f_logOK -logMsg $result  } else { f_logError -logMsg $result }
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# get-miscellaneous
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
$text               = "get-pimUsers"; $step++; f_log -logMsg $text -step $step
$rc, $result, $xml  = f_get-pimUsers -xml $xml
if ( $rc ) { f_logOK -logMsg $result  } else { f_logError -logMsg $result }
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# f_get-software and write jsonSwList
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
$text                       = "get-software"; $step++; f_log -logMsg $text -step $step
$rc, $result, $filteredSoftware, $allSoftwareList   = f_get-software -defaultSoftware $defaultSoftware
if ( $rc ) { f_logOK -logMsg $result  } else { f_logError -logMsg $result }

if ( -not [string]::IsNullOrEmpty($filteredSoftware) ) {
    $csvFilename    = "$scriptdir/${scriptname}_aeven_fsftcsv.csv"
    $null           = Remove-Item $csvFilename -Force -ErrorAction SilentlyContinue
    $filteredSoftware | Export-Csv -Path $csvFilename -Delimiter ';' -NoTypeInformation
}
if ( -not [string]::IsNullOrEmpty($allSoftwareList) ) {
    $csvFilename    = "$scriptdir/${scriptname}_aeven_fsftall.csv"
    $null           = Remove-Item $csvFilename -Force -ErrorAction SilentlyContinue
    $allSoftwareList | Export-Csv -Path $csvFilename -Delimiter ';' -NoTypeInformation
}
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# f_get-services and write jsonSwList
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
$text                       = "get-services"; $step++; f_log -logMsg $text -step $step
$rc, $result, $filteredServices, $allServicesList  = f_get-services -defaultServices $defaultServices
if ( $rc ) { f_logOK -logMsg $result  } else { f_logError -logMsg $result }

if ( -not [string]::IsNullOrEmpty($filteredServices) ) {
    $csvFilename    = "$scriptdir/${scriptname}_aeven_fsrvcsv.csv"
    $null           = Remove-Item $csvFilename -Force -ErrorAction SilentlyContinue
    $filteredServices | Export-Csv -Path $csvFilename -Delimiter ';' -NoTypeInformation
}
if ( -not [string]::IsNullOrEmpty($allServicesList) ) {
    $csvFilename    = "$scriptdir/${scriptname}_aeven_fsrvall.csv"
    $null           = Remove-Item $csvFilename -Force -ErrorAction SilentlyContinue
    $allServicesList | Export-Csv -Path $csvFilename -Delimiter ';' -NoTypeInformation
}
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# print keys and values
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Write-Host "# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
Write-Host "# print keys and values"
Write-Host "# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
foreach ($key in $xml.Keys | Sort $key  ) {
    $line = '{0,-40} {1}' -f $key,$xml[$key]
    Write-Output $line
}
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Create a new csv file
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
$sortedByKey = $xml.GetEnumerator() | Sort-Object Name
$sortedHashtable = [ordered]@{}
$sortedByKey | ForEach-Object {
    $sortedHashtable[$_.Name] = $_.Value
}
$csvObject = New-Object PSObject -Property $sortedHashtable
$csvFilename = "${scriptdir}/${scriptname}_aeven_foutcsv.csv"
$null = Remove-Item $csvFilename -Force -ErrorAction SilentlyContinue
$csvObject | Export-Csv -Path $csvFilename -Delimiter ';' -NoTypeInformation
# to get only the
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Create a new jsom file
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# $sortedByKey = $xml.GetEnumerator() | Sort-Object Name
# $sortedHashtable = [ordered]@{}
# $sortedByKey | ForEach-Object {
#     $sortedHashtable[$_.Name] = $_.Value
# }
# $json = $sortedHashtable | ConvertTo-Json
# $jsonFilename = "$scriptdir/$scriptname.json"
# $null = Remove-Item $jsonFilename -Force -ErrorAction SilentlyContinue
# $json | Out-File -FilePath $jsonFilename -Encoding utf8
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Create a new XML document
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# $xmlDoc = New-Object System.Xml.XmlDocument
# $xmlDeclaration = $xmlDoc.CreateXmlDeclaration("1.0", "UTF-8", $null)
# $xmlDoc.AppendChild($xmlDeclaration)
# $root = $xmlDoc.CreateElement("SystemInformation")
# $xmlDoc.AppendChild($root)

# # Create child xml and add them to the root element
# foreach ($elementName in $xml.Keys | Sort $elementName  ) {
#     $element = $xmlDoc.CreateElement($elementName)
#     $element.InnerText = $xml[$elementName]
#     $root.AppendChild($element)
# }
# $OSFilename = $scriptdir+"/"+$scriptname+".xml"
# $null       = remove-item $OSFilename -Force -ErrorAction SilentlyContinue
# $xmlDoc.Save($OSFilename)
# -----------------------------------------------------------------------------------------------------------------
# The End
# -----------------------------------------------------------------------------------------------------------------
$end = (get-date -format "yyyy-MM-dd HH:mm:ss.fff")
$TimeDiff = New-TimeSpan $begin $end
if ($TimeDiff.Seconds -lt 0) {
	$Hrs = ($TimeDiff.Hours) + 23
	$Mins = ($TimeDiff.Minutes) + 59
	$Secs = ($TimeDiff.Seconds) + 59
} else {
	$Hrs = $TimeDiff.Hours
	$Mins = $TimeDiff.Minutes44
	$Secs = $TimeDiff.Seconds
}
$Difference = '{0:00}:{1:00}:{2:00}' -f $Hrs,$Mins,$Secs
$text = "End  elapsed  $Difference"; $step++; f_log -logMsg $text -step $step;f_logOK