$defaultErrorActionPreference = 'SilentlyContinue'
$global:ErrorActionPreference = $defaultErrorActionPreference
$global:VerbosePreference = "SilentlyContinue"  # Disable verbose logging
<# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
#   V1.3
#                                                                             dddddddd
#   kkkkkkkk                                                                  d::::::d                                        lllllll
#   k::::::k                                                                  d::::::d                                        l:::::l
#   k::::::k                                                                  d::::::d                                        l:::::l
#   k::::::k                                                                  d:::::d                                         l:::::l
#   k:::::k    kkkkkkkyyyyyyy           yyyyyyynnnn  nnnnnnnn        ddddddddd:::::drrrrr   rrrrrrrrryyyyyyy           yyyyyyyl::::l
#   k:::::k   k:::::k  y:::::y         y:::::y n:::nn::::::::nn    dd::::::::::::::dr::::rrr:::::::::ry:::::y         y:::::y l::::l
#   k:::::k  k:::::k    y:::::y       y:::::y  n::::::::::::::nn  d::::::::::::::::dr:::::::::::::::::ry:::::y       y:::::y  l::::l
#   k:::::k k:::::k      y:::::y     y:::::y   nn:::::::::::::::nd:::::::ddddd:::::drr::::::rrrrr::::::ry:::::y     y:::::y   l::::l
#   k::::::k:::::k        y:::::y   y:::::y      n:::::nnn:::::nd::::::d    d:::::d r:::::r     r:::::r y:::::y   y:::::y    l::::l
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
# ${DisplayName}AgentUninstall.ps1  :      project de-tooling
#
# Objective:
#
# 2025-03-13  Initial release ( Benny.Skov@kyndryl.dk )
#
#>
# ----------------------------------------------------------------------------------------------------------------------------
# begining - INIT
# ----------------------------------------------------------------------------------------------------------------------------
[int]$psvers = $PSVersionTable.PSVersion | select-object -ExpandProperty major
$global:begin = (get-date -format "yyyy-MM-dd HH:mm:ss.fff")
$global:hostname = hostname
$global:hostname = $hostname.ToLower()
# Use try-catch for Get-WmiObject to avoid auto-import issues in restricted environments
try {
    if (Test-CmdletAvailable "Get-WmiObject") {
        $global:hostIp = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPENABLED=TRUE -ErrorAction SilentlyContinue | Select-Object IPAddress | select-object -expandproperty IPAddress | select-object -first 1
    }
    else {
        $global:hostIp = "Unknown"
    }
}
catch {
    $global:hostIp = "Unknown"
}
$global:scriptPath = $myinvocation.mycommand.Path
$global:scriptName = [System.Text.RegularExpressions.Regex]::Replace($scriptName, ".ps1", "")
$global:scriptPath = [System.Text.RegularExpressions.Regex]::Replace($scriptPath, "\\", "/")
$global:scriptarray = $scriptPath.split("/")
$global:scriptTOP = $scriptarray[0..($scriptarray.Count - 3)] -join "/"
$global:scriptDir = "${scriptTOP}/scripts"
$global:scriptBin = "${scriptTOP}/bin"
$global:logfile = "${scriptDir}/${scriptName}.log"
if (Test-Path $logfile) { Remove-Item -Path $logfile -Force -ErrorAction SilentlyContinue }
$global:continue = $true
# ----------------------------------------------------------------------------------------------------------------------------
#
# settings for ITM6 agent uninstall
#
# ----------------------------------------------------------------------------------------------------------------------------
$global:UninstName = 'ITMRmvAll.exe'
$global:DisplayName = 'monitoring Agent'
$global:ServiceName = '^k.*'
$global:CommandLine = '^C:\\IBM.ITM\\.*\\K*'
$global:UninstPath = "${scriptBin}/${UninstName}"
$global:UninstCmdexec = "start /WAIT /MIN ${UninstPath} -batchrmvall -removegskit"
$global:DisableService = $false
$global:step = 0
$global:RegistryKeys = @(
    "HKLM:\SOFTWARE\Candle",
    "HKLM:\SOFTWARE\Wow6432Node\Candle",
    "HKLM:\SYSTEM\CurrentControlSet\Services\Candle",
    "HKLM:\SYSTEM\CurrentControlSet\Services\IBM\ITM",
    "HKLM:\SOFTWARE\IBM\ITM",
    "HKLM:\SOFTWARE\Wow6432Node\IBM\ITM",
    "HKLM:\SOFTWARE\IBM\Tivoli",
    "HKLM:\SOFTWARE\Wow6432Node\IBM\Tivoli"
)
$global:RemoveDirs = @(
    "C:/IBM/ITM",
    "C:/ansible_workdir",
    "C:/ProgramData/BigFix",
    "C:/ProgramData/ansible",
    "C:/ProgramData/ilmt",
    "C:/PROGRA~1/BigFix",
    "C:/PROGRA~1/ansible",
    "C:/PROGRA~1/ilmt",
    "C:/chef"
)
# ----------------------------------------------------------------------------------------------------------------------------
# Logline
# ----------------------------------------------------------------------------------------------------------------------------
Function Logline {
    Param ([string]$logstring, $step)
    $now = (get-date -format "yyyy-MM-dd HH:mm:ss.fff")
    $text = ( "{0,-23} : $hostname : step {1:d4} : {2}" -f $now, $step, $logstring)
    if ($logstring -match "error|fail|exception|not found") {
        Write-Host $text -ForegroundColor Red
    }
    elseif ($logstring -match "warning") {
        Write-Host $text -ForegroundColor Yellow
    }
    elseif ($logstring -match "success|done|complete") {
        Write-Host $text -ForegroundColor Green
    }
    else {
        Write-Host $text -ForegroundColor Cyan
    }
    Add-Content -Path $logfile -Value $text
}
$text = "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"; Logline -logstring $text -step $step
$text = "begin:             " + $begin; Logline -logstring $text -step $step
$text = "psvers:            " + $psvers; Logline -logstring $text -step $step
$text = "hostname:          " + $hostname; Logline -logstring $text -step $step
$text = "hostIp:            " + $hostIp; Logline -logstring $text -step $step
$text = "scriptName:        " + $scriptName; Logline -logstring $text -step $step
$text = "scriptPath:        " + $scriptPath; Logline -logstring $text -step $step
$text = "scriptDir:         " + $scriptDir; Logline -logstring $text -step $step
$text = "scriptBin:         " + $scriptBin; Logline -logstring $text -step $step
$text = "logfile:           " + $logfile; Logline -logstring $text -step $step
$text = "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"; Logline -logstring $text -step $step
$text = "UninstName:        " + $UninstName; Logline -logstring $text -step $step
$text = "DisplayName:       " + $DisplayName; Logline -logstring $text -step $step
$text = "ServiceName:       " + $ServiceName; Logline -logstring $text -step $step
$text = "CommandLine:       " + $CommandLine; Logline -logstring $text -step $step
$text = "UninstPath:        " + $UninstPath; Logline -logstring $text -step $step
$text = "UninstCmdexec:     " + $UninstCmdexec; Logline -logstring $text -step $step
$text = "DisableService:    " + $DisableService; Logline -logstring $text -step $step
foreach ( $key in $RegistryKeys ) {
    $text = "registry key to be removed: " + $key; Logline -logstring $text -step $step
}
foreach ( $dir in $global:RemoveDirs ) {
    $text = "directory to be removed: " + $dir; Logline -logstring $text -step $step
}
$text = "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"; Logline -logstring $text -step $step

