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
$global:scriptPath = [System.Text.RegularExpressions.Regex]::Replace($scriptPath, "\\", "/")
$global:scriptarray = $scriptPath.split("/")
$global:scriptName = [System.Text.RegularExpressions.Regex]::Replace($scriptarray[-1], ".ps1", "")
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

function Remove-AdditionalDirectories {
    $text = "Removing additional specified directories"; $step++; Logline -logstring $text -step $step

    foreach ($dir in $global:RemoveDirs) {
        if (Test-Path $dir) {
            $text = "Attempting to remove directory: $dir"; Logline -logstring $text -step $step
            try {
                Remove-Item -Path $dir -Recurse -Force -Confirm:$false -ErrorAction Stop
                $text = "Successfully removed directory: $dir"; Logline -logstring $text -step $step
            }
            catch {
                $errorMsg = $_.Exception.Message
                $text = "Could not remove directory $dir directly. Error: $errorMsg. Attempting to remove contents individually."; Logline -logstring $text -step $step

                try {
                    # Get all child items (files and directories)
                    $childItems = Get-ChildItem -Path $dir -Recurse -Force -ErrorAction SilentlyContinue

                    # Remove files first
                    $childItems | Where-Object { -not $_.PSIsContainer } | ForEach-Object {
                        try {
                            $text = "Removing file: $($_.FullName)"; Logline -logstring $text -step $step
                            Remove-Item -Path $_.FullName -Force -Confirm:$false -ErrorAction Stop
                            $text = "Successfully removed file: $($_.FullName)"; Logline -logstring $text -step $step
                        }
                        catch {
                            $fileError = $_.Exception.Message
                            $text = "ERROR: Could not remove file: $($_.FullName). Reason: $fileError"; Logline -logstring $text -step $step
                        }
                    }

                    # Remove subdirectories in reverse order (deepest first)
                    $subDirectories = $childItems | Where-Object { $_.PSIsContainer } | Sort-Object -Property { $_.FullName.Length } -Descending
                    $subDirectories | ForEach-Object {
                        try {
                            $text = "Removing subdirectory: $($_.FullName)"; Logline -logstring $text -step $step
                            Remove-Item -Path $_.FullName -Recurse -Force -Confirm:$false -ErrorAction Stop
                            $text = "Successfully removed subdirectory: $($_.FullName)"; Logline -logstring $text -step $step
                        }
                        catch {
                            $dirError = $_.Exception.Message
                            $text = "ERROR: Could not remove subdirectory: $($_.FullName). Reason: $dirError"; Logline -logstring $text -step $step
                        }
                    }

                    # Final attempt to remove the top-level directory
                    $text = "Retrying to remove the top-level directory: $dir"; Logline -logstring $text -step $step
                    Remove-Item -Path $dir -Recurse -Force -Confirm:$false -ErrorAction Stop
                    $text = "Successfully removed directory: $dir"; Logline -logstring $text -step $step
                }
                catch {
                    $finalError = $_.Exception.Message
                    $text = "FINAL ERROR: Failed to remove directory $dir after all attempts. Reason: $finalError"; Logline -logstring $text -step $step
                }
            }
        }
        else {
            $text = "Directory not found, skipping: $dir"; Logline -logstring $text -step $step
        }
    }
}
}
function Show-AgentStatus {
    $services = Get-ServicesWithFallback -ServicePattern "${ServiceName}" -DisplayNamePattern "${DisplayName}"

    if ($services.Count -gt 0) {
        $text = "Found $($services.Count) services matching criteria"; Logline -logstring $text -step $step
        $services | Select-Object Name, DisplayName, Status, StartType | Format-Table -AutoSize | Out-String -Width 300 | ForEach-Object { Logline -logstring $_ -step $step }
    }
    else {
        # Ensure this message appears on a single line in the log
        Logline -logstring "Final services status: No monitoring agent services found matching criteria" -step $step
    }

    return $true
}
function Test-IsAgentsStopped {

    $serviceExists = $(Get-ServicesWithFallback -ServicePattern "${ServiceName}" -DisplayNamePattern "${DisplayName}").Name

    # Use Get-ProcessesWithFallback instead of Get-Process for restricted environments
    try {
        $itmProcesses = Get-ProcessesWithFallback | Where-Object { $_.Name -match "${ServiceName}" }
        $processExists = $itmProcesses.Name
    }
    catch {
        $processExists = @()
    }

    $serviceExists | format-table -autosize | Out-string -Width 300
    $processExists | format-table -autosize | Out-string -Width 300

    return -not ($serviceExists -or $processExists)
}

function Find-LockedFiles {
    $text = "Checking for locked files in ITM directories"; $step++; Logline -logstring $text -step $step

    $itmPaths = @("C:\IBM\ITM")
    foreach (${path} in $itmPaths) {
        if (Test-Path ${path}) {
            $text = "Checking for locked files in ${path}"; Logline -logstring $text -step $step
            $handleCmd = "${scriptBin}/handle.exe ${path} -accepteula -nobanner"
            try {
                $result = & cmd /C $handleCmd
                Logline -logstring "$result" -step $step
            }
            catch {
                $errorMsg = $_.ToString()
                Logline -logstring "Error executing handle: $errorMsg" -step $step
            }
        }
    }
}

