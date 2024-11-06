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
    $workHash                   = [ordered]@{}
    $workHash['date']           = $begin
    # $scriptdir                = (Get-Location).Path
    # $scriptdir                = [System.Text.RegularExpressions.Regex]::Replace($scriptdir,"`\","/")
    # $scriptname               = ($myinvocation).mycommand.Name
    # if ( [string]::IsNullOrEmpty($scriptdir) ) {
    #     $scriptdir            = "C:/Windows/Temp/servercheck/"
    #     $scriptname           = 'servercheck'
    # } else {
    #     $scriptname           = [System.Text.RegularExpressions.Regex]::Replace($scriptname,"`.ps1","")
    # }
    $scriptdir                  = "C:/Windows/Temp/servercheck/"
    $scriptname                 = 'servercheck'
    # $workHash['scriptname']= $scriptname
    # $workHash['xmlFile']= $scriptdir+$scriptname+".xml"

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
    param ($defaultSoftware,$workHash)
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
        [string]$opsware = [bool]($allSoftwareList |  Where-Object { $_.DisplayName -imatch '.*SA Agent.*' }).DisplayName
        $workHash['SA-Opsware-software'] = $opsware

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
    return $rc, $result, $filteredSoftware, $allSoftwareList, $workHash
}
function f_get-services {
    param ($defaultServices,$workHash)
    $rc = $false; $result=""
    try {

        $allServices = Get-Service | Select-Object Name, DisplayName | Sort-Object DisplayName
        $filteredServices = foreach ($service in $allServices) {
            if ($defaultServices.Name -inotcontains $service.Name ) {
                $service
            }
        }
        $workHash['OpswareAgent-SA']    = [BOOL]($allServices |  Where-Object { $_.Name -imatch 'OpswareAgent' })
        $workHash['OvSvcDiscAgent-OMI'] = [BOOL]($allServices |  Where-Object { $_.Name -imatch 'OvSvcDiscAgent' })
        $workHash['OvCtrl-OMI']         = [BOOL]($allServices |  Where-Object { $_.Name -imatch 'OvCtrl' })
        $workHash['DiscAgent-ucmdb']    = [BOOL]($allServices |  Where-Object { $_.Name -imatch 'DiscAgent' })
        $workHash['WinRMService']       = [BOOL]($allServices |  Where-Object { $_.Name -imatch 'winrm' })
        $workHash['kmdpaas']            = [BOOL]($allServices |  Where-Object { $_.Name -imatch 'kmdpaas' })
        $workHash['webhostingminion']   = [BOOL]($allServices |  Where-Object { $_.Name -imatch 'webhostingminion' })
        $workHash['salt-minion']        = [BOOL]($allServices |  Where-Object { $_.Name -imatch 'salt-minion' })
        $workHash['TSMclassic']         = [BOOL]($allServices |  Where-Object { $_.Name -imatch 'TSM client' })
        $workHash['TSMspectum']         = [BOOL]($allServices |  Where-Object { $_.Name -imatch 'TSM client' })
        $workHash['Commvault']          = [BOOL]($allServices |  Where-Object { $_.Name -imatch 'Commvault' })

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
    return $rc, $result, $filteredServices, $allServices, $workHash
}
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# functions
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function f_get-machineInfo {
    param ($workHash)
    $rc = $false; $result=""

    try {
        [string]$hostname           = $env:COMPUTERNAME.ToLower()
        $workHash['hostname']       = $hostname

        $OperatingSystem            = Get-CimInstance -ClassName Win32_OperatingSystem
        [string]$OperatingSystem    = $OperatingSystem.caption + " " + $OperatingSystem.OSArchitecture + " SP " + $OperatingSystem.ServicePackMajorVersion
        $workHash['OperatingSystem']= $OperatingSystem

        [string]$OSname             = (Get-WmiObject Win32_OperatingSystem).Caption
        $workHash['OSname']         = $OSname

        [string]$OSversion          = (Get-WmiObject Win32_OperatingSystem).version
        $workHash['OSversion']      = $OSversion

        [string]$OSservicePack      = (Get-WmiObject Win32_OperatingSystem).ServicePackMajorVersion
        $workHash['OSservicePack']  = $OSservicePack

        [string]$windir             = $env:WINDIR
        $workHash['windir']         = $windir

        [string]$systemroot         = $env:SystemRoot
        $workHash['systemroot']     = $systemroot

        [string]$systemdrive        = $env:SystemDrive
        $workHash['systemdrive']    = $systemdrive

        [string]$x64                = (Get-WmiObject -Class Win32_OperatingSystem).OSArchitecture -like '64-bit'
        $workHash['x64']            = $x64

        [string]$biosVersion        = (Get-WmiObject Win32_BIOS).Version
        $workHash['biosVersion']    = $biosVersion

        [string]$biosName           = (Get-WmiObject Win32_BIOS).Name
        $workHash['biosName']       = $biosName

        [string]$Manufacturer       = (Get-WmiObject Win32_ComputerSystem).Manufacturer
        $workHash['Manufacturer']   = $Manufacturer

        [string]$model              = (Get-WmiObject Win32_ComputerSystem).Model
        $workHash['model']          = $model

        [string]$PrimaryOwnerName   = (Get-WmiObject Win32_ComputerSystem).PrimaryOwnerName
        $workHash['PrimaryOwnerName']= $PrimaryOwnerName
        $workHash['netAdapters_total']=  @(Get-WmiObject -Class Win32_NetworkAdapterConfiguration).Count
        $workHash['netAdapters_enabled']= @(Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPENABLED=TRUE).Count
        $NetworkAdapterConfiguration= Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPENABLED=TRUE
        [string]$IPAddress          = $NetworkAdapterConfiguration.IPAddress[0]
        [string]$IPSubnet           = $NetworkAdapterConfiguration.IPSubnet
        [string]$DefaultIPGateway   = $NetworkAdapterConfiguration.DefaultIPGateway
        [string]$MACAddress         = $NetworkAdapterConfiguration.MACAddress
        [string]$DNSServerSearch    = $NetworkAdapterConfiguration.DNSServerSearchOrder
        $workHash['IPAddress']      = $IPaddress
        $workHash['IPSubnet']       = $IPSubnet
        $workHash['DefaultIPGateway']=$DefaultIPGateway
        $workHash['MACAddress']     = $MACAddress
        $workHash['DNSServerSearch']= $DNSServerSearch
        [string]$IPaddress_check    = ([System.Net.DNS]::GetHostAddresses([System.Net.Dns]::GetHostName())|Where-Object {$_.AddressFamily -eq 'InterNetwork'} | select-object IPAddressToString)[0].IPAddressToString
        $workHash['IPaddress_check']= $IPaddress_check

        $CPU                        = Get-CimInstance -Class Win32_Processor
        $workHash['CPU']            = $CPU[0].Name
        $workHash['CPUCaption']     = $CPU[0].Description
        $workHash['CPUManufacturer']= $CPU[0].Manufacturer
        $workHash['CPUspeed']       = ($CPU[0].MaxClockSpeed/1000).tostring()
        $workHash['CPUcount']       = ($CPU | Measure-Object -Property NumberOfCores -Sum).Sum.ToString()
        $workHash['CPUcores']       = ($CPU | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum.ToString()
        $workHash['CPUsockets']     = ($CPU | Select-Object -ExpandProperty SocketDesignation | Measure-Object).Count.ToString()

        $PhysicalMemory             = (Get-CimInstance -class Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).Sum
        $PhysicalMemory             = ([math]::round(($PhysicalMemory / 1GB),0))

        [string]$FQDN               = ([System.Net.Dns]::GetHostEntry([System.Net.Dns]::GetHostName())).HostName
        $workHash['FQDN']           = $FQDN

        [string]$Domain             = (Get-WmiObject Win32_ComputerSystem).Domain
        $workHash['Domain']         = $Domain

        # $diskspace                  = get-WmiObject Win32_Volume -ErrorAction SilentlyContinue | Where-Object { $_.drivetype -eq '3' -and $_.driveletter } | Select-Object driveletter,@{Name='freespace';Expression={[math]::round($_.freespace/1GB, 0)}},@{Name='capacity';Expression={[math]::round($_.capacity/1GB, 0)}}
        # $workHash['diskspace']      = $diskspace.trim()
        # $workHash['diskspace']      = $diskspace | ConvertTo-Json -Compress
        $diskdrives                 = Get-WmiObject Win32_Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveType -eq 3 -and $_.DriveLetter }
        $diskdrives | ForEach-Object {
            $driveLetter            = $_.DriveLetter
            $driveLetter            = [System.Text.RegularExpressions.Regex]::Replace($driveLetter,"`:","")
            $capacity = [math]::Floor($_.Capacity / 1GB)
            $freeSpace = [math]::Floor($_.FreeSpace / 1GB)
            $key = "diskdrive_${driveLetter}"
            $workHash[$key] = "capacity=${capacity},free=${freeSpace}"
        }

        $DiskSpaceSum               = (Get-WmiObject Win32_Volume -Filter "DriveType='3'" | Measure-Object -Property capacity -Sum).Sum
        $DiskSpaceSum               = [Math]::Round(($DiskSpaceSum / 1GB),0)
        $workHash['DiskSpaceSum']   = $DiskSpaceSum

        [string]$serialnumber       = (Get-WmiObject Win32_BIOS).SerialNumber
        $workHash['SerialNumber']   = $SerialNumber

        $IsVirtual                  = $false
        if ( $SerialNumber -imatch "VMware") {
            $IsVirtual = $true
        } else {
            switch -wildcard ( $biosVersion ) {
                'VIRTUAL'   { $IsVirtual = $true }
                'A M I'     { $IsVirtual = $true }
                '*Xen*'     { $IsVirtual = $true }
            }
        }
        if ( -not $IsVirtual ) {
            if      ( $Manufacturer -imatch "Microsoft")  { $IsVirtual = $true }
            elseif  ( $Manufacturer -imatch "VMWare")     { $IsVirtual = $true }
            elseif  ( $model -imatch "Virtual")           { $IsVirtual = $true }
        }
        $workHash['IsVirtual']   = $IsVirtual

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
    return $rc, $result, $workHash
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
    param ($workHash)
    $rc = $false; $result=""

    try {

        $toolName                   = 'Opsware-1'; $target = '84.255.75.1'; $port = 3001
        $rc, $result                = get-IPPort -target $target -port $port
        $workHash[$toolName]        = "$result"

        $toolName                   = 'Opsware-2'; $target = '84.255.75.2'; $port = 3001
        $rc, $result                = get-IPPort -target $target -port $port
        $workHash[$toolName]        = "$result"

        $toolName                   = 'Opsware-3'; $target = '84.255.75.1'; $port = 1002
        $rc, $result                = get-IPPort -target $target -port $port
        $workHash[$toolName]        = "$result"

        $toolName                   = 'Opsware-4'; $target = '84.255.75.2'; $port = 1002
        $rc, $result                = get-IPPort -target $target -port $port
        $workHash[$toolName]        = "$result"

        $toolName                   = 'OMI-1'; $target = '84.255.75.1'; $port = 383
        $rc, $result                = get-IPPort -target $target -port $port
        $workHash[$toolName]        = "$result"

        $toolName                   = 'OMI-2'; $target = '84.255.75.2'; $port = 383
        $rc, $result                = get-IPPort -target $target -port $port
        $workHash[$toolName]        = "$result"

        $toolName                   = 'OMI-3'; $target = '84.255.75.1'; $port = 3128
        $rc, $result                = get-IPPort -target $target -port $port
        $workHash[$toolName]        = "$result"

        $toolName                   = 'OMI-4'; $target = '84.255.75.2'; $port = 3128
        $rc, $result                = get-IPPort -target $target -port $port
        $workHash[$toolName]        = "$result"

        $toolName                   = 'ansible-1'; $target = '84.255.94.31'; $port = 8081
        $rc, $result                = get-IPPort -target $target -port $port
        $workHash[$toolName]        = "$result"

        $toolName                   = 'ansible-2'; $target = '84.255.94.33'; $port = 8081
        $rc, $result                = get-IPPort -target $target -port $port
        $workHash[$toolName]        = "$result"

        $toolName                   = 'ansible-3'; $target = 'localhost'; $port = 5985
        $rc, $result                = get-IPPort -target $target -port $port
        $workHash[$toolName]        = "$result"

        $result = "OK - get-ports step succeeded."
        $rc = $true

    } catch {

        Write-Host "An error occurred: $($_.Exception.Message)"
        $errorDetails = $_
        if ($errorDetails) {
            Write-Host "Error details: $($errorDetails.Exception)"
        }

        $rc = $false
        $result = "Error - get-ports step failed!"
    }
    return $rc, $result, $workHash
}
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# f_get-RebootPending
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function f_get-RebootPending {
    param (
        $workHash
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
        $workHash[$element] = $result
    } catch {

        Write-Host "An error occurred: $($_.Exception.Message)"
        $errorDetails = $_
        if ($errorDetails) {
            Write-Host "Error details: $($errorDetails.Exception)"
        }

        $rc = $false
        $result  = "Error - RebootPending step failed!"
    }

    return $rc, $result, $workHash
}
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# f_get-miscellaneous
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function f_get-miscellaneous {
    param (
        $workHash
    )
    $rc = $false; $result=""
    try {

        [int]$PSVersion                 = $PSVersionTable.PSVersion | select-object -ExpandProperty major
        $workHash['PSVersion']          = $PSVersion

        $MaxMemoryPerShellMB            = (Get-Item WSMan:\\localhost\\Shell\\MaxMemoryPerShellMB).Value
        $workHash['MaxMemoryPerShellMB']= $MaxMemoryPerShellMB

        [string]$Domain                 = (get-netfirewallprofile -ErrorAction SilentlyContinue | Where-Object {$_.Name -imatch 'Domain' }).Enabled
        [string]$Private                = (get-netfirewallprofile -ErrorAction SilentlyContinue | Where-Object {$_.Name -imatch 'Private' }).Enabled
        [string]$Public                 = (get-netfirewallprofile -ErrorAction SilentlyContinue | Where-Object {$_.Name -imatch 'Public' }).Enabled
        $workHash['FireWallEnabled']    = "Domain=$Domain|Private=$Domain|Public=$Domain"

        $EnableLUA                      = (Get-ItemProperty -Path HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\system -Name EnableLUA).EnableLUA.tostring()
        $workHash['EnableLUA']          = $EnableLUA

        $WSMan                          = [bool](Test-WSMan -ErrorAction SilentlyContinue).ToString()
        $workHash['WSMan']              = $WSMan

        [string]$listener               = (winrm enumerate winrm/config/Listener)
        [string]$listener               = $listener -replace '=', '' -replace '\,','' -replace '"', '' -replace '\s+',' '
        [string]$port                   = [regex]::Match($listener, 'Port\s+(\S+?)\s').Groups.Value[0]
        [string]$Enabled                = [regex]::Match($listener, 'Enabled\s+(\S+?)\s').Groups.Value[0]
        [string]$ListeningOn            = [regex]::Match($listener, 'ListeningOn\s+(\S+?)\s').Groups.Value[0]
        $workHash['winrmListener']      = "$port,$Enabled,$ListeningOn"

        $DotNetVersion                  = (Get-ChildItem 'HKLM:\\SOFTWARE\\Microsoft\\NET Framework Setup\\NDP' -recurse | Get-ItemProperty -name Version -EA 0).Version | ConvertTo-Json -Compress
        $workHash['DotNetVersion']      = $DotNetVersion

        $rc = $true
        $result = "OK - miscellaneous is collected."
    } catch {

        Write-Host "An error occurred: $($_.Exception.Message)"
        $errorDetails = $_
        if ($errorDetails) {
            Write-Host "Error details: $($errorDetails.Exception)"
        }

        $rc = $false
        $result = "Error - miscellaneous step failed!"
    }
    return $rc, $result, $workHash
}
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# get-pimUsers
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function f_get-pimUsers {
    param ($workHash)
    $rc = $false; $result=""

    try {
        $pimusers                   = (Get-LocalUser | Where-Object { $_.Name -match '^(kmdwiat|pimadm).*' }).Name
        $pimusers | foreach-object {
            $waldo                  = [Bool](Get-Localuser -Name $_ -ErrorAction SilentlyContinue)
            $fred                   = [Bool](Get-LocalGroupMember -Group 'Administrators' -member $_ -ErrorAction SilentlyContinue)
            $workHash[$_]           = "User:$waldo,Administrators:$fred"
        }
        $rc = $true
        $result = "OK - pim_users is collected."
    } catch {

        Write-Host "An error occurred: $($_.Exception.Message)"
        $errorDetails = $_
        if ($errorDetails) {
            Write-Host "Error details: $($errorDetails.Exception)"
        }

        $rc = $false
        $result = "Error - pimUsers step failed!"
    }
    return $rc, $result, $workHash
}
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# f_get-Persistent
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function f_get-Persistent {
    param (
        [string]$PolicyStore,
        [string]$DestPrefix,
        $workHash
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
            $workHash[$element]         = $PersistentString
            $rc                         = $true
        } else {
            $rc                         = $true
            $result                     = "No routes found for $DestPrefix in $PolicyStore."
            $workHash[$element]         = $result
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
    return $rc, $result, $workHash
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
        $rc, $result, $workHash  = f_get-Persistent -DestPrefix $DestPrefix -PolicyStore $PolicyStore -workHash $workHash
        if ( $rc ) { f_logOK -logMsg $result  } else { f_logError -logMsg $result }
    }
}
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# get-ports
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
$text = "get-ports"; $step++; f_log -logMsg $text -step $step
$rc, $result, $workHash = f_get-ports -workHash $workHash
if ( $rc ) { f_logOK -logMsg $result  } else { f_logError -logMsg $result }
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# get-machineInfo
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
$text = "get-machineInfo"; $step++; f_log -logMsg $text -step $step
$rc, $result, $workHash = f_get-machineInfo -workHash $workHash
if ( $rc ) { f_logOK -logMsg $result  } else { f_logError -logMsg $result }
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# get-RebootPending
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
$text = "get-RebootPending"; $step++; f_log -logMsg $text -step $step
$rc, $result, $workHash = f_get-RebootPending -workHash $workHash
if ( $rc ) { f_logOK -logMsg $result  } else { f_logError -logMsg $result }
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# get-miscellaneous
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
$text = "get-miscellaneous"; $step++; f_log -logMsg $text -step $step
$rc, $result, $workHash = f_get-miscellaneous -workHash $workHash
if ( $rc ) { f_logOK -logMsg $result  } else { f_logError -logMsg $result }
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# get-miscellaneous
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
$text = "get-pimUsers"; $step++; f_log -logMsg $text -step $step
$rc, $result, $workHash = f_get-pimUsers -workHash $workHash
if ( $rc ) { f_logOK -logMsg $result  } else { f_logError -logMsg $result }
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# f_get-software and write jsonSwList
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
$text = "get-software"; $step++; f_log -logMsg $text -step $step
$rc, $result, $filteredSoftware, $allSoftwareList, $workHash = f_get-software -defaultSoftware $defaultSoftware -workHash $workHash
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
$text = "get-services"; $step++; f_log -logMsg $text -step $step
$rc, $result, $filteredServices, $allServices, $workHash = f_get-services -defaultServices $defaultServices -workHash $workHash
if ( $rc ) { f_logOK -logMsg $result  } else { f_logError -logMsg $result }

if ( -not [string]::IsNullOrEmpty($filteredServices) ) {
    $csvFilename    = "$scriptdir/${scriptname}_aeven_fsrvcsv.csv"
    $null           = Remove-Item $csvFilename -Force -ErrorAction SilentlyContinue
    $filteredServices | Export-Csv -Path $csvFilename -Delimiter ';' -NoTypeInformation
}
if ( -not [string]::IsNullOrEmpty($allServices) ) {
    $csvFilename    = "$scriptdir/${scriptname}_aeven_fsrvall.csv"
    $null           = Remove-Item $csvFilename -Force -ErrorAction SilentlyContinue
    $allServices | Export-Csv -Path $csvFilename -Delimiter ';' -NoTypeInformation
}
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# output all
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
$finalHashtable = $workHash
# $finalHashtable = [ordered]@{}
# foreach ($key in $workHash.Keys ) {
#     [string]$key    = $key
#     [string]$value  = $workHash[$key]
#     $key            = $key.Trim()
#     $value          = $value.Trim()
#     $finalHashtable[$key] = $value
#     $line = '{0,-40} {1}' -f $key,$value
#     Write-Output $line
# }
# Create a csv file
$csvFilename = "${scriptdir}/${scriptname}_aeven_foutcsv.csv"
$null = Remove-Item $csvFilename -Force -ErrorAction SilentlyContinue
$finalHashtable | Export-Csv -Path $csvFilename -Delimiter ';' -NoTypeInformation

# Create json file
$jsonFilename = "${scriptdir}/${scriptname}_aeven_foutjsn.json"
$null = Remove-Item $jsonFilename -Force -ErrorAction SilentlyContinue
$json = $finalHashtable | ConvertTo-Json
$json | Out-File -FilePath $jsonFilename -Encoding utf8

# Create xml file
$xmlDoc = New-Object System.Xml.XmlDocument
$xmlDeclaration = $xmlDoc.CreateXmlDeclaration("1.0", "UTF-8", $null)
$xmlDoc.AppendChild($xmlDeclaration)
$root = $xmlDoc.CreateElement('SystemInformation')
$xmlDoc.AppendChild($root)
foreach ($key in $finalHashtable.Keys) {
    $element = $xmlDoc.CreateElement($key)
    $element.InnerText = $finalHashtable[$key]
    $root.AppendChild($element)
}
$OSFilename = "${scriptdir}/${scriptname}_aeven_foutxml.xml"
$null       = remove-item $OSFilename -Force -ErrorAction SilentlyContinue
$xmlDoc.Save($OSFilename)
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