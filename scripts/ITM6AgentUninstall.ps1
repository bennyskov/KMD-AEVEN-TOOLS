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
# ${DisplayName}AgentUninstall.ps1  :      project de-tooling
#
# Objective:
# for this script is to do a complete uninstall of ${DisplayName} agent and all legacy versions, if any on a given server.
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
        $text = "Created directory ${scriptDir} and set permissions"; Logline -logstring $text -step $step
    }
    catch {
        $text = "Error creating directory ${scriptDir}: $_"; Logline -logstring $text -step $step
    }
}
remove-item -Path $logfile -Force -ErrorAction SilentlyContinue
$text = "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"; Logline -logstring $text -step $step
$text = "begin:             " + $begin;         Logline -logstring $text -step $step
$text = "Powershell ver:    " + $psvers;        Logline -logstring $text -step $step
$text = "hostname:          " + $hostname;      Logline -logstring $text -step $step
$text = "hostIp:            " + $hostIp;        Logline -logstring $text -step $step
$text = "scriptName:        " + $scriptName;    Logline -logstring $text -step $step
$text = "scriptPath:        " + $scriptPath;    Logline -logstring $text -step $step
$text = "scriptDir:         " + $scriptDir;     Logline -logstring $text -step $step
$text = "logfile:           " + $logfile;       Logline -logstring $text -step $step
$text = "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"; Logline -logstring $text -step $step
# ----------------------------------------------------------------------------------------------------------------------------
#region functions
# ----------------------------------------------------------------------------------------------------------------------------
Function Logline {
    Param ([string]$logstring, $step)
    $now = (get-date -format "yyyy-MM-dd HH:mm:ss.fff")
    $text = ( "{0,-23} : $hostname : step {1:d4} : {2}" -f $now, $step, $logstring)
    Add-content -LiteralPath $Logfile -value $text
    Write-Host $text
}
function Test-lastUninstall {
    Param (
        [string]$uninstName,
        [int32]$step
    )

    $continue = $true
    if ( [bool](Get-WmiObject Win32_Process -Filter "name = '${uninstName}'") ) {
        $text = "stop ${uninstName} if program is still running from last run."; $step++; Logline -logstring $text -step $step
        $result = Get-WmiObject Win32_Process -Filter "name = '${uninstName}'" | Select-Object ProcessId, CommandLine | Where-Object { $_.CommandLine -like "*ITMRmvAll.exe*" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -PassThru -ErrorAction Stop -Verbose }
        Logline -logstring $result -step $step

        Start-Sleep -Seconds 10

        if ( [bool](Get-WmiObject Win32_Process -Filter "name = '${uninstName}'") ) {
            $text = "${uninstName} is still running. We try stopping it using psKill"; Logline -logstring $result -step $step
            $cmdexec = "${scriptDir}/psKill -t $uninstName -accepteula -nobanner"
            Logline -logstring $cmdexec -step $step
            $result = & cmd /C $cmdexec 2>&1
            Logline -logstring $result -step $step

            Start-Sleep -Seconds 10

            if ( [bool](Get-WmiObject Win32_Process -Filter "name = '${uninstName}'") ) {
                $text = "${uninstName} is still running. We must break now"; Logline -logstring $result -step $step
                $continue = $false
            }
        }
    }
    return $continue
}
function Stop-ProductAgent {
    Param (
        [string]$ServiceName,
        [string]$DisplayName,
        [string]$CommandLine,
        [switch]$disable,
        [int32]$step
        )

    $IsAgentsStopped = $false

    if ( -not $IsAgentsStopped ) {
        $text = "stop Method 1: Stop all ${DisplayName} agents using Stop-Service"; $step++; Logline -logstring $text -step $step
        $servicesToStop = Get-Service | Where-Object { $_.Name -match '${ServiceName}' -and $_.DisplayName -match '${DisplayName}' } -ErrorAction SilentlyContinue
        $servicesToStop | Stop-Service -Force
        Start-Sleep -Seconds 10
        foreach ($service in $servicesToStop) {
            if ( $disable ) { $service | Set-Service -StartupType Disabled }
            $service | Stop-Service -force
            $result = $service | Get-Service
            Logline -logstring $result -step $step
        }
        if ( Test-IsAgentsStopped -eq $true ) { $IsAgentsStopped = $true }
    }

    if ( -not $IsAgentsStopped ) {
        $text = "stop Method 2: Stop ${DisplayName} using WMI Terminate"; $step++; Logline -logstring $text -step $step
        $ReturnValue = $(Get-WmiObject Win32_Process | Where-Object CommandLine -match '${CommandLine}' | ForEach-Object { $_.Terminate() }).ReturnValue
        if ($ReturnValue) {
            foreach ($rc in $ReturnValue) {
                if ( -not $rc -eq 0 ) {
                    Logline -logstring "terminating service rc=$rc" -step $step
                }
            }
        }
        if ( Test-IsAgentsStopped -eq $true ) { $IsAgentsStopped = $true }
    }

    if ( -not $IsAgentsStopped ) {
        $text = "stop Method 3: Stop ${DisplayName} using 'net stop service'"; $step++; Logline -logstring $text -step $step
        $servicesToStop = $(Get-Service | Where-Object { $_.Name -match '${ServiceName}' -and $_.DisplayName -match '${DisplayName}' }).Name
        foreach ($service in $servicesToStop) {
            $cmdexec = "net stop $service"
            $result = & cmd /C $cmdexec 2>&1
            Logline -logstring "$result"
        }
        if ( Test-IsAgentsStopped -eq $true ) { $IsAgentsStopped = $true }
    }

    if ( -not $IsAgentsStopped ) {
        $text = "stop Method 4: Stop ${DisplayName} using 'psKill service'"; $step++; Logline -logstring $text -step $step
        $servicesToKill = Get-Service | Where-Object { $_.Name -match '${ServiceName}' -and $_.DisplayName -match '${DisplayName}' } -ErrorAction SilentlyContinue
        foreach ($service in $servicesToKill) {
            $text = "${service} is still running. We try stopping it using psKill"; Logline -logstring $result -step $step
            $cmdexec = "${scriptDir}/psKill -t $service -accepteula -nobanner"
            Logline -logstring $cmdexec -step $step
            $result = & cmd /C $cmdexec 2>&1
            Logline -logstring $result -step $step
        }
        if ( Test-IsAgentsStopped -eq $true ) { $IsAgentsStopped = $true }
    }

    if ( -not $IsAgentsStopped ) {
        $text = "stop and disable services"; $step++; Logline -logstring $text -step $step
        $servicesToStop = Get-Service | Where-Object { $_.Name -match '${ServiceName}' -and $_.DisplayName -match '${DisplayName}' }
        foreach ($service in $servicesToStop) {
            if ( $disable ) { $service | Set-Service -StartupType Disabled }
            $service | Stop-Service -force
            $result = $service | Get-Service | format-table -autosize | Out-string -Width 300
            Logline -logstring "$result"
        }
        if ( Test-IsAgentsStopped -eq $true ) { $IsAgentsStopped = $true }
    }
    return $IsAgentsStopped
}
function Uninstall-ProductAgent {
    Param (
        [string]$DisplayName,
        [string]$uninstName,
        [int32]$step
    )

    $IsUninstallDone = $false
    $text = "uninstall ${DisplayName} Agents"; $step++; Logline -logstring $text -step $step
    $program = "${scriptDir}/${uninstName}"

    if ( Test-IsAgentsStopped -eq $true ) {

        if (Test-Path "$program") {
            $text = " ITMRmvAll"; Logline -logstring $text -step $step
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
            $text = "${program} exit code: $($result.ExitCode)"; Logline -logstring $text -step $step
        }
    }

    if ( Test-IsAllGone -eq $false ) {
        $text = "uninstall via MsiExec for direct uninstall (if other methods fail)"; $step++; Logline -logstring $text -step $step
        try {
            $clientMsi = Get-WmiObject -Class Win32_Product | Where-Object { $_.Description -like "*${DisplayName}*" }
            if ($clientMsi) {
                $text = "Uninstalling via MSI: $($clientMsi.Name)"; Logline -logstring $text -step $step
                $result = $clientMsi.Uninstall()
                $text = "MSI uninstall result: $($result.ReturnValue)"; Logline -logstring $text -step $step
            }
        }
        catch {
            $text = "MSI uninstall error: $_"; Logline -logstring $text -step $step
        }
    }

    if ( Test-IsAllGone -eq $false ) {
        $text = "uninstall via WMIC (for older systems)"; $step++; Logline -logstring $text -step $step
        try {
            $text = "Attempting uninstall via WMI"; Logline -logstring $text -step $step
            $result = Invoke-Expression "wmic product where 'name like ""Configuration Manager Client""' call uninstall /nointeractive"
            $text = "WMI uninstall attempted"; Logline -logstring $text -step $step
        }
        catch {
            $text = "WMI uninstall error: $_"; Logline -logstring $text -step $step
        }
    }

    return Test-IsAllGone
}
function Test-CleanupRegistry {
    $isAllRegistryGone = $true
    $regKeys = @(
        "HKLM:\SOFTWARE\Candle"
        "HKLM:\SOFTWARE\Wow6432Node\Candle",
        "HKLM:\SYSTEM\CurrentControlSet\Services\Candle",
        "HKLM:\SYSTEM\CurrentControlSet\Services\IBM\ITM"
    )
    $text = "Clean up registry"; $step++; Logline -logstring $text -step $step
    foreach ($key in $regKeys) {
        if (Test-Path $key) {
            try {
                $text = "Removing registry key: $key"; Logline -logstring $text -step $step
                Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
                $isAllRegistryGone = $true
            } catch {
                $text = "Error removing registry key $key : $_"; Logline -logstring $text -step $step
                $isAllRegistryGone = $false
            }
        }
    }
    return $isAllRegistryGone
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

    $isAllFilesGone = $true
    $filesNotRemoved = @()

    $dirPaths = @(
        "C:/Temp/scanner_logs",
        "C:/Temp/jre",
        "C:/Temp/report",
        "C:/Temp/exclude_config.txt",
        "C:/Temp/Get-Win-Disks-and-Partitions.ps1",
        "C:/Temp/log4j2-scanner-2.6.5.jar",
        "C:/salt",
        "C:/IBM/ITM/TMA${DisplayName}_x64/logs"
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
                $isAllFilesGone = $false
            }
        }
        else {
            $text = "Path does not exist: $path"; Logline -logstring $text -step $step
        }

        if ( $isAllFilesGone ) {
            $result = 'success. All Agents files are removed'
            Logline -logstring $result -step $step
        }
        else {
            if ( $filesNotRemoved.Count -gt 0 ) {
                $text = "filesNotRemoved=" + $filesNotRemoved.Count; Logline -logstring $text -step $step
                foreach ($path in $filesNotRemoved) {
                    Logline -logstring $line -step $step
                }
            }
        }
    }
    return $isAllFilesGone
}
function Test-IsAgentsStopped {

    $serviceExists = $(Get-Service | Where-Object { $_.Name -match '${ServiceName}' -and $_.DisplayName -match '${DisplayName}' } -ErrorAction SilentlyContinue).Name
    $processExists = $(Get-Process | Where-Object { $_.ProcessName -match '${ServiceName}' -and $_.Description -match '${DisplayName}' } -ErrorAction SilentlyContinue).ProcessName
    $serviceExists | format-table -autosize | Out-string -Width 300
    $processExists | format-table -autosize | Out-string -Width 300

    return -not ($serviceExists -or $processExists)
}
function Test-IsAllGone {
    Param (
        [string]$ServiceName,
        [string]$DisplayName,
        [string]$CommandLine,
        [int32]$step
        )

    $isFilesGone        = [bool]$(Test-Path "C:/IBM/ITM/*" -ErrorAction SilentlyContinue)
    $isRegistryGone     = [bool]$(Test-Path "HKLM:\SOFTWARE\Candle" -ErrorAction SilentlyContinue)
    $serviceExists      = [bool]$(Get-Service | Where-Object { $_.Name -match '${ServiceName}' -and $_.DisplayName -match '${DisplayName}' } -ErrorAction SilentlyContinue)
    $processExists      = [bool]$(Get-Process | Where-Object { $_.ProcessName -match '${ServiceName}' -and $_.Description -match '${DisplayName}' } -ErrorAction SilentlyContinue)

    return -not ($isFilesGone -or $isRegistryGone -or $serviceExists -or $processExists)
}
# ----------------------------------------------------------------------------------------------------------------------------
#region appl vars
# ----------------------------------------------------------------------------------------------------------------------------
$continue           = $true
$uninstName         = 'ITMRmvAll.exe'
$DisplayName        = 'monitoring Agent'
$ServiceName        = '^k.*'
$CommandLine        = '^C:\\IBM.ITM\\.*\\K*'
$text = "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"; Logline -logstring $text -step $step
$text = "uninstName:        " + $uninstName;    Logline -logstring $text -step $step
$text = "DisplayName:       " + $DisplayName;   Logline -logstring $text -step $step
$text = "ServiceName:       " + $ServiceName;   Logline -logstring $text -step $step
$text = "CommandLine:       " + $CommandLine;   Logline -logstring $text -step $step
$text = "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"; Logline -logstring $text -step $step
# ----------------------------------------------------------------------------------------------------------------------------
#region run Test-lastUninstall
# ----------------------------------------------------------------------------------------------------------------------------
    $text = "run Test-lastUninstall"; $step++; Logline -logstring $text -step $step
    $continue = Test-lastUninstall -uninstName ${uninstName} -step $step