function Test-IsAllGone {
    # Check all directories in RemoveDirs array
    $isFilesGone = $true
    foreach ($dir in $global:RemoveDirs) {
        $normalizedPath = $dir -replace "/", "\"
        if (Test-Path $normalizedPath) {
            $isFilesGone = $false
            break
        }
    }
    $isRegistryGone = -not [bool]$(Test-Path "HKLM:\SOFTWARE\Candle")
    $serviceExists = [bool]$(Get-ServicesWithFallback -ServicePattern "${ServiceName}" -DisplayNamePattern "${DisplayName}")

    # Use Get-ProcessesWithFallback instead of Get-Process for restricted environments
    try {
        $itmProcesses = Get-ProcessesWithFallback | Where-Object { $_.Name -match "${ServiceName}" }
        $processExists = [bool]($itmProcesses -and $itmProcesses.Count -gt 0)
    }
    catch {
        $processExists = $false
    }

    # Also check for remaining ITM entries in Programs and Features
    $programsAndFeaturesEntries = @()
    $programsAndFeaturesEntries += Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
                Where-Object { ($_.DisplayName -like "*IBM*" -and ($_.DisplayName -like "*Tivoli*" -or $_.DisplayName -like "*ITM*" -or $_.DisplayName -like "*monitoring*")) -or
                              ($_.Publisher -like "*IBM*" -and ($_.DisplayName -like "*Tivoli*" -or $_.DisplayName -like "*ITM*" -or $_.DisplayName -like "*monitoring*")) }
    $programsAndFeaturesEntries += Get-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
                Where-Object { ($_.DisplayName -like "*IBM*" -and ($_.DisplayName -like "*Tivoli*" -or $_.DisplayName -like "*ITM*" -or $_.DisplayName -like "*monitoring*")) -or
                              ($_.Publisher -like "*IBM*" -and ($_.DisplayName -like "*Tivoli*" -or $_.DisplayName -like "*ITM*" -or $_.DisplayName -like "*monitoring*")) }

    $noProgramsAndFeaturesEntries = ($programsAndFeaturesEntries.Count -eq 0)

    return ($isFilesGone -and $isRegistryGone -and -not $serviceExists -and -not $processExists -and $noProgramsAndFeaturesEntries)
}

