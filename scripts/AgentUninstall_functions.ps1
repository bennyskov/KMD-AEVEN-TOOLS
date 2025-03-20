$text = "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"; Logline -logstring $text -step $step
$text = "UninstName:        " + $UninstName; Logline -logstring $text -step $step
$text = "DisplayName:       " + $DisplayName; Logline -logstring $text -step $step
$text = "ServiceName:       " + $ServiceName; Logline -logstring $text -step $step
$text = "CommandLine:       " + $CommandLine; Logline -logstring $text -step $step
$text = "UninstPath:        " + $UninstPath; Logline -logstring $text -step $step
$text = "UninstCmdexec:     " + $UninstCmdexec; Logline -logstring $text -step $step
$text = "DisableService:       " + $DisableService; Logline -logstring $text -step $step
foreach ( $key in $RegistryKeys ) {
    $text = "registry key to be removed: " + $key; Logline -logstring $text -step $step
}
foreach ( $dir in $RemoveDirs ) {
    $text = "directory to be removed: " + $dir; Logline -logstring $text -step $step
}
$text = "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"; Logline -logstring $text -step $step
# ----------------------------------------------------------------------------------------------------------------------------
# functions
# ----------------------------------------------------------------------------------------------------------------------------
Function Logline {
    Param ([string]$logstring, $step)
    $now = (get-date -format "yyyy-MM-dd HH:mm:ss.fff")
    $text = ( "{0,-23} : $hostname : step {1:d4} : {2}" -f $now, $step, $logstring)
    Add-content -LiteralPath $Logfile -value $text -Force
    Write-Host $text
}
function Test-lastUninstall {
    try {
        $continue = $true
        if ( [bool]$(Get-WmiObject Win32_Process | Where-Object Name -imatch "${UninstName}")) {
            $text   = "stop ${UninstName} if UninstPath is still running from last run."; $step++; Logline -logstring $text -step $step
            $result = $(Get-WmiObject Win32_Process | Where-Object Name -imatch "${UninstName}") | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -PassThru -Verbose }
            Logline -logstring $result -step $step
        }
        if ( [bool]$(Get-WmiObject Win32_Process | Where-Object Name -imatch "${UninstName}")) {
                $text = "${UninstName} is still running. We try stopping it using psKill"; Logline -logstring $result -step $step
                $cmdexec = "${scriptDir}/psKill -t $UninstName -accepteula -nobanner"
                Logline -logstring $cmdexec -step $step
                $result = & cmd /C $cmdexec
                Logline -logstring $result -step $step

                if ( [bool]$(Get-WmiObject Win32_Process | Where-Object Name -imatch "${UninstName}")) {
                    $text = "${UninstName} is still running. We must break now"; Logline -logstring $result -step $step
                    $continue = $false
                }
        } else {
            $text = "${UninstName} is not hanging around from last run"; Logline -logstring $result -step $step
        }
    }
    catch {
        $errorMsg = $_.ToString()
        Logline -logstring $errorMsg -step $step
    }
    return $continue
}
function Start-ProductAgent {
    try {
        $IsAgentsStarted = $false
        $text = "Start ${DisplayName} agents"; $step++; Logline -logstring $text -step $step
        $services = Get-Service | Where-Object { $_.Name -match "${ServiceName}" -and $_.DisplayName -match "${DisplayName}" }
        foreach ($service in $services) {
            $service | Stop-Service
            $service | Set-Service -StartupType Automatic
            $service | Start-Service
        }
    }
    catch {
        $errorMsg = $_.ToString()
        Logline -logstring $errorMsg -step $step
    }

    if ( Test-IsAgentsStopped -eq $false ) { $IsAgentsStarted = $true }
    Logline -logstring $IsAgentsStarted -step $step
    $result = Show-AgentStatus
    Logline -logstring $result -step $step
    return $IsAgentsStarted
}
function Stop-ProductAgent {
    try {
        $IsAgentsStopped = $false
        if ( -not $IsAgentsStopped ) {
            $text = "stop Method 1: Stop all ${DisplayName} agents using Stop-Service"; $step++; Logline -logstring $text -step $step
            $servicesToStop = Get-Service | Where-Object { $_.Name -match "${ServiceName}" -and $_.DisplayName -match "${DisplayName}" }
            Logline -logstring "Found services to stop:" -step $step
            foreach ($service in $servicesToStop) {
                if ( $disable ) { $service | Set-Service -StartupType Disabled }
                $service | Stop-Service -force
                $result =  $($service).Status
                Logline -logstring $result -step $step
            }
            if ( Test-IsAgentsStopped -eq $true ) { $IsAgentsStopped = $true }
        }

        if ( -not $IsAgentsStopped ) {
            $text = "stop Method 2: Stop ${DisplayName} using WMI Terminate"; $step++; Logline -logstring $text -step $step
            $ReturnValue = $(Get-WmiObject Win32_Process | Where-Object CommandLine -match "${CommandLine}" | ForEach-Object { $_.Terminate() }).ReturnValue
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
            $text = "stop Method 3: Stop ${DisplayName} using "net stop service"; $step++; Logline -logstring $text -step $step
            $servicesToStop = $(Get-Service | Where-Object { $_.Name -match "${ServiceName}" -and $_.DisplayName -match "${DisplayName}"}).Name
            foreach ($service in $servicesToStop) {
                $cmdexec = "net stop $service"
                $result = & cmd /C $cmdexec
                Logline -logstring "$result"
            }
            if ( Test-IsAgentsStopped -eq $true ) { $IsAgentsStopped = $true }
        }

        if ( -not $IsAgentsStopped ) {
            $text = "stop Method 4: Stop ${DisplayName} using "psKill service"; $step++; Logline -logstring $text -step $step
            $servicesToKill = Get-Service | Where-Object { $_.Name -match "${ServiceName}" -and $_.DisplayName -match "${DisplayName}" }
            foreach ($service in $servicesToKill) {
                $text = "${service} is still running. We try stopping it using psKill"; Logline -logstring $result -step $step
                $cmdexec = "${scriptDir}/psKill -t $service -accepteula -nobanner"
                Logline -logstring $cmdexec -step $step
                $result = & cmd /C $cmdexec
                Logline -logstring $result -step $step
            }
            if ( Test-IsAgentsStopped -eq $true ) { $IsAgentsStopped = $true }
        }

        if ( -not $IsAgentsStopped ) {
            $text = "stop and disable services"; $step++; Logline -logstring $text -step $step
            $servicesToStop = Get-Service | Where-Object { $_.Name -match "${ServiceName}" -and $_.DisplayName -match "${DisplayName}" }
            foreach ($service in $servicesToStop) {
                if ( $disable ) { $service | Set-Service -StartupType Disabled }
                $service | Stop-Service -force
            }
            Logline -logstring "$result"
            if ( Test-IsAgentsStopped -eq $true ) { $IsAgentsStopped = $true }
        }
    }
    catch {
        $errorMsg = $_.ToString()
        Logline -logstring $errorMsg -step $step
        if ( Test-IsAgentsStopped -eq $false ) { $IsAgentsStopped = $true }
    }
    if ( -not $IsAgentsStopped ) {
        Show-AgentStatus
    }
    return $IsAgentsStopped
}
function Uninstall-ProductAgent {
    $text = "run Uninstall ${DisplayName} Agents"; $step++; Logline -logstring $text -step $step

    if ( Test-IsAgentsStopped -eq $true ) {
        if (Test-Path "$UninstPath") {
            try {
                $text = "${UninstName}"; Logline -logstring $text -step $step
                $result = & cmd /C $UninstCmdexec
                $rc = $?
                if ( $rc ) {
                    Logline -logstring "Success. rc=$rc result=$result"
                }
                else {
                    Logline -logstring "Failed. rc=$rc result=$result"
                }
                $text = "${UninstPath} exit code: $($result.ExitCode)"; Logline -logstring $text -step $step
            }
            catch {
                $text = "${UninstName} error: $_"; Logline -logstring $text -step $step
            }
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
            $result = Invoke-Expression "wmic product where name like ${DisplayName} call uninstall /nointeractive"
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
    $text = "Clean up registry"; $step++; Logline -logstring $text -step $step
    foreach ($key in $RegistryKeys) {
        if (Test-Path $key) {
            try {
                $text = "Removing registry key: $key"; Logline -logstring $text -step $step
                Remove-Item -Path $key -Recurse -Force
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
        Remove-Item -Path $path -Recurse -Force
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
            $handleResult = & cmd /C $handleCmd
            Logline -logstring "Handle result: $handleResult" -step $step

            # Parse handle output
            $handleRegex = [regex]::Match($handleResult, "pid:\s*(\d+).*?type:\s*File\s*([0-9A-F]+):")
            if ($handleRegex.Success) {
                $processId = $handleRegex.Groups[1].Value.Trim()
                $handleId = $handleRegex.Groups[2].Value.Trim()

                # Close handle
                $cmdexec = "${binDir}/handle -c $handleId -y -p ${processId} -accepteula -nobanner"
                Logline -logstring "Executing: $cmdexec" -step $step
                $closeResult = & cmd /C $cmdexec
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

    $isAllFilesGone = $true
    $filesNotRemoved = @()

    $text = "cleanup all product files, if uninstall didnt do it"; $step++; Logline -logstring $text -step $step
    foreach ($path in $RemoveDirs) {
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
            $result = "success. All Agents files are removed"
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
function Show-AgentStatus {
    $services = $(Get-Service | Where-Object { $_.Name -imatch "${ServiceName}" -and $_.DisplayName -imatch "${DisplayName}"})
    $services | Format-Table -AutoSize | Out-String -Width 300 | ForEach-Object { Logline -logstring $_ -step $step }
    return $true
}
function Test-IsAgentsStopped {

    $serviceExists = $(Get-Service | Where-Object { $_.Name -match "${ServiceName}" -and $_.DisplayName -match "${DisplayName}"}).Name
    $processExists = $(Get-Process | Where-Object { $_.ProcessName -match "${ServiceName}" -and $_.Description -match "${DisplayName}"}).ProcessName
    $serviceExists | format-table -autosize | Out-string -Width 300
    $processExists | format-table -autosize | Out-string -Width 300

    return -not ($serviceExists -or $processExists)
}
function Test-IsAllGone {
    $isFilesGone        = [bool]$(Test-Path "C:/IBM/ITM/*")
    $isRegistryGone     = [bool]$(Test-Path "HKLM:\SOFTWARE\Candle")
    $serviceExists      = [bool]$(Get-Service | Where-Object { $_.Name -match "${ServiceName}" -and $_.DisplayName -match "${DisplayName}"})
    $processExists      = [bool]$(Get-Process | Where-Object { $_.ProcessName -match "${ServiceName}" -and $_.Description -match "${DisplayName}"})
    return -not ($isFilesGone -or $isRegistryGone -or $serviceExists -or $processExists)
}
