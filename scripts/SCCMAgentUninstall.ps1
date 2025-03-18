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
# SCCMAgentUninstall.ps1  :      project de-tooling
#
# Objective:
# for this script is to do a complete uninstall of SCCM agent and all legacy versions, if any on a given server.
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
$windir         = "$env:WINDIR/Temp"
$scriptName     = $myinvocation.mycommand.Name
$scriptpath     = $myinvocation.mycommand.Path
$scriptName     = [System.Text.RegularExpressions.Regex]::Replace($scriptName, ".ps1", "")
$scriptDir      = [System.Text.RegularExpressions.Regex]::Replace($scriptpath, "\\", "/")
$scriptarray    = $scriptDir.split("/")
$scriptDir      = $scriptarray[0..($scriptarray.Count-2)] -join "/"
$project        = "de-tooling"
$tempDir        = "${scriptDir}"
$logfile        = "${scriptDir}/${scriptName}.log"
if (-not (Test-Path -Path ${tempDir})) {
    try {
        New-Item -Path ${tempDir} -ItemType Directory -Force | Out-Null
        $icaclsCmd = "icacls `"${tempDir}`" /grant `"Users`":`(OI`)`(CI`)F"
        $result = Invoke-Expression $icaclsCmd
        $text = "Created directory ${tempDir} and set permissions"; Lognewline -logstring $text
    }
    catch {
        $text = "Error creating directory ${tempDir}: $_"; Lognewline -logstring $text
    }
}
remove-item -Path $logfile -Force -ErrorAction SilentlyContinue
"------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
"begin:             " + $begin
"hostname:          " + $hostname
"hostIp:            " + $hostIp
"windir:            " + $windir
"scriptName:        " + $scriptName
"scriptpath:        " + $scriptpath
"scriptDir:         " + $scriptDir
"project:           " + $project
"function:          " + $function
"tempDir:           " + $tempDir
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
    if ( $psvers -gt 4 ) {
        Add-content -NoNewline -LiteralPath $Logfile -value $text
        Write-Host -NoNewline $text
    } else {
        Add-content -LiteralPath $Logfile -value ""
        Add-content -LiteralPath $Logfile -value $text
        Write-Host
        Write-Host $text
    }
}
Function Lognewline
{
Param ([string]$logstring)
    Add-content -LiteralPath $Logfile -value $logstring
    Write-Host $logstring
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
function remove-host([string]$filename, [string]$hostname) {
    $c = Get-Content $filename
    $newLines = @()
    foreach ($line in $c) {
        if ( $line -notmatch $ip) { $newLines += $line }
    }

    # Write file
    $ErrorActionPreference = 'Stop'
    Clear-Content $filename
    foreach ($line in $newLines) {
        $line | Out-File -encoding ASCII -append $filename
    }
    $ErrorActionPreference = 'Continue'
}
function print_hostfile([string]$filename) {
    $c = Get-Content $filename
    foreach ($line in $c) {
        Write-Host $line
    }
}
function Test-SCCMUninstalled {
    $filesExist = Test-Path "$env:WinDir\CCM\CcmExec.exe"
    $serviceExists = Get-Service "CcmExec" -ErrorAction SilentlyContinue
    $processExists = Get-Process "CcmExec" -ErrorAction SilentlyContinue

    return -not ($filesExist -or $serviceExists -or $processExists)
}
#endregion
$text = "Set initial parms"; $step++; Logline -logstring $text -step $step
Lognewline -logstring "OK"

function Uninstall-SCCMAgent {
    param(
        [switch]$Force,
        [switch]$NoReboot
    )

    $hostsFile = "${windir}\system32\Drivers\etc\hosts"
    $text = "cleanup old entries in ${hostsFile}"; $step++; Logline -logstring $text -step $step
    Lognewline -logstring "begin"
    $null = remove-host $hostsFile kmdwinccm003
    $null = remove-host $hostsFile kmdwinccm004
    $null = remove-host $hostsFile kmdwinccm005
    print_hostfile $hostsFile

    $text = "Stop old ccmsetup.exe if hanging from last run"; $step++; Logline -logstring $text -step $step
    Lognewline -logstring "begin"
    $result = Get-WmiObject Win32_Process -Filter "name = 'ccmsetup.exe'" | Select-Object ProcessId, CommandLine | Where-Object { $_.CommandLine -like "*ccmsetup.exe*" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -PassThru -ErrorAction Stop -Verbose }
    $text = "Stop services first"; $step++; Logline -logstring $text -step $step
    Lognewline -logstring "begin"
    $services = @("CcmExec", "SMS Agent Host", "ccmsetup")
    foreach ($service in $services) {
        try {
            $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
            if ($svc) {
                $text = "Stopping service: $service";Lognewline -logstring $text
                Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
            }
        } catch {
            $text = "Error stopping service $service : $_";Lognewline -logstring $text
        }
    }

    $text = "Kill any running processes"; $step++; Logline -logstring $text -step $step
    Lognewline -logstring "begin"
    $processes = @("ccmexec.exe", "ccmsetup.exe", "ccmrepair.exe")
    foreach ($process in $processes) {
        try {
            Get-Process -Name ($process -replace '\.exe$', '') -ErrorAction SilentlyContinue |
                Stop-Process -Force -ErrorAction SilentlyContinue
            $text = "Terminated process if running: $process";Lognewline -logstring $text
        } catch {
            $text = "Error stopping process $process : $_";Lognewline -logstring $text
        }
    }

    $text = "Method 1: Use ccmsetup.exe /uninstall"; $step++; Logline -logstring $text -step $step
    Lognewline -logstring "begin"
    if (Test-Path "$env:WinDir\ccmsetup\ccmsetup.exe") {
        $text = "Uninstalling using ccmsetup.exe";Lognewline -logstring $text
        $result = Start-Process -FilePath "$env:WinDir\ccmsetup\ccmsetup.exe" -ArgumentList "/uninstall" -Wait -PassThru
        $text = "ccmsetup /uninstall exit code: $($result.ExitCode)";Lognewline -logstring $text
    }

    $text = "Method 2: Use WMIC (for older systems)"; $step++; Logline -logstring $text -step $step
    Lognewline -logstring "begin"
    try {
        $text = "Attempting uninstall via WMI";Lognewline -logstring $text
        $result = Invoke-Expression "wmic product where 'name like ""Configuration Manager Client""' call uninstall /nointeractive"
        $text = "WMI uninstall attempted";Lognewline -logstring $text
    } catch {
        $text = "WMI uninstall error: $_";Lognewline -logstring $text
    }

    $text = "Method 3: MsiExec for direct uninstall (if other methods fail)"; $step++; Logline -logstring $text -step $step
    Lognewline -logstring "begin"
    try {
        $clientMsi = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*Configuration Manager Client*" }
        if ($clientMsi) {
            $text = "Uninstalling via MSI: $($clientMsi.Name)";Lognewline -logstring $text
            $result = $clientMsi.Uninstall()
            $text = "MSI uninstall result: $($result.ReturnValue)";Lognewline -logstring $text
        }
    } catch {
        $text = "MSI uninstall error: $_";Lognewline -logstring $text
    }

    if ($Force) {
        $clientPaths = @(
            "$env:WinDir\CCM",
            "$env:WinDir\ccmsetup",
            "$env:WinDir\ccmcache",
            "$env:ProgramData\Microsoft\CCMSETUP",
            "$env:ProgramData\Microsoft\CCM"
        )

        $text = "Force removal of client directory if requested"; $step++; Logline -logstring $text -step $step
        Lognewline -logstring "begin"
        foreach ($path in $clientPaths) {
            if (Test-Path $path) {
                try {
                    $text = "Force removing directory: $path";Lognewline -logstring $text
                    Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                } catch {
                    $text = "Error removing $path : $_";Lognewline -logstring $text
                }
            }
        }

        $regKeys = @(
            "HKLM:\SOFTWARE\Microsoft\CCM",
            "HKLM:\SOFTWARE\Microsoft\SMS",
            "HKLM:\SOFTWARE\Microsoft\CCMSetup",
            "HKLM:\SOFTWARE\Wow6432Node\Microsoft\CCM",
            "HKLM:\SOFTWARE\Wow6432Node\Microsoft\SMS",
            "HKLM:\SOFTWARE\Wow6432Node\Microsoft\CCMSetup"
        )

        $text = "Clean up registry"; $step++; Logline -logstring $text -step $step
        Lognewline -logstring "begin"
        foreach ($key in $regKeys) {
            if (Test-Path $key) {
                try {
                    $text = "Removing registry key: $key";Lognewline -logstring $text
                    Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
                } catch {
                    $text = "Error removing registry key $key : $_";Lognewline -logstring $text
                }
            }
        }

        $text = "Remove WMI namespaces"; $step++; Logline -logstring $text -step $step
        Lognewline -logstring "begin"
        try {
            $text = "Removing CCM WMI namespaces";Lognewline -logstring $text
            Get-WmiObject -Query "SELECT * FROM __Namespace WHERE Name='CCM'" -Namespace "root" -ErrorAction SilentlyContinue |
                Remove-WmiObject -ErrorAction SilentlyContinue
            Get-WmiObject -Query "SELECT * FROM __Namespace WHERE Name='SMSDM'" -Namespace "root\cimv2" -ErrorAction SilentlyContinue |
                Remove-WmiObject -ErrorAction SilentlyContinue
        } catch {
            $text = "Error removing WMI namespaces: $_";Lognewline -logstring $text
        }
    }

    $text = "Check if uninstallation was successful"; $step++; Logline -logstring $text -step $step
    Lognewline -logstring "begin"
    $success = -not (Test-Path "$env:WinDir\CCM\CcmExec.exe")
    if ($success) {
        $text = "SCCM client uninstallation appears successful";Lognewline -logstring $text
    } else {
        $text = "SCCM client may still be installed. Consider using -Force parameter";Lognewline -logstring $text
    }

    if (-not $NoReboot -and (Test-Path HKLM:\SYSTEM\CurrentControlSet\Control\Session` Manager\PendingFileRenameOperations)) {
        $text = "System restart required to complete uninstallation"; Lognewline -logstring $text
        Restart-Computer -Force
    }

    return $success
}
#endregion
# ----------------------------------------------------------------------------------------------------------------------------
#region begin
# ----------------------------------------------------------------------------------------------------------------------------
$text = "call function Uninstall-SCCMAgent"; $step++; Logline -logstring $text -step $step
Lognewline -logstring "begin"
Uninstall-SCCMAgent -Force
#endregion
# ----------------------------------------------------------------------------------------------------------------------------
#region set parm
# ----------------------------------------------------------------------------------------------------------------------------
$text = "Set initial parms";$step++;Logline -logstring $text -step $step
Lognewline -logstring "OK"
#endregion
# ----------------------------------------------------------------------------------------------------------------------------
#region cleanup
# ----------------------------------------------------------------------------------------------------------------------------
Remove-Item -Recurse -Path "$scriptDir" -ErrorAction SilentlyContinue
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