function Invoke-ForceUninstall {
    $text = "Performing emergency force uninstallation as a last resort"; $step++; Logline -logstring $text -step $step

    # First, try direct MSI uninstallation by searching for product codes
    $text = "Searching Windows Installer database for product codes"; Logline -logstring $text -step $step

    try {
        $products = @()
        $products += Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
                    Where-Object { ($_.DisplayName -like "*IBM*" -and ($_.DisplayName -like "*Tivoli*" -or $_.DisplayName -like "*ITM*" -or $_.DisplayName -like "*monitoring*")) -or
                                  ($_.Publisher -like "*IBM*" -and ($_.DisplayName -like "*Tivoli*" -or $_.DisplayName -like "*ITM*" -or $_.DisplayName -like "*monitoring*")) }
        $products += Get-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
                    Where-Object { ($_.DisplayName -like "*IBM*" -and ($_.DisplayName -like "*Tivoli*" -or $_.DisplayName -like "*ITM*" -or $_.DisplayName -like "*monitoring*")) -or
                                  ($_.Publisher -like "*IBM*" -and ($_.DisplayName -like "*Tivoli*" -or $_.DisplayName -like "*ITM*" -or $_.DisplayName -like "*monitoring*")) }

        if ($products -and $products.Count -gt 0) {
            $text = "Found $($products.Count) IBM/ITM related products"; Logline -logstring $text -step $step

            foreach ($product in $products) {
                $text = "Attempting to force uninstall: $($product.DisplayName)"; Logline -logstring $text -step $step

                if ($product.UninstallString) {
                    $guid = $null

                    # Extract GUID from uninstall string
                    if ($product.UninstallString -match '\{([0-9A-F-]+)\}') {
                        $guid = $matches[1]
                        $text = "Extracted product code: {$guid}"; Logline -logstring $text -step $step

                        # Force uninstall with msiexec
                        try {
                            $cmdString = "msiexec.exe /x {$guid} /qn /norestart REBOOT=ReallySuppress"
                            $text = "Executing: $cmdString"; Logline -logstring $text -step $step
                            $result = Start-Process -FilePath "msiexec.exe" -ArgumentList "/x {$guid}", "/qn", "/norestart", "REBOOT=ReallySuppress" -Wait -PassThru
                            $text = "MSI uninstall completed with exit code: $($result.ExitCode)"; Logline -logstring $text -step $step
                        }
                        catch {
                            $text = "Error executing MSI uninstall: $_"; Logline -logstring $text -step $step
                        }
                    }
                    else {
                        # Try to directly execute the uninstall string with /quiet added
                        try {
                            $uninstallCmd = $product.UninstallString
                            if ($uninstallCmd -match 'msiexec') {
                                $uninstallCmd = "$uninstallCmd /qn /norestart"
                            }

                            $text = "Executing uninstall string: $uninstallCmd"; Logline -logstring $text -step $step
                            $result = & cmd /C $uninstallCmd
                            $text = "Uninstall completed: $result"; Logline -logstring $text -step $step
                        }
                        catch {
                            $text = "Error executing uninstall string: $_"; Logline -logstring $text -step $step
                        }
                    }
                }
            }
        }
        else {
            $text = "No IBM/ITM products found in Windows Installer database"; Logline -logstring $text -step $step
        }
    }
    catch {
        $text = "Error accessing Windows Installer database: $_"; Logline -logstring $text -step $step
    }

    # Kill any remaining ITM services with extreme prejudice
    $text = "Forcibly removing ITM services from registry"; Logline -logstring $text -step $step

    try {
        $servicesToRemove = Get-ServicesWithFallback | Where-Object {
            ($_.Name -match "^k" -and ($_.DisplayName -match "monitoring Agent" -or $_.DisplayName -like "*ITM*")) -or
            (($_.Name -like "*IBM*" -or ($_.Name -like "*Tivoli*" -and $_.Name -notlike "*TSM*" -and $_.DisplayName -notlike "*Storage*")) -and ($_.DisplayName -match "monitoring Agent" -or $_.DisplayName -like "*ITM*" -or $_.DisplayName -like "*Candle*"))
        }

        if ($servicesToRemove -and $servicesToRemove.Count -gt 0) {
            foreach ($svc in $servicesToRemove) {
                $text = "Removing service: $($svc.Name)"; Logline -logstring $text -step $step

                # First, kill processes associated with service
                try {
                    Stop-ServiceWithFallback -ServiceName $svc.Name
                    Start-Sleep -Seconds 2

                    # Use SC delete as a more forceful approach
                    $cmdString = "sc.exe delete $($svc.Name)"
                    $text = "Executing: $cmdString"; Logline -logstring $text -step $step
                    $result = & cmd /C $cmdString
                    $text = "SC delete result: $result"; Logline -logstring $text -step $step
                }
                catch {
                    $text = "Error removing service $($svc.Name): $_"; Logline -logstring $text -step $step
                }
            }
        }
    }
    catch {
        $text = "Error removing services: $_"; Logline -logstring $text -step $step
    }

    # Delete remaining ITM files with extreme prejudice
    $text = "Force removing ITM installation directories"; Logline -logstring $text -step $step

    $itmPaths = @(
        "C:\IBM\ITM"
    )

    foreach(${path} in $itmPaths) {
        if(Test-Path ${path}) {
            $text = "Attempting to forcefully remove: ${path}"; Logline -logstring $text -step $step

            try {
                # Take ownership of the directory for admin
                $takeown = "takeown.exe /F `"${path}`" /R /A /D Y"
                $text = "Taking ownership: $takeown"; Logline -logstring $text -step $step
                & cmd /C $takeown

                # Grant admin full control
                $icacls = "icacls.exe `"${path}`" /grant administrators:F /T /C"
                $text = "Setting permissions: $icacls"; Logline -logstring $text -step $step
                & cmd /C $icacls

                # Force remove directory
                $text = "Force removing path: ${path}"; Logline -logstring $text -step $step
                Remove-Item -Path ${path} -Recurse -Force -ErrorAction SilentlyContinue

                # Check if removal succeeded
                if (Test-Path ${path}) {
                    $text = "Standard removal failed. Directory is likely locked. Using handle.exe to find locking processes"; Logline -logstring $text -step $step

                    # Use handle.exe to find what's locking the directory
                    $handleCmd = "${scriptBin}/handle.exe `"${path}`" -accepteula -nobanner"
                    $text = "Executing: $handleCmd"; Logline -logstring $text -step $step

                    try {
                        $handleResult = & cmd /C $handleCmd
                        $text = "Handle output: $handleResult"; Logline -logstring $text -step $step

                        # Parse handle output to find processes and kill them
                        $handleLines = $handleResult -split "`n"
                        foreach ($line in $handleLines) {
                            if ($line -match "^(.+?\.exe)\s+pid:\s*(\d+)\s+type:\s*File\s+([0-9A-Fa-f]+):\s*(.+)") {
                                $processName = $matches[1].Trim()
                                $processId = $matches[2].Trim()
                                $handleId = $matches[3].Trim()
                                $filePath = $matches[4].Trim()

                                $text = "Found locking process: $processName (PID: $processId) holding handle $handleId to $filePath"; Logline -logstring $text -step $step

                                # Try to close the specific handle first
                                try {
                                    $closeHandleCmd = "${scriptBin}/handle.exe -c $handleId -y -p $processId -accepteula -nobanner"
                                    $text = "Attempting to close handle: $closeHandleCmd"; Logline -logstring $text -step $step
                                    $closeResult = & cmd /C $closeHandleCmd
                                    $text = "Close handle result: $closeResult"; Logline -logstring $text -step $step
                                }
                                catch {
                                    $text = "Failed to close handle, will try killing process: $_"; Logline -logstring $text -step $step
                                }

                                # If handle closing didn't work, kill the process
                                $text = "Attempting to kill locking process: $processName (PID: $processId)"; Logline -logstring $text -step $step
                                $success = Stop-ProcessWithFallback -ProcessName $processName -ProcessId $processId
                                if ($success) {
                                    $text = "Successfully killed process: $processName (PID: $processId)"; Logline -logstring $text -step $step
                                } else {
                                    $text = "Failed to kill process $processName (PID: $processId) with all methods"; Logline -logstring $text -step $step
                                }
                            }
                        }

                        # Wait a moment for processes to fully terminate
                        Start-Sleep -Seconds 3

                        # Try removing the directory again after killing locking processes
                        $text = "Attempting directory removal after killing locking processes"; Logline -logstring $text -step $step
                        Remove-Item -Path ${path} -Recurse -Force -ErrorAction SilentlyContinue

                        # If still locked, try robocopy method
                        if (Test-Path ${path}) {
                            $text = "Directory still exists. Trying robocopy empty method"; Logline -logstring $text -step $step

                            # Create empty temp directory
                            $emptyDir = "$env:TEMP\EmptyDir"
                            if (-not (Test-Path $emptyDir)) {
                                New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
                            }

                            # Use robocopy to mirror empty directory over the ITM directory
                            $robocopy = "robocopy.exe `"$emptyDir`" `"${path}`" /MIR /R:1 /W:1"
                            $text = "Executing: $robocopy"; Logline -logstring $text -step $step
                            & cmd /C $robocopy

                            # Try removal one last time
                            Remove-Item -Path ${path} -Recurse -Force -ErrorAction SilentlyContinue
                        }

                    }
                    catch {
                        $text = "Error using handle.exe: $_"; Logline -logstring $text -step $step

                        # Fallback to robocopy method if handle.exe fails
                        $text = "Falling back to robocopy empty method"; Logline -logstring $text -step $step

                        # Create empty temp directory
                        $emptyDir = "$env:TEMP\EmptyDir"
                        if (-not (Test-Path $emptyDir)) {
                            New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
                        }

                        # Use robocopy to mirror empty directory over the ITM directory
                        $robocopy = "robocopy.exe `"$emptyDir`" `"${path}`" /MIR /R:1 /W:1"
                        $text = "Executing: $robocopy"; Logline -logstring $text -step $step
                        & cmd /C $robocopy

                        # Try removal one last time
                        Remove-Item -Path ${path} -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }

                # Final check
                if (Test-Path ${path}) {
                    $text = "WARNING: Could not remove directory: ${path}"; Logline -logstring $text -step $step
                }
                else {
                    $text = "Successfully removed: ${path}"; Logline -logstring $text -step $step
                }
            }
            catch {
                $text = "Error force removing ${path}: $_"; Logline -logstring $text -step $step
            }
        }
    }

    # Clean up the system environment variables related to ITM
    $text = "Cleaning up ITM environment variables"; Logline -logstring $text -step $step

    try {
        $envVars = [Environment]::GetEnvironmentVariables([EnvironmentVariableTarget]::Machine)
        foreach ($varName in $envVars.Keys) {
            $varValue = $envVars[$varName]



            if ($varValue -like "*IBM\ITM*" -or $varValue -like "*Tivoli*" -or
                $varName -like "*CANDLEHOME*" -or $varName -like "*ITM*") {
                $text = "Removing environment variable: $varName = $varValue"; Logline -logstring $text -step $step
                try {
                    [Environment]::SetEnvironmentVariable($varName, $null, [EnvironmentVariableTarget]::Machine)
                }
                catch {
                    $text = "Error removing environment variable ${varName}: $_"; Logline -logstring $text -step $step
                }
            }
        }
    }
    catch {
        $text = "Error processing environment variables: $_"; Logline -logstring $text -step $step
    }

    # Force cleanup of remaining registry entries
    $text = "Force cleanup of remaining ITM registry entries"; Logline -logstring $text -step $step
    try {
        # Aggressive cleanup of specific Candle registry keys that often persist
        $text = "Aggressively removing stubborn Candle/ITM registry keys"; Logline -logstring $text -step $step
        $stubborn_registry_keys = @(
            "HKLM:\SOFTWARE\Candle",
            "HKLM:\SOFTWARE\Wow6432Node\Candle",
            "HKLM:\SYSTEM\CurrentControlSet\Services\Candle",
            "HKLM:\SOFTWARE\IBM\ITM",
            "HKLM:\SOFTWARE\Wow6432Node\IBM\ITM",
            "HKLM:\SOFTWARE\IBM\Tivoli",
            "HKLM:\SOFTWARE\Wow6432Node\IBM\Tivoli"
        )

        foreach ($regKey in $stubborn_registry_keys) {
            if (Test-Path $regKey) {
                $text = "Force removing persistent registry key: $regKey"; Logline -logstring $text -step $step
                try {
                    # Take ownership and grant full control before removing
                    $text = "Taking ownership of registry key: $regKey"; Logline -logstring $text -step $step

                    # Use reg.exe for more aggressive registry manipulation
                    $regPath = $regKey -replace "HKLM:\\", "HKEY_LOCAL_MACHINE\"

                    # Grant ownership to administrators
                    $takeownCmd = "reg.exe add `"$regPath`" /f"
                    $text = "Executing: $takeownCmd"; Logline -logstring $text -step $step
                    & cmd /C $takeownCmd | Out-Null

                    # Delete the registry key recursively
                    $deleteCmd = "reg.exe delete `"$regPath`" /f"
                    $text = "Executing: $deleteCmd"; Logline -logstring $text -step $step
                    $deleteResult = & cmd /C $deleteCmd 2>&1

                    if ($LASTEXITCODE -eq 0) {
                        $text = "Successfully removed registry key: $regKey"; Logline -logstring $text -step $step
                    } else {
                        $text = "reg.exe delete result: $deleteResult"; Logline -logstring $text -step $step

                        # Fallback to PowerShell method
                        $text = "Fallback: Using PowerShell Remove-Item for $regKey"; Logline -logstring $text -step $step
                        Remove-Item -Path $regKey -Recurse -Force -ErrorAction SilentlyContinue

                        if (-not (Test-Path $regKey)) {
                            $text = "Successfully removed with PowerShell: $regKey"; Logline -logstring $text -step $step
                        } else {
                            $text = "WARNING: Registry key still exists: $regKey"; Logline -logstring $text -step $step
                        }
                    }
                }
                catch {
                    $text = "Error force removing registry key $regKey : $_"; Logline -logstring $text -step $step

                    # Final attempt with direct WMI registry manipulation

                    try {
                        $text = "Final attempt using WMI StdRegProv for $regKey"; Logline -logstring $text -step $step
                        $regProvider = [wmiclass]"\\.\root\default:StdRegProv"
                        $hive = 2147483650 # HKEY_LOCAL_MACHINE
                        $keyPath = ($regKey -replace "HKLM:\\", "") -replace "\\", "\"
                        $result = $regProvider.DeleteKey($hive, $keyPath)

                        if ($result.ReturnValue -eq 0) {
                            $text = "Successfully removed with WMI: $regKey"; Logline -logstring $text -step $step
                        } else {
                            $text = "WMI deletion failed with return code: $($result.ReturnValue) for $regKey"; Logline -logstring $text -step $step
                        }
                    }
                    catch {
                        $text = "WMI registry deletion also failed for $regKey : $_"; Logline -logstring $text -step $step
                    }
                }
            }
        }

        # Clean up any remaining Programs and Features entries
        $text = "Cleaning up Programs and Features entries"; Logline -logstring $text -step $step
        $uninstallPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        )

        foreach ($uninstallPath in $uninstallPaths) {
            if (Test-Path $uninstallPath) {
                $uninstallEntries = Get-ChildItem -Path $uninstallPath -ErrorAction SilentlyContinue |
                    Where-Object {
                        $props = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
                        $props -and (
                            ($props.DisplayName -like "*IBM*" -and ($props.DisplayName -like "*Tivoli*" -or $props.DisplayName -like "*ITM*" -or $props.DisplayName -like "*monitoring*")) -or
                            ($props.Publisher -like "*IBM*" -and ($props.DisplayName -like "*Tivoli*" -or $props.DisplayName -like "*ITM*" -or $props.DisplayName -like "*monitoring*"))
                        )
                    }

                foreach ($entry in $uninstallEntries) {
                    $props = Get-ItemProperty -Path $entry.PSPath -ErrorAction SilentlyContinue
                    $text = "Force removing Programs and Features entry: $($props.DisplayName)"; Logline -logstring $text -step $step
                    try {
                        Remove-Item -Path $entry.PSPath -Recurse -Force
                        $text = "Successfully force removed entry: $($props.DisplayName)"; Logline -logstring $text -step $step
                    }
                    catch {
                        $text = "Error force removing Programs and Features entry $($props.DisplayName): $_"; Logline -logstring $text -step $step
                    }
                }
            }
        }
    }
    catch {
        $text = "Error during force cleanup of registry entries: $_"; Logline -logstring $text -step $step
    }

    # Verify aggressive registry cleanup results
    $text = "Verifying aggressive registry cleanup results"; Logline -logstring $text -step $step
    try {
        $remainingKeys = 0
        $stubborn_registry_keys = @(
            "HKLM:\SOFTWARE\Candle",
            "HKLM:\SOFTWARE\Wow6432Node\Candle",
            "HKLM:\SYSTEM\CurrentControlSet\Services\Candle",
            "HKLM:\SOFTWARE\IBM\ITM",
            "HKLM:\SOFTWARE\Wow6432Node\IBM\ITM",
            "HKLM:\SOFTWARE\IBM\Tivoli",
            "HKLM:\SOFTWARE\Wow6432Node\IBM\Tivoli"
        )

        foreach ($regKey in $stubborn_registry_keys) {
            if (Test-Path $regKey) {
                $remainingKeys++
                $text = "STILL EXISTS: $regKey"; Logline -logstring $text -step $step
            } else {
                $text = "SUCCESSFULLY REMOVED: $regKey"; Logline -logstring $text -step $step
            }
        }

        if ($remainingKeys -eq 0) {
            $text = "SUCCESS: All targeted ITM registry keys have been removed"; Logline -logstring $text -step $step
        } else {
            $text = "WARNING: $remainingKeys registry keys still remain after aggressive cleanup"; Logline -logstring $text -step $step
        }
    }
    catch {
        $text = "Error verifying registry cleanup: $_"; Logline -logstring $text -step $step
    }

    # Force cleanup of any remaining empty ITM directories
    $text = "Force cleanup of any remaining ITM directories and subdirectories"; Logline -logstring $text -step $step
    try {
        $itmRootPath = "C:\IBM\ITM"
        if (Test-Path $itmRootPath) {
            # Get all subdirectories first
            $subDirectories = Get-ChildItem -Path $itmRootPath -Directory -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName -Descending

            foreach ($subDir in $subDirectories) {
                if (Test-Path $subDir.FullName) {
                    $text = "Force removing subdirectory: $($subDir.FullName)"; Logline -logstring $text -step $step
                    try {
                        Remove-Item -Path $subDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
                        if (-not (Test-Path $subDir.FullName)) {
                            $text = "Successfully removed: $($subDir.FullName)"; Logline -logstring $text -step $step
                        } else {
                            # Directory is locked, use handle.exe to find and kill locking processes
                            $text = "Subdirectory $($subDir.FullName) is locked. Using handle.exe to identify locking processes"; Logline -logstring $text -step $step

                            $handleCmd = "${scriptBin}/handle.exe `"$($subDir.FullName)`" -accepteula -nobanner"
                            try {
                                $handleResult = & cmd /C $handleCmd
                                $text = "Handle output: $handleResult"; Logline -logstring $text -step $step

                                # Parse and kill locking processes
                                $handleLines = $handleResult -split "`n"
                                foreach ($line in $handleLines) {
                                    if ($line -match "^(.+?\.exe)\s+pid:\s*(\d+)\s+type:\s*File\s+([0-9A-Fa-f]+):\s*(.+)") {
                                        $processName = $matches[1].Trim()
                                        $processId = $matches[2].Trim()
                                        $handleId = $matches[3].Trim()
                                        $filePath = $matches[4].Trim()

                                        $text = "Killing locking process: $processName (PID: $processId)"; Logline -logstring $text -step $step
                                        $success = Stop-ProcessWithFallback -ProcessName $processName -ProcessId $processId
                                        if ($success) {
                                            $text = "Successfully killed process: $processName (PID: $processId)"; Logline -logstring $text -step $step
                                        } else {
                                            $text = "Failed to kill process $processId with all methods"; Logline -logstring $text -step $step
                                        }
                                    }
                                }

                                # Wait for processes to terminate
                                Start-Sleep -Seconds 3

                                # Try to remove the subdirectory again
                                Remove-Item -Path $subDir.FullName -Recurse -Force -ErrorAction SilentlyContinue

                                if (-not (Test-Path $subDir.FullName)) {
                                    $text = "Successfully removed subdirectory after killing locking processes: $($subDir.FullName)"; Logline -logstring $text -step $step
                                } else {
                                    $text = "WARNING: Subdirectory still exists even after killing locking processes: $($subDir.FullName)"; Logline -logstring $text -step $step
                                }
                            }
                            catch {
                                $text = "Error using handle.exe on $($subDir.FullName): $_"; Logline -logstring $text -step $step
                            }
                        }
                    }
                    catch {
                        $text = "Error removing subdirectory $($subDir.FullName): $_"; Logline -logstring $text -step $step
                    }
                }
            }

            # Finally try to remove the root ITM directory
            if (Test-Path $itmRootPath) {
                $text = "Attempting final removal of ITM root directory: $itmRootPath"; Logline -logstring $text -step $step
                try {
                    Remove-Item -Path $itmRootPath -Recurse -Force -ErrorAction SilentlyContinue
                    if (-not (Test-Path $itmRootPath)) {
                        $text = "Successfully removed ITM root directory: $itmRootPath"; Logline -logstring $text -step $step
                    } else {
                        $text = "ITM root directory still exists. Using handle.exe to find and kill locking processes"; Logline -logstring $text -step $step

                        # Use handle.exe to find what's locking the root directory
                        $handleCmd = "${scriptBin}/handle.exe `"$itmRootPath`" -accepteula -nobanner"
                        try {
                            $handleResult = & cmd /C $handleCmd
                            $text = "Handle output for root directory: $handleResult"; Logline -logstring $text -step $step

                            # Parse and kill locking processes
                            $handleLines = $handleResult -split "`n"
                            foreach ($line in $handleLines) {
                                if ($line -match "^(.+?\.exe)\s+pid:\s*(\d+)\s+type:\s*File\s+([0-9A-Fa-f]+):\s*(.+)") {
                                    $processName = $matches[1].Trim()
                                    $processId = $matches[2].Trim()
                                    $handleId = $matches[3].Trim()

                                    $text = "Killing locking process for root directory: $processName (PID: $processId)"; Logline -logstring $text -step $step
                                    $success = Stop-ProcessWithFallback -ProcessName $processName -ProcessId $processId
                                    if ($success) {
                                        $text = "Successfully killed process: $processName (PID: $processId)"; Logline -logstring $text -step $step
                                    } else {
                                        $text = "Failed to kill process $processId with all methods"; Logline -logstring $text -step $step
                                    }
                                }
                            }

                            # Wait for processes to terminate
                            Start-Sleep -Seconds 3

                            # Try to remove the directory again
                            Remove-Item -Path $itmRootPath -Recurse -Force -ErrorAction SilentlyContinue

                            if (-not (Test-Path $itmRootPath)) {
                                $text = "Successfully removed ITM root directory after killing locking processes"; Logline -logstring $text -step $step
                            } else {
                                $text = "WARNING: ITM root directory still exists even after killing locking processes"; Logline -logstring $text -step $step
                            }
                        }
                        catch {
                            $text = "Error using handle.exe on root directory: $_"; Logline -logstring $text -step $step
                        }
                    }
                }
                catch {
                    $text = "Error removing ITM root directory: $_"; Logline -logstring $text -step $step
                }
            }
        }
    }
    catch {
        $text = "Error during force cleanup of directories: $_"; Logline -logstring $text -step $step
    }

    return $true
}