#endregion
# ----------------------------------------------------------------------------------------------------------------------------
#region run Stop-ProductAgent
# ----------------------------------------------------------------------------------------------------------------------------
if ( $continue ) {
    $text = "run Stop-ProductAgent"; $step++; Logline -logstring $text -step $step
    $continue = Stop-ProductAgent -ServiceName $ServiceName -DisplayName $DisplayName -CommandLine $CommandLine -step $step -disable
}
#endregion
# ----------------------------------------------------------------------------------------------------------------------------
#region run Uninstall-ProductAgent
# ----------------------------------------------------------------------------------------------------------------------------
if ( $continue ) {
    $text = "run Uninstall-ProductAgent"; $step++; Logline -logstring $text -step $step
    Uninstall-ProductAgent -uninstName ${uninstName} -DisplayName $DisplayName
}
#endregion
# ----------------------------------------------------------------------------------------------------------------------------
#region run Test-CleanupRegistry.
# ----------------------------------------------------------------------------------------------------------------------------
if ( $continue ) {
    $text = "run Test-CleanupRegistry"; $step++; Logline -logstring $text -step $step
    $result = Test-CleanupRegistry -step $step
}
#endregion
# ----------------------------------------------------------------------------------------------------------------------------
#region run Test-CleanupProductFiles.
# ----------------------------------------------------------------------------------------------------------------------------
if ( $continue ) {
    $text = "run Test-CleanupProductFiles"; $step++; Logline -logstring $text -step $step
    $result = Test-CleanupProductFiles -step $step
}
#endregion
# ----------------------------------------------------------------------------------------------------------------------------
#region cleanup after us.
# ----------------------------------------------------------------------------------------------------------------------------
Remove-Item -Recurse -Path "$scriptDir" -ErrorAction SilentlyContinue
#endregion
# ----------------------------------------------------------------------------------------------------------------------------
#region final test.
# ----------------------------------------------------------------------------------------------------------------------------
if ( $continue ) {
    $text = "run Test-IsAllGone"; $step++; Logline -logstring $text -step $step
    $continue = Test-IsAllGone -ServiceName $ServiceName -DisplayName $DisplayName -CommandLine $CommandLine -step $step
}#endregion
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
$Difference = '{0:00}:{1:00}:{2:00}' -f $Hrs, $Mins, $Secs
$text = "The End, Elapsed time: ${Difference}"; $step++; Logline -logstring $text -step $step
$text = "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
exit 0