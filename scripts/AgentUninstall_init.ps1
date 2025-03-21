# ----------------------------------------------------------------------------------------------------------------------------
# begining - INIT
# ----------------------------------------------------------------------------------------------------------------------------
[int]$psvers        = $PSVersionTable.PSVersion | select-object -ExpandProperty major
$global:begin       = (get-date -format "yyyy-MM-dd HH:mm:ss.fff")
$global:hostname    = hostname
$global:hostname    = $hostname.ToLower()
$global:hostIp      = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPENABLED=TRUE | Select-Object IPAddress | select-object -expandproperty IPAddress | select-object -first 1
$global:scriptPath  = $myinvocation.mycommand.Path
$global:scriptName  = [System.Text.RegularExpressions.Regex]::Replace($scriptName, ".ps1", "")
$global:scriptPath  = [System.Text.RegularExpressions.Regex]::Replace($scriptPath, "\\", "/")
$global:scriptarray = $scriptPath.split("/")
$global:scriptDir   = $scriptarray[0..($scriptarray.Count-2)] -join "/"
$global:scriptBin   = "${scriptDir}/bin"
$global:logfile     = "${scriptDir}/${scriptName}.log"
if (Test-Path $logfile) { Remove-Item -Path $logfile -Force }
$global:continue    = $true
# ----------------------------------------------------------------------------------------------------------------------------
# Logline
# ----------------------------------------------------------------------------------------------------------------------------
Function Logline {
    Param ([string]$logstring, $step)
    $now = (get-date -format "yyyy-MM-dd HH:mm:ss.fff")
    $text = ( "{0,-23} : $hostname : step {1:d4} : {2}" -f $now, $step, $logstring)
    Add-content -LiteralPath $Logfile -value $text -Force
    Write-Host $text
}
# ----------------------------------------------------------------------------------------------------------------------------
# display vars
# ----------------------------------------------------------------------------------------------------------------------------
$text = "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"; Logline -logstring $text -step $step
$text = "begin:             " + $begin; Logline -logstring $text -step $step
$text = "psvers:            " + $psvers; Logline -logstring $text -step $step
$text = "hostname:          " + $hostname; Logline -logstring $text -step $step
$text = "hostIp:            " + $hostIp; Logline -logstring $text -step $step
$text = "scriptName:        " + $scriptName; Logline -logstring $text -step $step
$text = "scriptPath:        " + $scriptPath; Logline -logstring $text -step $step
$text = "scriptDir:         " + $scriptDir; Logline -logstring $text -step $step
$text = "logfile:           " + $logfile; Logline -logstring $text -step $step
$text = "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"; Logline -logstring $text -step $step
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
foreach ( $dir in $RemoveDirs ) {
    $text = "directory to be removed: " + $dir; Logline -logstring $text -step $step
}
$text = "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"; Logline -logstring $text -step $step