function Get-InstallationLogs {
    param(
        [string]$Phase = "unknown"
    )
    $text = "Checking for ITM installation logs for debugging ($Phase)"; $step++; Logline -logstring $text -step $step

    # Check common log locations
    $logPaths = @(
        "C:\IBM\ITM\logs",
        "$env:TEMP",
        "$env:windir\Temp",
        "C:\Windows\Logs\MsiInstaller"
    )

    foreach ($logPath in $logPaths) {
        if (Test-Path $logPath) {
            $text = "Checking for logs in: $logPath"; Logline -logstring $text -step $step

            # Look for ITM-related logs
            $itmLogs = Get-ChildItem -Path $logPath -Filter "*itm*" -Recurse -ErrorAction SilentlyContinue
            $itmLogs += Get-ChildItem -Path $logPath -Filter "*tivoli*" -Recurse -ErrorAction SilentlyContinue
            $itmLogs += Get-ChildItem -Path $logPath -Filter "*install*" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-1) }

            if ($itmLogs -and $itmLogs.Count -gt 0) {
                $text = "Found $($itmLogs.Count) potential ITM logs"; Logline -logstring $text -step $step

                foreach ($log in $itmLogs) {
                    $text = "Found log: $($log.FullName)"; Logline -logstring $text -step $step

                    # For text log files, try to extract error messages (only during post-uninstall phase)
                    if ($log.Extension -in ".log", ".txt" -and $Phase -eq "post-uninstall") {
                        # Skip scanning our own active log file to avoid recursive errors
                        if ($log.FullName -eq $global:logfile) {
                            $text = "Skipping scan of active log file: $($log.FullName)"; Logline -logstring $text -step $step
                            continue
                        }

                        try {
                            $text = "Scanning log for errors: $($log.FullName)"; Logline -logstring $text -step $step

                            # Read file with better error handling
                            $logContent = @()
                            try {
                                $logContent = Get-Content -Path $log.FullName -ErrorAction Stop
                            }
                            catch {
                                $text = "Cannot read log file (may be locked): $($log.FullName)"; Logline -logstring $text -step $step
                                continue
                            }

                            # Only process if we got valid line content
                            if ($logContent -and $logContent.Count -gt 0) {
                                $errorLines = $logContent | Where-Object {
                                    $_ -and $_.Length -gt 10 -and $_ -match "error|fail|except|warning"
                                }

                                if ($errorLines -and $errorLines.Count -gt 0) {
                                    $text = "Found $($errorLines.Count) error lines in log"; Logline -logstring $text -step $step
                                    # Show only last 5 errors to avoid log spam
                                    $lastErrors = if ($errorLines.Count -gt 5) { $errorLines[-5..-1] } else { $errorLines }
                                    foreach ($line in $lastErrors) {
                                        if ($line -and $line.Trim().Length -gt 0) {
                                            Logline -logstring "LOG ERROR: $($line.Trim())" -step $step
                                        }
                                    }
                                }
                            }
                        }
                        catch {
                            $text = "Error reading log file $($log.FullName): $_"; Logline -logstring $text -step $step
                        }
                    }
                    elseif ($log.Extension -in ".log", ".txt" -and $Phase -eq "pre-uninstall") {
                        $text = "Skipping error scan during pre-uninstall phase to avoid false positives from previous runs"; Logline -logstring $text -step $step
                    }
                }
            }
            else {
                $text = "No ITM-related logs found in $logPath"; Logline -logstring $text -step $step
            }
        }
    }

    # Check Windows Event Log for MSI installer events
    $text = "Checking Windows Event Log for MSI installer events"; Logline -logstring $text -step $step
    try {
        # Check if Get-WinEvent cmdlet is available to avoid auto-import issues in restricted environments
        if (Test-CmdletAvailable "Get-WinEvent") {
            $msiEvents = Get-WinEvent -FilterHashtable @{LogName = "Application"; ProviderName = "MsiInstaller" } -MaxEvents 10 -ErrorAction SilentlyContinue |
            Where-Object { ($_.Message -like "*IBM*" -and ($_.Message -like "*Tivoli*" -or $_.Message -like "*ITM*" -or $_.Message -like "*monitoring*")) }

            if ($msiEvents -and $msiEvents.Count -gt 0) {
                $text = "Found $($msiEvents.Count) MSI installer events related to ITM"; Logline -logstring $text -step $step
                foreach ($event in $msiEvents) {
                    $text = "Event ID $($event.Id) (Level: $($event.LevelDisplayName)) at $($event.TimeCreated): $($event.Message)"; Logline -logstring $text -step $step
                }
            }
            else {
                $text = "No relevant MSI installer events found"; Logline -logstring $text -step $step
            }
        }
        else {
            $text = "Get-WinEvent cmdlet not available - skipping Windows Event Log check"; Logline -logstring $text -step $step
        }
    }
    catch {
        $text = "Error retrieving Windows Event Log: $_"; Logline -logstring $text -step $step
    }
}