# Step 1: Collect ITM status report
Get-ITMStatusReport

# Step 2: Stop and disable ITM services
$text = "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"; Logline -logstring $text -step $step
$text = "Step 2: Stop and disable ITM services"; Logline -logstring $text -step $step
Stop-ProductAgent

# Step 3: Uninstall ITM product agent
$text = "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"; Logline -logstring $text -step $step
$text = "Step 3: Uninstall ITM product agent"; Logline -logstring $text -step $step
Uninstall-ProductAgent

# Step 4: Clean up registry entries
$text = "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"; Logline -logstring $text -step $step
$text = "Step 4: Clean up registry entries"; Logline -logstring $text -step $step
Test-CleanupRegistry

# Step 5: Remove additional directories
$text = "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"; Logline -logstring $text -step $step
$text = "Step 5: Remove additional directories"; Logline -logstring $text -step $step
Remove-AdditionalDirectories

# Final verification
$text = "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"; Logline -logstring $text -step $step
$text = "Final verification of ITM removal"; Logline -logstring $text -step $step
Get-ITMStatusReport

# Completion message
$text = "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"; Logline -logstring $text -step $step
$text = "ITM removal process completed. Please review the log for details."; Logline -logstring $text -step $step
$text = "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"; Logline -logstring $text -step $step