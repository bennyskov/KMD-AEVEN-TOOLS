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
# HPOMAgentUninstall.ps1  :      project de-tooling
#
#
# Objective:
# for this script is to do a complete uninstall of HPOM agent and all legacy versions, if any on a given server.
# also check and uninstall if any legacy versions. But do not uninstall if a opentext version exists on server.
# the script is uploaded to a server and started remotely by a automation tool like ansible
#
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
function Test-HPOMAgentUninstalled {
    $agentExists = Test-Path "C:/PROGRA~1/HP/HP BTO Software"
    $serviceExists = Get-Service "ovctrl" -ErrorAction SilentlyContinue

    return -not ($agentExists -or $serviceExists)
}
#endregion
$text = "Set initial parms"; $step++; Logline -logstring $text -step $step
Lognewline -logstring "OK"

function Uninstall-HPOMAgent {
    param(
        [switch]$Force
    )


    $text = "stop ovc agent - opcagt -kill"; $step++; Logline -logstring $text -step $step
    Lognewline -logstring "begin"
    $program = "C:/PROGRA~1/HP/HP BTO Software/bin/win64/opcagt.bat"
    if (Test-Path "$program") {
        $text = "stopping agent using opcagt"; Lognewline -logstring $text
        $cmdexec = @("`"${program}`"", "-kill")
        write-host $cmdexec
        $result = & cmd /C $cmdexec 2>&1
        $rc = $?
        if ( $rc ) {
            write-host "rc=$rc result=$result"
        }
        else {
            write-host "rc=$rc result=$result"
        }
        $text = "opcagt exit code: $($result.ExitCode)"; Lognewline -logstring $text
    }


    $text = "uninstall ovc agent"; $step++; Logline -logstring $text -step $step
    Lognewline -logstring "begin"
    $possiblePaths = @(
        "C:/PROGRA~1/HP/HP BTO Software/bin/win64/OpC/install/oainstall.vbs",
        "C:/Program Files/HP/HP BTO Software/bin/win64/OpC/install/oainstall.vbs",
        "C:/Program Files (x86)/HP/HP BTO Software/bin/win64/OpC/install/oainstall.vbs"
    )

    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $program = $path
            break
        }
    }
    if (Test-Path "$program") {
        $text = " oainstall"; Lognewline -logstring $text
        $cmdexec = @("cscript", "`"${program}`"", "-remove", "-force")
        write-host $cmdexec
        $result = & cmd /C $cmdexec 2>&1
        $rc = $?
        if ( $rc ) {
            write-host "rc=$rc result=$result"
        }
        else {
            write-host "rc=$rc result=$result"
        }
        $text = "opcagt exit code: $($result.ExitCode)"; Lognewline -logstring $text
    }

    $clientPaths = @(
        "C:/PROGRA~1/Hewlett-Packard/Discovery Agent",
        "C:/PROGRA~2/Hewlett-Packard/Discovery Agent"
    )

    $text = "Force removal of client directory if found"; $step++; Logline -logstring $text -step $step
    Lognewline -logstring "begin"
    foreach ($path in $clientPaths) {
        if (Test-Path $path) {
            try {
                $text = "Force removing directory: $path"; Lognewline -logstring $text
                Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            } catch {
                $text = "Error removing $path : $_"; Lognewline -logstring $text
            }
        }
    }

    #     $regKeys = @(
    #         "HKLM:\SOFTWARE\Microsoft\CCM",
    #         "HKLM:\SOFTWARE\Microsoft\SMS",
    #         "HKLM:\SOFTWARE\Microsoft\CCMSetup",
    #         "HKLM:\SOFTWARE\Wow6432Node\Microsoft\CCM",
    #         "HKLM:\SOFTWARE\Wow6432Node\Microsoft\SMS",
    #         "HKLM:\SOFTWARE\Wow6432Node\Microsoft\CCMSetup"
    #     )

    #     $text = "Clean up registry"; $step++; Logline -logstring $text -step $step
    #     Lognewline -logstring "begin"
    #     foreach ($key in $regKeys) {
    #         if (Test-Path $key) {
    #             try {
    #                 $text = "Removing registry key: $key";Lognewline -logstring $text
    #                 Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
    #             } catch {
    #                 $text = "Error removing registry key $key : $_";Lognewline -logstring $text
    #             }
    #         }
    #     }


    return $success
}


    if (Test-HPOMAgentUninstalled) {
        $text = "HP Operations Manager Agent uninstall successful"; Lognewline -logstring $text
        $success = $true
    } else {
        $text = "HP Operations Manager Agent may not be completely uninstalled"; Lognewline -logstring $text
        $success = $false
    }
#endregion
# ----------------------------------------------------------------------------------------------------------------------------
#region begin
# ----------------------------------------------------------------------------------------------------------------------------
$text = "call function Uninstall-HPOMAgent"; $step++; Logline -logstring $text -step $step
Lognewline -logstring "begin"
Uninstall-HPOMAgent -Force
#endregion
# ----------------------------------------------------------------------------------------------------------------------------
#region cleanup
# ----------------------------------------------------------------------------------------------------------------------------
Remove-Item -Path $scriptpath -ErrorAction SilentlyContinue
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