function Show-RemainingRegistryEntries {
    $text = "--- FINAL REGISTRY SCAN FOR REMAINING ITM ENTRIES ---"; $step++; Logline -logstring $text -step $step

    # Check standard ITM registry locations
    $registryLocations = @(
        "HKLM:\SOFTWARE\Candle",
        "HKLM:\SOFTWARE\Wow6432Node\Candle",
        "HKLM:\SYSTEM\CurrentControlSet\Services\Candle",
        "HKLM:\SYSTEM\CurrentControlSet\Services\IBM\ITM",
        "HKLM:\SOFTWARE\IBM\ITM",
        "HKLM:\SOFTWARE\Wow6432Node\IBM\ITM",
        "HKLM:\SOFTWARE\IBM\Tivoli",
        "HKLM:\SOFTWARE\Wow6432Node\IBM\Tivoli"
    )

    $foundRegistryEntries = $false

    foreach ($regPath in $registryLocations) {
        if (Test-Path $regPath) {
            $foundRegistryEntries = $true
            $text = "WARNING: Found remaining registry key: $regPath"; Logline -logstring $text -step $step

            # Try to show some details about what's in the key
            try {
                $subKeys = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue
                if ($subKeys -and $subKeys.Count -gt 0) {
                    $text = "  Contains $($subKeys.Count) subkeys: $($subKeys.Name -join ', ')"; Logline -logstring $text -step $step
                }

                $values = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
                if ($values) {
                    $valueNames = ($values.PSObject.Properties | Where-Object { $_.Name -notmatch "^PS" }).Name
                    if ($valueNames -and $valueNames.Count -gt 0) {
                        $text = "  Contains values: $($valueNames -join ', ')"; Logline -logstring $text -step $step
                    }
                }
            }
            catch {
                $text = "  Error reading registry details: $_"; Logline -logstring $text -step $step
            }
        }
    }

    # Check Programs and Features for remaining ITM entries
    $text = "Checking Programs and Features for remaining ITM entries"; Logline -logstring $text -step $step

    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    foreach ($uninstallPath in $uninstallPaths) {
        if (Test-Path $uninstallPath) {
            try {
                $itmUninstallEntries = Get-ChildItem -Path $uninstallPath -ErrorAction SilentlyContinue |
                    Where-Object {
                        $props = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
                        $props -and (
                            ($props.DisplayName -like "*IBM*" -and ($props.DisplayName -like "*Tivoli*" -or $props.DisplayName -like "*ITM*" -or $props.DisplayName -like "*monitoring*")) -or
                            ($props.Publisher -like "*IBM*" -and ($props.DisplayName -like "*Tivoli*" -or $props.DisplayName -like "*ITM*" -or $props.DisplayName -like "*monitoring*"))
                        )
                    }

                if ($itmUninstallEntries -and $itmUninstallEntries.Count -gt 0) {
                    $foundRegistryEntries = $true
                    $text = "WARNING: Found $($itmUninstallEntries.Count) remaining Programs and Features entries"; Logline -logstring $text -step $step

                    foreach ($entry in $itmUninstallEntries) {
                        $props = Get-ItemProperty -Path $entry.PSPath -ErrorAction SilentlyContinue
                        if ($props) {
                            $text = "  - $($props.DisplayName) (Publisher: $($props.Publisher)) (Key: $($entry.PSChildName))"; Logline -logstring $text -step $step
                        }
                    }
                }
            }
            catch {
                $text = "Error checking uninstall entries in $uninstallPath : $_"; Logline -logstring $text -step $step
            }
        }
    }

    # Perform a broader search for any remaining IBM/ITM references in the registry
    $text = "Performing broader registry search for IBM/ITM references"; Logline -logstring $text -step $step
    $allServices = Get-ServicesWithFallback

    # Filter for services that might be ITM-related, excluding TSM
    $itmRelatedServices = $allServices | Where-Object {
        ($_.Name -like "*IBM*" -or $_.DisplayName -like "*IBM*" -or $_.Name -like "*Tivoli*" -or $_.DisplayName -like "*Tivoli*" -or $_.Name -like "*Candle*" -or $_.DisplayName -like "*Candle*") -and
        ($_.Name -notlike "*TSM*" -and $_.DisplayName -notlike "*TSM*" -and $_.DisplayName -notlike "*Tivoli Storage*" -and $_.DisplayName -notlike "*Storage Management*")
    }

    if ($itmRelatedServices -and $itmRelatedServices.Count -gt 0) {
        $text = "WARNING: Found $($itmRelatedServices.Count) potentially ITM-related service registry entries"; Logline -logstring $text -step $step
        foreach ($svc in $itmRelatedServices) {
            $text = "  - Service: $($svc.DisplayName)"; Logline -logstring $text -step $step
        }
    }

    if (-not $foundRegistryEntries) {
        $text = "SUCCESS: No remaining ITM-related registry entries found"; Logline -logstring $text -step $step
    }

    $text = "--- END OF FINAL REGISTRY SCAN ---"; Logline -logstring $text -step $step
}

