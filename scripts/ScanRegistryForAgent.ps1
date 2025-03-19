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
$scriptPath     = [System.Text.RegularExpressions.Regex]::Replace($scriptPath, "\\", "/")
$scriptarray    = $scriptPath.split("/")
$scriptDir      = $scriptarray[0..($scriptarray.Count - 2)] -join "/"
$binDir         = [System.Text.RegularExpressions.Regex]::Replace($scriptDir, "scripts$", "bin")
$logfile        = "${scriptDir}/${scriptName}.log"
if (-not (Test-Path -Path ${scriptDir})) {
    try {
        New-Item -Path ${scriptDir} -ItemType Directory -Force | Out-Null
        $icaclsCmd = "icacls `"${scriptDir}`" /grant `"Users`":`(OI`)`(CI`)F"
        $result = Invoke-Expression $icaclsCmd
        $text = "Created directory ${scriptDir} and set permissions"; Logline -logstring $text
    } catch {
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
"binDir:            " + $binDir
"logfile:           " + $logfile
"Powershell ver:    " + $psvers
"------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
Function Logline {
    Param ([string]$logstring, $step)
    $now = (get-date -format "yyyy-MM-dd HH:mm:ss.fff")
    $text = ( "{0,-23} : $hostname : step {1:d4} : {2}" -f $now, $step, $logstring)
    Add-content -LiteralPath $Logfile -value $text
    Write-Host $text
}

# Add IBM and ITM registry keys to the removal list
$text = "Searching registry for IBM, Candle, and ITM related keys"; Logline -logstring $text -step $step
# Search for additional registry keys
$registryHives = @("HKLM:")
$searchPatterns = @("*candle*", "*IBM*", "*ITM*")

foreach ($hive in $registryHives) {
    foreach ($pattern in $searchPatterns) {
        try {
            $foundKeys = Get-ChildItem -Path $hive -Recurse -ErrorAction SilentlyContinue |
                            Where-Object { $_.Name -like $pattern } |
                            Select-Object -ExpandProperty PSPath

            foreach ($key in $foundKeys) {
                if ($key -notmatch "uninstall" -and $key -notmatch "installer" -and $key -notmatch "WindowsUpdate") {
                    if ($regKeys -notcontains $key) {
                        $text = "Found additional key to remove: $key"; Logline -logstring $text -step $step
                        $regKeys += $key
                    }
                }
            }
        }
        catch {
            $text = "Error searching registry for $pattern : $_"; Logline -logstring $text -step $step
        }
    }
}
# ----------------------------------------------------------------------------------------------------------------------------
# The End
# ----------------------------------------------------------------------------------------------------------------------------
$end = (get-date -format "yyyy-MM-dd HH:mm:ss.fff")
$TimeDiff = New-TimeSpan $begin $end
if ($TimeDiff.Seconds -lt 0) {
    $Hrs = ($TimeDiff.Hours) + 23
    $Mins = ($TimeDiff.Minutes) + 59
    $Secs = ($TimeDiff.Seconds) + 59
}
else {
    $Hrs = $TimeDiff.Hours
    $Mins = $TimeDiff.Minutes
    $Secs = $TimeDiff.Seconds
}
$text = 'The End, Elapsed time'; $step++; Logline -logstring $text -step $step
$Difference = '{0:00}:{1:00}:{2:00}' -f $Hrs, $Mins, $Secs
$Difference
"------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
exit 0