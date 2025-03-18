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
function Remove-BlockedPath {
    param (
        [string]$path,
        [string]$blockedFilePath = $null,
        [int]$depth = 0
    )

    if ($depth -gt 3) {
        $text = "Maximum retry depth reached for path: $path"; Logline -logstring $text -step $step
        return $false
    }

    # Try to delete the path
    try {
        $text = "Attempting to remove: $path (depth: $depth)"; Logline -logstring $text -step $step
        Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
        $text = "Successfully removed: $path"; Logline -logstring $text -step $step
        return $true
    }
    catch {
        # Extract blocked file path if not already known
        if (-not $blockedFilePath) {
            $errorMsg = $_.ToString()
            $filePathMatch = [regex]::Match($errorMsg, "Cannot remove item (.*?): The process cannot access the file")
            if ($filePathMatch.Success) {
                $blockedFilePath = $filePathMatch.Groups[1].Value
                $text = "Found blocked file: $blockedFilePath"; Logline -logstring $text -step $step
            }
        }

        if ($blockedFilePath) {
            # Run handle on blocked file
            $handleCmd = "${binDir}/handle `"$blockedFilePath`" -accepteula -nobanner"
            $handleResult = & cmd /C $handleCmd 2>&1
            Logline -logstring "Handle result: $handleResult" -step $step

            # Parse handle output
            $handleRegex = [regex]::Match($handleResult, "pid:\s*(\d+).*?type:\s*File\s*([0-9A-F]+):")
            if ($handleRegex.Success) {
                $processId = $handleRegex.Groups[1].Value.Trim()
                $handleId = $handleRegex.Groups[2].Value.Trim()

                # Close handle
                $cmdexec = "${binDir}/handle -c $handleId -y -p ${processId} -accepteula -nobanner"
                Logline -logstring "Executing: $cmdexec" -step $step
                $closeResult = & cmd /C $cmdexec 2>&1
                Logline -logstring $closeResult -step $step

                # Recursive call to retry deletion
                return Remove-BlockedPath -path $path -blockedFilePath $null -depth ($depth + 1)
            }
        }

        $text = "Failed to remove: $path - $_"; Logline -logstring $text -step $step
        return $false
    }
}
function Test-CleanupProductFiles {
    Param ([int32]$step)

    $isAllDoneOK = $true
    $filesNotRemoved = @()

    $dirPaths = @(
        "C:/Temp/scanner_logs",
        "C:/Temp/jre",
        "C:/Temp/report",
        "C:/Temp/exclude_config.txt",
        "C:/Temp/Get-Win-Disks-and-Partitions.ps1",
        "C:/Temp/log4j2-scanner-2.6.5.jar",
        "C:/salt",
        "C:/IBM/ITM/TMAITM6_x64/logs"
    )
    # "D:/scripts/tview/build/logs/systems"

    $text = "cleanup all product files, if uninstall didnt do it"; $step++; Logline -logstring $text -step $step
    foreach ($path in $dirPaths) {
        $path = [System.Text.RegularExpressions.Regex]::Replace($path, "\\", "/")
        if (Test-Path $path) {
            $text = "Attempting to remove directory: $path"; Logline -logstring $text -step $step
            $result = Remove-BlockedPath -path $path
            if (-not $result) {
                $filesNotRemoved += $path
                $isAllDoneOK = $false
            }
        } else {
            $text = "Path does not exist: $path"; Logline -logstring $text -step $step
        }

        if ( $isAllDoneOK ) {
            $result = 'success. All Agents files are removed'
            Logline -logstring $result -step $step
        } else {
            if ( $filesNotRemoved.Count -gt 0 ) {
                $text = "filesNotRemoved="+$filesNotRemoved.Count; Logline -logstring $text -step $step
                foreach ($path in $filesNotRemoved) {
                    Logline -logstring $line -step $step
                }
            }
        }
    }
    return $isAllDoneOK
}
$result = Test-CleanupProductFiles -step 0
$result