function Remove-AdditionalDirectories {
    $text = "--- CHECKING ADDITIONAL DIRECTORIES FOR REMOVAL ---"; Logline -logstring $text -step $step
    $anyDirsNotRemoved = $false

    foreach ($dir in $global:RemoveDirs) {
        if (Test-Path $dir) {
            try {
                Remove-Item -Path $dir -Recurse -Force -Confirm:$false -ErrorAction Stop
                $text = "SUCCESS: Directory removed: $dir"; Logline -logstring $text -step $step
            }
            catch {
                $text = "WARNING: Failed to remove directory $dir. Attempting recursive deletion of contents."; Logline -logstring $text -step $step
                $anyDirsNotRemoved = $true
                try {
                    # Get all child items (files and directories)
                    $childItems = Get-ChildItem -Path $dir -Recurse -Force -ErrorAction SilentlyContinue

                    # Sort items to delete files before directories
                    $files = $childItems | Where-Object { -not $_.PSIsContainer } | ForEach-Object { $_.FullName }
                    $subDirectories = $childItems | Where-Object { $_.PSIsContainer } | Sort-Object { $_.FullName.Length } -Descending | ForEach-Object { $_.FullName }

                    # Remove files first
                    foreach ($file in $files) {
                        try {
                            Remove-Item -Path $file -Force -Confirm:$false -ErrorAction Stop
                            $text = "SUCCESS: Removed file: $file"; Logline -logstring $text -step $step
                        } catch {
                            $text = "ERROR: Failed to remove file: $file. Details: $_"; Logline -logstring $text -step $step
                        }
                    }

                    # Then remove directories
                    foreach ($subDir in $subDirectories) {
                        try {
                            Remove-Item -Path $subDir -Force -Confirm:$false -ErrorAction Stop
                            $text = "SUCCESS: Removed directory: $subDir"; Logline -logstring $text -step $step
                        } catch {
                            $text = "ERROR: Failed to remove directory: $subDir. Details: $_"; Logline -logstring $text -step $step
                        }
                    }

                    # Final attempt to remove the top-level directory
                    $text = "Retrying to remove the top-level directory: $dir"; Logline -logstring $text -step $step
                    Remove-Item -Path $dir -Recurse -Force -Confirm:$false -ErrorAction Stop
                    $text = "Successfully removed directory: $dir"; Logline -logstring $text -step $step
                }
                catch {
                    $finalError = $_.Exception.Message
                    $text = "FINAL ERROR: Failed to remove directory $dir after all attempts. Reason: $finalError"; Logline -logstring $text -step $step
                }
            }
        }
        else {
            $text = "Directory not found, skipping: $dir"; Logline -logstring $text -step $step
        }
    }

    if ($anyDirsNotRemoved) {
        $text = "WARNING: Some additional directories could not be removed"