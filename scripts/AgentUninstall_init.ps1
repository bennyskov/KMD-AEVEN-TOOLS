# ----------------------------------------------------------------------------------------------------------------------------
# begining - INIT
# ----------------------------------------------------------------------------------------------------------------------------
[int]$psvers        = $PSVersionTable.PSVersion | select-object -ExpandProperty major
$global:begin       = (get-date -format "yyyy-MM-dd HH:mm:ss.fff")
$global:hostname    = hostname
$global:hostname    = $hostname.ToLower()
$global:hostIp      = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPENABLED=TRUE | Select-Object IPAddress | select-object -expandproperty IPAddress | select-object -first 1
$global:scriptName  = $myinvocation.mycommand.Name
$global:scriptPath  = $myinvocation.mycommand.Path
$global:scriptName  = [System.Text.RegularExpressions.Regex]::Replace($scriptName, ".ps1", "")
$global:scriptDir   = [System.Text.RegularExpressions.Regex]::Replace($scriptPath, "\\", "/")
$global:scriptarray = $scriptDir.split("/")
$global:scriptDir   = $scriptarray[0..($scriptarray.Count-2)] -join "/"
$global:scriptBin   = "${scriptDir}/bin"
$global:icaclsCmd   = "icacls `"${scriptDir}`" /grant `"Users`":`(OI`)`(CI`)F"
$null               = Invoke-Expression $icaclsCmd
$global:logfile     = "${scriptDir}/${scriptName}.log"; if (Test-Path -Path $logfile) { remove-item -Path $logfile -Force }
$global:continue    = $true
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
