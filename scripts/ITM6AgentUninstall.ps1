"------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
Remove-Variable * -ErrorAction SilentlyContinue
[int]$psvers = $PSVersionTable.PSVersion | select-object -ExpandProperty major
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
# ITM6AgentUninstall.ps1  :      project de-tooling
#
# Objective:
# for this script is to do a complete uninstall of ITM6 agent and all legacy versions, if any on a given server.
# also check and uninstall if any legacy versions. But do not uninstall if a opentext version exists on server.
# the script is uploaded to a server and started remotely by a automation tool like ansible
#
# 2025-03-13  Initial release ( Benny.Skov@kyndryl.dk )
#
#>
# ----------------------------------------------------------------------------------------------------------------------------
#region begining - INIT
# ----------------------------------------------------------------------------------------------------------------------------
$begin          = (get-date -format "yyyy-MM-dd HH:mm:ss.fff")
$step           = 0
$hostname       = hostname
$hostname       = $hostname.ToLower()
$hostIp         = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPENABLED=TRUE | Select-Object IPAddress | select-object -expandproperty IPAddress | select-object -first 1
$scriptName     = $myinvocation.mycommand.Name
$scriptPath     = $myinvocation.mycommand.Path
$scriptName     = [System.Text.RegularExpressions.Regex]::Replace($scriptName, ".ps1", "")
$scriptDir      = [System.Text.RegularExpressions.Regex]::Replace($scriptPath, "\\", "/")
$scriptarray    = $scriptDir.split("/")
$scriptDir      = $scriptarray[0..($scriptarray.Count-2)] -join "/"
$logfile        = "${scriptDir}/${scriptName}.log"
if (-not (Test-Path -Path ${scriptDir})) {
    try {
        New-Item -Path ${scriptDir} -ItemType Directory -Force | Out-Null
        $icaclsCmd = "icacls `"${scriptDir}`" /grant `"Users`":`(OI`)`(CI`)F"
        $result = Invoke-Expression $icaclsCmd
        $text = "Created directory ${scriptDir} and set permissions"; Logline -logstring $text
    }
    catch {
        $text = "Error creating directory ${scriptDir}: $_"; Logline -logstring $text
    }
}
remove-item -Path $logfile -Force -ErrorAction SilentlyContinue
"------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
"begin:             " + $begin
"hostname:          " + $hostname
"hostIp:            " + $hostIp
"scriptName:        " + $scriptName
"scriptPath:        " + $scriptPath
"scriptDir:         " + $scriptDir
"logfile:           " + $logfile
"Powershell ver:    " + $psvers
"------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
# ----------------------------------------------------------------------------------------------------------------------------
#region functions
# ----------------------------------------------------------------------------------------------------------------------------
Function Logline
{
Param ([string]$logstring,$step)
    $now = (get-date -format "yyyy-MM-dd HH:mm:ss.fff")
    $text = ( "{0,-23} : $hostname : step {1:d4} : {2,-75} : {3}" -f $now,$step,$logstring,"" )
    Add-content -LiteralPath $Logfile -value $text
    Write-Host $text
}
Function finish
{
Param(
    [string]$f_result = "",
    [string]$f_message = ""
)
    if ( $f_message ) { Write-Host f_message  }
    if ( $f_message ) { " : $f_result" }
    if ( $f_result -eq 0 ) { exit 12 }
}
function Test-RemoveWMInamespace {
    $isAllDoneOK = $true
    $text = "Removing CCM WMI namespaces"; $step++; Logline -logstring $text -step $step
    try {
        Get-WmiObject -Query "SELECT * FROM __Namespace WHERE Name='CCM'" -Namespace "root" -ErrorAction SilentlyContinue |
            Remove-WmiObject -ErrorAction SilentlyContinue
        Get-WmiObject -Query "SELECT * FROM __Namespace WHERE Name='SMSDM'" -Namespace "root\cimv2" -ErrorAction SilentlyContinue |
            Remove-WmiObject -ErrorAction SilentlyContinue
        Logline -logstring "OK"
    } catch {
        $text = "Error removing WMI namespaces: $_";Logline -logstring $text
        $isAllDoneOK = $false
    }
    return $isAllDoneOK
}
function Test-CleanupRegistry {
    $isAllDoneOK = $true
    $regKeys = @(
        "HKLM:\SOFTWARE\Microsoft\CCM",
        "HKLM:\SOFTWARE\Microsoft\SMS",
        "HKLM:\SOFTWARE\Microsoft\CCMSetup",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\CCM",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\SMS",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\CCMSetup"
    )
    $text = "Clean up registry"; $step++; Logline -logstring $text -step $step
    foreach ($key in $regKeys) {
        if (Test-Path $key) {
            try {
                $text = "Removing registry key: $key";Logline -logstring $text
                Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
            } catch {
                $text = "Error removing registry key $key : $_";Logline -logstring $text
                $isAllDoneOK = $false
            }
        }
    }
    if ( $isAllDoneOK) {
        return $true
    } else {
        return $true
    }
}
function Test-CleanupProductFiles {
    $isAllDoneOK = $true
    $filesNotRemoved = @()
    $clientPaths = @(
        "C:/IBM/ITM/",
        "C:/PROGRA~1\IBM\tivoli\common\CIT",
        "C:/PROGRA~1\IBM\tivoli\common\cfg",
        "C:/ProgramData/BigFix/"
    )

    $text = "cleanup all product files, if uninstall didnt do it"; $step++; Logline -logstring $text -step $step
    foreach ($path in $clientPaths) {
        if ( Test-Path $path ) {
            try {
                $text = "Force removing directory: $path"; Logline -logstring $text
                Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            }
            catch {
                $text = "Error removing $path : $_"; Logline -logstring $text
                $filesNotRemoved += $path
                $isAllDoneOK = $false
            }
        }
    }
    if ( $isAllDoneOK ) {
        $filesExist = Test-Path "C:/IBM/ITM/"
        return -not ($filesExist)
    } else {
        if ( $filesNotRemoved.Count -gt 0 ) {
            foreach ($path in $filesNotRemoved) {
                $cmdexec = '${scriptDir}/handle "${path}" -accepteula -nobannerr'
                $result = & cmd /C $cmdexec 2>&1
                Logline -logstring $result -step $step
                # python.exe         pid: 10920  type: File           770: D:\scripts\tview\build\logs\activities\debugfile\tool_launch_activities_2025-03-17_07-57-06_078402_kmdwinitm001_stdout.log
            }
        }
    }

}
function Test-IsAgentsStopped {
    $serviceExists = $(Get-Service | Where-Object { $_.Name -match '^k.*' -and $_.DisplayName -match 'Monitoring agent' } -ErrorAction SilentlyContinue).Name
    $processExists = $(Get-Process | Where-Object { $_.ProcessName -match '^k.*' -and $_.Description -match 'Monitoring agent' } -ErrorAction SilentlyContinue).ProcessName
    $serviceExists | format-table -autosize | Out-string -Width 300
    $processExists | format-table -autosize | Out-string -Width 300

    return -not ($serviceExists -or $processExists)
}
#endregion
function Uninstall-ProductAgent {
    param(
        [switch]$Force,
        [switch]$NoReboot
    )

    if ( [bool](Get-WmiObject Win32_Process -Filter "name = 'ITMRmvAll.exe'") ) {
        $text = "stop ITMRmvAll.exe if program is still running from last run."; $step++; Logline -logstring $text -step $step
        $result = Get-WmiObject Win32_Process -Filter "name = 'ITMRmvAll.exe'" | Select-Object ProcessId, CommandLine | Where-Object { $_.CommandLine -like "*ITMRmvAll.exe*" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -PassThru -ErrorAction Stop -Verbose }
        Logline -logstring $result -step $step
    }
    Start-Sleep -Seconds 10
    if ( [bool](Get-WmiObject Win32_Process -Filter "name = 'ITMRmvAll.exe'") ) {
        $text = "ITMRmvAll.exe is still running. We try stopping it using psKill"; Logline -logstring $result -step $step
        $cmdexec = "${scriptDir}/psKill -t $serviceName -accepteula -nobanner"
        Logline -logstring $cmdexec -step $step
        $result = & cmd /C $cmdexec 2>&1
        Logline -logstring $result -step $step
    }




    $text = "stop Method 1: Stop all ITM6 agents using Stop-Service"; $step++; Logline -logstring $text -step $step
    $servicesToStop = Get-Service | Where-Object { $_.Name -match '^k.*' -and $_.DisplayName -match 'Monitoring agent'  } -ErrorAction SilentlyContinue
    $servicesToStop | Stop-Service -Force
    Start-Sleep -Seconds 10
    foreach ($service in $servicesToStop) {
        $service | Set-Service -StartupType Disabled
        $service | Stop-Service -force
        $result = $service | Get-Service
        Logline -logstring $result -step $step
    }

    $text = "stop Method 2: Stop ITM6 using WMI AND then terminate"; $step++; Logline -logstring $text -step $step
    $ReturnValue = $(Get-WmiObject Win32_Process | Where-Object commandLine -match '^C:\\IBM.ITM\\.*\\K*' | ForEach-Object { $_.Terminate() }).ReturnValue
    if ($ReturnValue) {
        foreach ($rc in $ReturnValue) {
            if ( -not $rc -eq 0 ) {
                write-host "rc=$rc"
            }
        }
    }
    $servicesToStop = Get-Service | Where-Object { $_.Name -match '^k.*' -and $_.DisplayName -match 'Monitoring agent' }
    foreach ($service in $servicesToStop) {
        $service | Set-Service -StartupType Disabled
        $service | Stop-Service -force
        $result = $service | Get-Service
        Logline -logstring "$result"
    }
    Start-Sleep -Seconds 10
    if ( Test-IsAgentsStopped -eq $false ) {

        $text = "Method 3: Stop ITM6 using net stop service"; $step++; Logline -logstring $text -step $step
        $servicesToStop = $(Get-Service | Where-Object { $_.Name -match '^k.*' -and $_.DisplayName -match 'Monitoring agent' }).Name
        foreach ($serviceName in $servicesToStop) {
            $cmdexec = "net stop $serviceName"
            $result = & cmd /C $cmdexec 2>&1
            Logline -logstring "$result"
        }
        Start-Sleep -Seconds 10
        $result = $servicesToStop | format-table -autosize | Out-string -Width 300
        Logline -logstring "$result"
    }

    $text = "Method 2: Use WMIC (for older systems)"; $step++; Logline -logstring $text -step $step
    Logline -logstring "begin"
    try {
        $text = "Attempting uninstall via WMI";Logline -logstring $text
        $result = Invoke-Expression "wmic product where 'name like ""Configuration Manager Client""' call uninstall /nointeractive"
        $text = "WMI uninstall attempted";Logline -logstring $text
    } catch {
        $text = "WMI uninstall error: $_";Logline -logstring $text
    }

    $text = "Method 3: MsiExec for direct uninstall (if other methods fail)"; $step++; Logline -logstring $text -step $step
    Logline -logstring "begin"
    try {
        $clientMsi = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*Configuration Manager Client*" }
        if ($clientMsi) {
            $text = "Uninstalling via MSI: $($clientMsi.Name)";Logline -logstring $text
            $result = $clientMsi.Uninstall()
            $text = "MSI uninstall result: $($result.ReturnValue)";Logline -logstring $text
        }
    } catch {
        $text = "MSI uninstall error: $_";Logline -logstring $text
    }

    $text = "uninstall ITM6 Agents"; $step++; Logline -logstring $text -step $step
    $possiblePaths = @(
        "${scriptDir}/ITMRmvAll.exe"
    )

    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $program = $path
            break
        }
    }
    if (Test-Path "$program") {
        $text = " ITMRmvAll"; Logline -logstring $text
        $cmdexec = @("start", "/WAIT", "/MIN", "`"${program}`"", "-batchrmvall", "-removegskit")
        Logline -logstring "begin" $cmdexec
        $result = & cmd /C $cmdexec 2>&1
        $rc = $?
        if ( $rc ) {
            Logline -logstring "Success. rc=$rc result=$result"
        }
        else {
            Logline -logstring "Failed. rc=$rc result=$result"
        }
        $text = "ITMRmvAll exit code: $($result.ExitCode)"; Logline -logstring $text
    }




    $text = "Check if uninstallation was successful"; $step++; Logline -logstring $text -step $step
    Logline -logstring "begin"
    $success = -not (Test-Path "$env:WinDir\CCM\CcmExec.exe")
    if ($success) {
        $text = "SCCM client uninstallation appears successful";Logline -logstring $text
    } else {
        $text = "SCCM client may still be installed. Consider using -Force parameter";Logline -logstring $text
    }

    if (-not $NoReboot -and (Test-Path HKLM:\SYSTEM\CurrentControlSet\Control\Session` Manager\PendingFileRenameOperations)) {
        $text = "System restart required to complete uninstallation"; Logline -logstring $text
        Restart-Computer -Force
    }

    return $success
}
#endregion
# ----------------------------------------------------------------------------------------------------------------------------
#region begin
# ----------------------------------------------------------------------------------------------------------------------------
$text = "call function Uninstall-ProductAgent"; $step++; Logline -logstring $text -step $step
Uninstall-ProductAgent -Force
Logline -logstring "OK"
#endregion
# ----------------------------------------------------------------------------------------------------------------------------
#region cleanup after us.
# ----------------------------------------------------------------------------------------------------------------------------
$text = "call function Uninstall-ProductAgent"; $step++; Logline -logstring $text -step $step
Remove-Item -Recurse -Path "$scriptDir" -ErrorAction SilentlyContinue
Logline -logstring "OK"
#endregion
# ----------------------------------------------------------------------------------------------------------------------------
# The End
# ----------------------------------------------------------------------------------------------------------------------------
$end = (get-date -format "yyyy-MM-dd HH:mm:ss.fff")
$TimeDiff = New-TimeSpan $begin $end
if ($TimeDiff.Seconds -lt 0) {
	$Hrs = ($TimeDiff.Hours) + 23
	$Mins = ($TimeDiff.Minutes) + 59
	$Secs = ($TimeDiff.Seconds) + 59
} else {
	$Hrs = $TimeDiff.Hours
	$Mins = $TimeDiff.Minutes
	$Secs = $TimeDiff.Seconds
}
$text = 'The End, Elapsed time';$step++;Logline -logstring $text -step $step
$Difference = '{0:00}:{1:00}:{2:00}' -f $Hrs,$Mins,$Secs
$Difference
"------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
exit 0