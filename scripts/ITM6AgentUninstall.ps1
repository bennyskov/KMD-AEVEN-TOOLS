# Enhanced error handling and output suppression
# - Set ErrorActionPreference and VerbosePreference to SilentlyContinue
# - Added error handling to Logline function to prevent file access issues
# - Added ErrorAction SilentlyContinue to WMI calls and file operations
# - Removed verbose flags from process operations

$defaultErrorActionPreference = 'SilentlyContinue'
# $defaultErrorActionPreference = 'Continue'
$global:ErrorActionPreference = $defaultErrorActionPreference
$global:VerbosePreference = "SilentlyContinue"  # Disable verbose logging

# Disable automatic module loading to prevent import issues in restricted environments (DMZ)
# This prevents the 'mport-Module' error when cmdlets trigger auto-import
$PSModuleAutoLoadingPreference = "None"
$global:PSModuleAutoLoadingPreference = "None"

$global:scriptName = $myinvocation.mycommand.Name

function Get-ITMStatusReport {
    $text = "Collecting comprehensive ITM status report"; $step++; Logline -logstring $text -step $step

    # Verify ITM installation paths
    $text = "--- ITM INSTALLATION PATHS ---"; Logline -logstring $text -step $step
    $itmPaths = @(
        "C:\IBM\ITM"
    )

    foreach(${path} in $itmPaths) {
        if(Test-Path ${path}) {
            $text = "Found ITM installation at: ${path}"; Logline -logstring $text -step $step
            $files = Get-ChildItem -Path ${path} -Recurse -ErrorAction SilentlyContinue | Measure-Object
            $text = "Path contains $($files.Count) files/folders"; Logline -logstring $text -step $step

            # Get exe files for more details
            $exeFiles = Get-ChildItem -Path ${path} -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 5
            if($exeFiles -and $exeFiles.Count -gt 0) {
                $text = "Key executable files found:"; Logline -logstring $text -step $step
                $exeFiles | ForEach-Object { Logline -logstring "- $($_.FullName)" -step $step }
            }
        } else {
            $text = "ITM installation not found at: ${path}"; Logline -logstring $text -step $step
        }
    }

    # Check Services
    $text = "--- ITM SERVICES ---"; Logline -logstring $text -step $step
    try {
        $itmServices = Get-ServicesWithFallback -ServicePattern "^k" -DisplayNamePattern "monitoring Agent"
        if (-not $itmServices) {
            $itmServices = Get-ServicesWithFallback | Where-Object {
                ($_.Name -match "^k" -and ($_.DisplayName -match "monitoring Agent" -or $_.DisplayName -like "*ITM*")) -or
                (($_.Name -like "*IBM*" -or ($_.Name -like "*Tivoli*" -and $_.Name -notlike "*TSM*" -and $_.DisplayName -notlike "*Storage*")) -and ($_.DisplayName -match "monitoring Agent" -or $_.DisplayName -like "*ITM*" -or $_.DisplayName -like "*Candle*"))
            }
            # Explicitly filter out any TSM (Tivoli Storage Management) related services
            $itmServices = $itmServices | Where-Object {
                -not ($_.Name -like "*TSM*" -or $_.DisplayName -like "*TSM*" -or
                      $_.DisplayName -like "*Tivoli Storage*" -or $_.DisplayName -like "*Storage Management*")
            }
        }
    }
    catch {
        $text = "Error checking ITM services: $_"; Logline -logstring $text -step $step
        $itmServices = @()
    }

    if($itmServices -and $itmServices.Count -gt 0) {
        $text = "Found $($itmServices.Count) ITM related services"; Logline -logstring $text -step $step
        $itmServices | Select-Object Name, DisplayName, Status, StartType | Format-Table -AutoSize |
            Out-String -Width 300 | ForEach-Object { Logline -logstring $_ -step $step }
    } else {
        $text = "No ITM services found"; Logline -logstring $text -step $step
    }

    # Check Registry
    $text = "--- ITM REGISTRY ENTRIES ---"; Logline -logstring $text -step $step
    $regPaths = @(
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
    foreach($regPath in $regPaths) {
        if(Test-Path $regPath) {
            $foundRegistryEntries = $true
            $text = "Found ITM registry entries at: $regPath"; Logline -logstring $text -step $step
            try {
                $regKeys = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue
                if($regKeys -and $regKeys.Count -gt 0) {
                    $text = "Registry path contains $($regKeys.Count) keys/values"; Logline -logstring $text -step $step
                }
            } catch {
                $text = "Error reading registry path: $_"; Logline -logstring $text -step $step
            }
        }
    }

    if(-not $foundRegistryEntries) {
        $text = "No ITM registry entries found"; Logline -logstring $text -step $step
    }

    # Check installed software
    $text = "--- ITM INSTALLED SOFTWARE ---"; Logline -logstring $text -step $step
    try {
        if (Test-CmdletAvailable "Get-WmiObject") {
            $itmProducts = Get-WmiObject -Class Win32_Product -ErrorAction SilentlyContinue | Where-Object {
                (($_.Name -like "*IBM*" -or $_.Vendor -like "*IBM*") -and ($_.Name -like "*Tivoli*" -or $_.Name -like "*ITM*" -or $_.Name -like "*Monitoring*" -or $_.Name -like "*Candle*"))
            }
        }
        else {
            $text = "Get-WmiObject cmdlet not available - skipping installed software check"; Logline -logstring $text -step $step
            $itmProducts = @()
        }
    }
    catch {
        $text = "Error accessing WMI for installed software check: $_"; Logline -logstring $text -step $step
        $itmProducts = @()
    }

    if($itmProducts -and $itmProducts.Count -gt 0) {
        $text = "Found $($itmProducts.Count) IBM/ITM related software packages"; Logline -logstring $text -step $step
        foreach($product in $itmProducts) {
            $text = "Product: $($product.Name), Version: $($product.Version), Vendor: $($product.Vendor), GUID: $($product.IdentifyingNumber)";
            Logline -logstring $text -step $step

            # Get uninstall string
            try {
                $uninstall = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -eq $product.Name }
                if(-not $uninstall) {
                    $uninstall = Get-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
                    Where-Object { $_.DisplayName -eq $product.Name }
                }

                if($uninstall) {
                    $text = "Uninstall string: $($uninstall.UninstallString)"; Logline -logstring $text -step $step
                }
            } catch {
                $text = "Error getting uninstall string: $_"; Logline -logstring $text -step $step
            }
        }
    } else {
        $text = "No IBM/ITM related software found in Windows installer database"; Logline -logstring $text -step $step
    }

    # Check for ITM processes
    $text = "--- ITM RUNNING PROCESSES ---"; Logline -logstring $text -step $step
    $itmProcesses = Get-Process | Where-Object {
        ($_.Name -match "^k" -and ($_.Path -like "*IBM\ITM*" -or $_.Company -like "*IBM*")) -or
        (($_.Company -like "*IBM*" -or $_.Name -like "*ITM*") -and $_.Path -like "*IBM\ITM*")
    }

    if($itmProcesses -and $itmProcesses.Count -gt 0) {
        $text = "Found $($itmProcesses.Count) ITM related processes"; Logline -logstring $text -step $step
        $itmProcesses | Select-Object Id, Name, Path | Format-Table -AutoSize |
            Out-String -Width 300 | ForEach-Object { Logline -logstring $_ -step $step }
    } else {
        $text = "No ITM processes currently running"; Logline -logstring $text -step $step
    }

    # Check for ITM scheduled tasks
    $text = "--- ITM SCHEDULED TASKS ---"; Logline -logstring $text -step $step
    try {
        if (Test-CmdletAvailable "Get-ScheduledTask") {
            $itmTasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
                ($_.TaskName -like "*IBM*" -and ($_.TaskName -like "*ITM*" -or $_.TaskName -like "*Tivoli*" -or $_.TaskName -like "*monitoring*")) -or
                ($_.Description -like "*IBM*" -and ($_.Description -like "*ITM*" -or $_.Description -like "*Tivoli*" -or $_.Description -like "*monitoring*"))
            }

            if($itmTasks -and $itmTasks.Count -gt 0) {
                $text = "Found $($itmTasks.Count) ITM related scheduled tasks"; Logline -logstring $text -step $step
                $itmTasks | Select-Object TaskName, State | Format-Table -AutoSize |
                    Out-String -Width 300 | ForEach-Object { Logline -logstring $_ -step $step }
            } else {
                $text = "No ITM scheduled tasks found"; Logline -logstring $text -step $step
            }
        } else {
            $text = "Get-ScheduledTask cmdlet not available - skipping scheduled tasks check"; Logline -logstring $text -step $step
        }
    } catch {
        $text = "Get-ScheduledTask cmdlet not available - skipping scheduled tasks check"; Logline -logstring $text -step $step
    }

    $text = "----- END OF ITM STATUS REPORT -----"; Logline -logstring $text -step $step
}

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
# Convert log file path back to Windows format for compatibility
$global:logfile = $global:logfile -replace "/", "\"
if (Test-Path $logfile) { Remove-Item -Path $logfile -Force -ErrorAction SilentlyContinue }
$global:continue = $true
# ----------------------------------------------------------------------------------------------------------------------------
# Helper Functions
# ----------------------------------------------------------------------------------------------------------------------------
function Test-CmdletAvailable {
    param([string]$CmdletName)

    try {
        return [bool](Get-Command $CmdletName -ErrorAction SilentlyContinue)
    }
    catch {
        return $false
    }
}

# ----------------------------------------------------------------------------------------------------------------------------
# Logline
# ----------------------------------------------------------------------------------------------------------------------------
Function Logline {
    Param ([string]$logstring, $step)
    $now = (get-date -format "yyyy-MM-dd HH:mm:ss.fff")
    $text = ( "{0,-23} : $hostname : step {1:d4} : {2}" -f $now, $step, $logstring)

    # Try to write to log file with error handling
    try {
        Add-content -LiteralPath $global:logfile -value $text -Force -ErrorAction Stop
    } catch {
        # If file is locked or inaccessible, continue without logging to file
        # This prevents the script from failing due to logging issues
    }

    # Add color output to help with visibility
    if ($logstring -match "error|fail|exception|not found") {
        Write-Host $text -ForegroundColor Red
    } elseif ($logstring -match "warning") {
        Write-Host $text -ForegroundColor Yellow
    } elseif ($logstring -match "success|done|complete") {
        Write-Host $text -ForegroundColor Green
    } else {
        Write-Host $text -ForegroundColor Cyan
    }
}
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
# $global:UninstCmdexec = @("start", "/WAIT", "/MIN", "`"${UninstPath}`"", "-batchrmvall", "-removegskit")
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
    # Skipping "C:/Windows/Temp/KMD-AEVEN-TOOLS" as script runs from this location
)
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
# ----------------------------------------------------------------------------------------------------------------------------
# functions
# ----------------------------------------------------------------------------------------------------------------------------
function Test-lastUninstall {
    try {
        # ${UninstName} = ''
        $continue = $true
        $runningProcesses = Get-ProcessesWithFallback -ProcessPattern "${UninstName}"
        if ($runningProcesses) {
            $text = "stop ${UninstName} if UninstPath is still running from last run."; $step++; Logline -logstring $text -step $step
            foreach ($proc in $runningProcesses) {
                Stop-ProcessWithFallback -ProcessName $proc.Name -ProcessId $proc.Id
            }
        }
        $runningProcesses = Get-ProcessesWithFallback -ProcessPattern "${UninstName}"
        if ($runningProcesses) {
            $text = "${UninstName} is still running. We try stopping it using psKill"; Logline -logstring $text -step $step
            $cmdexec = "$scriptBin\pskill.exe -t $UninstName -accepteula -nobanner"
            Logline -logstring $cmdexec -step $step
            $result = & cmd /C $cmdexec
            Logline -logstring $result -step $step

            $runningProcesses = Get-ProcessesWithFallback -ProcessPattern "${UninstName}"
            if ($runningProcesses) {
                $text = "${UninstName} is still running. We must break now"; Logline -logstring $result -step $step
                $continue = $false
            }
        }
        else {
            $text = "${UninstName} is not hanging around from last run"; Logline -logstring $text -step $step
        }
    }
    catch {
        $errorMsg = $_.ToString()
        Logline -logstring $errorMsg -step $step
    }    return $continue
}
function Start-ProductAgent {
    try {
        $IsAgentsStarted = $false
        $text = "Start ${DisplayName} agents"; $step++; Logline -logstring $text -step $step
        $services = Get-ServicesWithFallback -ServicePattern "${ServiceName}" -DisplayNamePattern "${DisplayName}"

        if ($services.Count -gt 0) {
            $text = "Found $($services.Count) services matching pattern '${ServiceName}' with display name matching '${DisplayName}'"; Logline -logstring $text -step $step
            $services | Select-Object Name, DisplayName, Status | Format-Table -AutoSize | Out-String -Width 300 | ForEach-Object { Logline -logstring $_ -step $step }
        }
        else {
            $text = "No monitoring agent services found matching criteria"; Logline -logstring $text -step $step
        }

        foreach ($service in $services) {
            if ( -not $($service).Name -imatch "FCProvider" ) {
                $text = "Processing service: $($service.Name) ($($service.DisplayName))"; Logline -logstring $text -step $step
                $text = "Stopping service $($service.Name)..."; Logline -logstring $text -step $step
                Stop-ServiceWithFallback -ServiceName $service.Name
                $text = "Setting startup type to Automatic for $($service.Name)..."; Logline -logstring $text -step $step
                $service | Set-Service -StartupType Automatic
                $text = "Starting service $($service.Name)..."; Logline -logstring $text -step $step
                Start-ServiceWithFallback -ServiceName $service.Name
                $text = "Service $($service.Name) status: $($service.Status)"; Logline -logstring $text -step $step
            }
            else {
                $text = "Skipping FCProvider service: $($service.Name)"; Logline -logstring $text -step $step
            }
        }
    }
    catch {
        $errorMsg = $_.ToString()
        Logline -logstring "error: $errorMsg" -step $step
    }

    if ($services.Count -eq 0) {
        $IsAgentsStarted = "Skipped"
    }
    elseif ( Test-IsAgentsStopped -eq $false ) {
        $IsAgentsStarted = $true
    }
    $text = "Agents started status: $IsAgentsStarted"; Logline -logstring $text -step $step $text = "Final services status:"; Logline -logstring $text -step $step
    Show-AgentStatus

    $runningServices = Get-ServicesWithFallback -ServicePattern "${ServiceName}" -DisplayNamePattern "${DisplayName}" | Where-Object { $_.Status -eq "Running" }

    if ($runningServices -and $runningServices.Count -gt 0) {
        $text = "Monitoring agent services running: $($runningServices.Count)"; Logline -logstring $text -step $step
        $runningServices | Select-Object Name, DisplayName, Status | Format-Table -AutoSize | Out-String -Width 300 | ForEach-Object { Logline -logstring $_ -step $step }
    }
    else {
        $text = "No monitoring agent services found in running state"; Logline -logstring $text -step $step
    }

    return $IsAgentsStarted
}
# $(Get-WmiObject Win32_Process | Where-Object Name -imatch "power")
function Stop-ProductAgent {
    try {
        $IsAgentsStopped = $false
        if ( -not $IsAgentsStopped ) {
            $text = "stop Method 1: Stop all ${DisplayName} agents using Stop-Service"; $step++; Logline -logstring $text -step $step
            $servicesToStop = Get-ServicesWithFallback -ServicePattern "${ServiceName}" -DisplayNamePattern "${DisplayName}"

            if ($servicesToStop -and $servicesToStop.Count -gt 0) {
                $text = "Found $($servicesToStop.Count) monitoring agent services to stop"; Logline -logstring $text -step $step
                $servicesToStop | Select-Object Name, DisplayName, Status | Format-Table -AutoSize | Out-String -Width 300 | ForEach-Object { Logline -logstring $_ -step $step }
            }
            else {
                $text = "No monitoring agent services found to stop"; Logline -logstring $text -step $step
            }

            foreach ($service in $servicesToStop) {
                if ( $disable ) { $service | Set-Service -StartupType Disabled }
                Stop-ServiceWithFallback -ServiceName $service.Name
            }
            if ( Test-IsAgentsStopped -eq $true ) { $IsAgentsStopped = $true }
        }

        if ( -not $IsAgentsStopped ) {
            $text = "stop Method 2: Stop ${DisplayName} using process termination"; $step++; Logline -logstring $text -step $step

            # Try WMI first if available
            $ReturnValue = @()
            if (Test-CmdletAvailable "Get-WmiObject") {
                try {
                    $ReturnValue = $(Get-WmiObject Win32_Process -ErrorAction SilentlyContinue | Where-Object CommandLine -match "${CommandLine}" | ForEach-Object { $_.Terminate() }).ReturnValue
                } catch {
                    $text = "WMI process termination failed: $_"; Logline -logstring $text -step $step
                }
            }

            # Fallback to direct process killing by name patterns
            if (-not $ReturnValue) {
                $processNames = @("k06agent", "kcawd", "kntcma", "klzagent", "k*agent")
                foreach ($processName in $processNames) {
                    $processes = Get-ProcessesWithFallback -ProcessPattern $processName
                    foreach ($proc in $processes) {
                        $success = Stop-ProcessWithFallback -ProcessName $proc.Name -ProcessId $proc.Id
                        if ($success) {
                            $text = "Successfully killed process: $($proc.Name) (ID: $($proc.Id))"; Logline -logstring $text -step $step
                        } else {
                            $text = "Failed to kill process $($proc.Name) (ID: $($proc.Id))"; Logline -logstring $text -step $step
                        }
                    }
                }
            }

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
            $servicesToStop = $(Get-ServicesWithFallback -ServicePattern "${ServiceName}" -DisplayNamePattern "${DisplayName}").Name
            foreach ($service in $servicesToStop) {
                $cmdexec = "net stop $service"
                $result = & cmd /C $cmdexec
                Logline -logstring "$result"
            }
            if ( Test-IsAgentsStopped -eq $true ) { $IsAgentsStopped = $true }
        }

        if ( -not $IsAgentsStopped ) {
            $text = "stop Method 4: Stop ${DisplayName} using 'psKill service'"; $step++; Logline -logstring $text -step $step
            $servicesToKill = Get-ServicesWithFallback -ServicePattern "${ServiceName}" -DisplayNamePattern "${DisplayName}"
            foreach ($service in $servicesToKill) {
                $text = "${service} is still running. We try stopping it using psKill"; Logline -logstring $result -step $step
                $cmdexec = "$scriptBin\pskill.exe -t $service -accepteula -nobanner"
                Logline -logstring $cmdexec -step $step
                $result = & cmd /C $cmdexec
                Logline -logstring $result -step $step
            }
            if ( Test-IsAgentsStopped -eq $true ) { $IsAgentsStopped = $true }
        }

        if ( -not $IsAgentsStopped ) {
            $text = "stop and disable services"; $step++; Logline -logstring $text -step $step
            $servicesToStop = Get-ServicesWithFallback -ServicePattern "${ServiceName}" -DisplayNamePattern "${DisplayName}"
            foreach ($service in $servicesToStop) {
                if ( $disable ) { $service | Set-Service -StartupType Disabled }
                Stop-ServiceWithFallback -ServiceName $service.Name
            }
            Logline -logstring "$result"
            if ( Test-IsAgentsStopped -eq $true ) { $IsAgentsStopped = $true }
        }
    }
    catch {
        $errorMsg = $_.ToString()
        Logline -logstring $errorMsg -step $step
    }
    Show-AgentStatus
    return $IsAgentsStopped
}
function Uninstall-ProductAgent {
    $text = "run Uninstall ${DisplayName} Agents"; $step++; Logline -logstring $text -step $step

    # Always try to run ITMRmvAll.exe if it exists, regardless of service state
    if (Test-Path "$UninstPath") {
        try {
            $text = "Executing ${UninstName} with parameters: $UninstCmdexec"; Logline -logstring $text -step $step

            # Convert array to a proper command string
            # $cmdString = "cmd /C " + ($UninstCmdexec -join ' ')
            $cmdString = "cmd /C ${UninstCmdexec}"
            $text = "Command to execute: $cmdString"; Logline -logstring $text -step $step

            # Execute the command
            $result = Invoke-Expression $cmdString
            $rc = $?

            if ( $rc ) {
                Logline -logstring "Success. rc=$rc result=$result" -step $step
            }
            else {
                Logline -logstring "Failed. rc=$rc result=$result" -step $step
            }

            $text = "${UninstPath} execution completed"; Logline -logstring $text -step $step
        }
        catch {
            $text = "${UninstName} error: $_"; Logline -logstring $text -step $step
        }
    } else {
        $text = "ITMRmvAll.exe not found at: $UninstPath"; Logline -logstring $text -step $step
    }

    if ( Test-IsAllGone -eq $false ) {
        $text = "uninstall via MsiExec for direct uninstall (if other methods fail)"; $step++; Logline -logstring $text -step $step
        try {
            if (Test-CmdletAvailable "Get-WmiObject") {
                $clientMsi = Get-WmiObject -Class Win32_Product -ErrorAction SilentlyContinue | Where-Object { $_.Description -like "*${DisplayName}*" }
                if ($clientMsi) {
                    $text = "Uninstalling via MSI: $($clientMsi.Name)"; Logline -logstring $text -step $step
                    $result = $clientMsi.Uninstall()
                    $text = "MSI uninstall result: $($result.ReturnValue)"; Logline -logstring $text -step $step
                }
            } else {
                $text = "Get-WmiObject not available - skipping MSI uninstall method"; Logline -logstring $text -step $step
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

    if ( Test-IsAllGone -eq $false ) {
        $text = "Attempting to find and uninstall by product GUID"; $step++; Logline -logstring $text -step $step
        try {
            # Find any IBM ITM related products
            $guidCmd = "wmic product get name,identifyingnumber | findstr /i ""IBM Tivoli ITM"""
            $guidResults = Invoke-Expression $guidCmd
            Logline -logstring "Found product GUIDs: $guidResults" -step $step

            # Extract GUIDs using regex
            $guidMatches = [regex]::Matches($guidResults, '{([0-9A-F-]+)}')
            if ($guidMatches.Count -gt 0) {
                foreach ($match in $guidMatches) {
                    $guid = $match.Groups[1].Value
                    $text = "Found GUID: $guid - attempting direct uninstall"; Logline -logstring $text -step $step
                    $uninstCmd = "msiexec.exe /x {$guid} /qn"
                    Logline -logstring "Running: $uninstCmd" -step $step
                    $result = Invoke-Expression $uninstCmd
                    Start-Sleep -Seconds 10  # Give uninstall some time
                }
            }
            else {
                $text = "No product GUIDs found for direct uninstall"; Logline -logstring $text -step $step
            }
        }
        catch {
            $text = "GUID uninstall error: $_"; Logline -logstring $text -step $step
        }
    }

    return Test-IsAllGone
}
function Test-CleanupRegistry {
    $isAllRegistryGone = $true
    $text = "Clean up registry"; $step++; Logline -logstring $text -step $step

    # Clean up standard ITM registry keys
    foreach ($key in $RegistryKeys) {
        if (Test-Path $key) {
            try {
                $text = "Removing registry key: $key"; Logline -logstring $text -step $step
                Remove-Item -Path $key -Recurse -Force
                $isAllRegistryGone = $true
            }
            catch {
                $text = "Error removing registry key $key : $_"; Logline -logstring $text -step $step
                $isAllRegistryGone = $false
            }
        }
    }

    # Clean up specific ITM entries from Programs and Features (Uninstall registry)
    $text = "Cleaning up ITM entries from Programs and Features"; Logline -logstring $text -step $step

    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    foreach ($uninstallPath in $uninstallPaths) {
        if (Test-Path $uninstallPath) {
            try {
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
                    $text = "Removing Programs and Features entry: $($props.DisplayName)"; Logline -logstring $text -step $step
                    try {
                        Remove-Item -Path $entry.PSPath -Recurse -Force
                        $text = "Successfully removed entry: $($props.DisplayName)"; Logline -logstring $text -step $step
                    }
                    catch {
                        $text = "Error removing Programs and Features entry $($props.DisplayName): $_"; Logline -logstring $text -step $step
                        $isAllRegistryGone = $false
                    }
                }
            }
            catch {
                $text = "Error accessing uninstall entries in $uninstallPath : $_"; Logline -logstring $text -step $step
                $isAllRegistryGone = $false
            }
        }
    }

    # Clean up ITM services by deleting them from the system
    $text = "Removing ITM services from the system"; Logline -logstring $text -step $step
    try {
        $servicesToRemove = Get-ServicesWithFallback | Where-Object {
            ($_.Name -match "^k" -and ($_.DisplayName -match "monitoring Agent" -or $_.DisplayName -like "*ITM*")) -or
            (($_.Name -like "*IBM*" -or ($_.Name -like "*Tivoli*" -and $_.Name -notlike "*TSM*" -and $_.DisplayName -notlike "*Storage*")) -and ($_.DisplayName -match "monitoring Agent" -or $_.DisplayName -like "*ITM*" -or $_.DisplayName -like "*Candle*"))
        }

        # Explicitly filter out any TSM (Tivoli Storage Management) related services
        $servicesToRemove = $servicesToRemove | Where-Object {
            -not ($_.Name -like "*TSM*" -or $_.DisplayName -like "*TSM*" -or
                  $_.DisplayName -like "*Tivoli Storage*" -or $_.DisplayName -like "*Storage Management*")
        }

        if ($servicesToRemove -and $servicesToRemove.Count -gt 0) {
            foreach ($svc in $servicesToRemove) {
                $text = "Removing service: $($svc.Name)"; Logline -logstring $text -step $step

                # First, stop the service if it's running
                try {
                    Stop-ServiceWithFallback -ServiceName $svc.Name
                    Start-Sleep -Seconds 2

                    # Use SC delete to remove the service
                    $cmdString = "sc.exe delete $($svc.Name)"
                    $text = "Executing: $cmdString"; Logline -logstring $text -step $step
                    $result = & cmd /C $cmdString
                    $text = "SC delete result: $result"; Logline -logstring $text -step $step

                    if ($result -match "SUCCESS") {
                        $text = "Successfully removed service: $($svc.Name)"; Logline -logstring $text -step $step
                    }
                }
                catch {
                    $text = "Error removing service $($svc.Name): $_"; Logline -logstring $text -step $step
                    $isAllRegistryGone = $false
                }
            }
        } else {
            $text = "No ITM services found to remove"; Logline -logstring $text -step $step
        }
    }
    catch {
        $text = "Error removing services: $_"; Logline -logstring $text -step $step
        $isAllRegistryGone = $false
    }

    return $isAllRegistryGone
}

function Stop-AllITMProcesses {
    $text = "Forcefully terminating all IBM/ITM related processes"; $step++; Logline -logstring $text -step $step

    # Define specific ITM process names to target
    $itmProcessNames = @(
        "k06agent",
        "kcawd",
        "kntcma",
        "kdc",
        "kdh",
        "klz",
        "kul",
        "kux",
        "kpx",
        "kuira",
        "kglprm",
        "kglmain"
    )

    $processesKilled = $false

    # Method 1: Try using Get-Process if available
    try {
        if (Test-CmdletAvailable "Get-Process") {
            $processesToStop = Get-Process | Where-Object {
                ($_.Name -match "^k" -and ($_.Path -like "*IBM\ITM*" -or $_.Company -like "*IBM*")) -or
                (($_.Company -like "*IBM*" -or $_.Name -like "*ITM*") -and $_.Path -like "*IBM\ITM*") -or
                ($itmProcessNames -contains $_.Name)
            }

            if ($processesToStop -and $processesToStop.Count -gt 0) {
                $text = "Found $($processesToStop.Count) processes to terminate using Get-Process"; Logline -logstring $text -step $step
                $processesToStop | Select-Object Id, Name, Path | Format-Table -AutoSize | Out-String -Width 300 | ForEach-Object { Logline -logstring $_ -step $step }

                foreach ($process in $processesToStop) {
                    $success = Stop-ProcessWithFallback -ProcessName $process.Name -ProcessId $process.Id
                    if ($success) {
                        $text = "Successfully stopped process $($process.Name) (PID: $($process.Id))"; Logline -logstring $text -step $step
                        $processesKilled = $true
                    } else {
                        $text = "Failed to stop process $($process.Name) (PID: $($process.Id))"; Logline -logstring $text -step $step
                    }
                }
            }
        }
    }
    catch {
        $text = "Get-Process method failed: $_"; Logline -logstring $text -step $step
    }

    # Method 2: Use tasklist and taskkill as fallback
    try {
        $text = "Using tasklist/taskkill method for ITM processes"; Logline -logstring $text -step $step

        foreach ($processName in $itmProcessNames) {
            try {
                # Check if process exists using tasklist
                $tasklistOutput = & cmd /C "tasklist /FI `"IMAGENAME eq $processName.exe`" /FO CSV" 2>$null

                if ($tasklistOutput -and $tasklistOutput.Count -gt 1) {
                    $text = "Found running process: $processName.exe"; Logline -logstring $text -step $step

                    # Kill the process using taskkill
                    $killResult = & cmd /C "taskkill /F /IM `"$processName.exe`" /T" 2>$null
                    $text = "taskkill result for ${processName}.exe: $killResult"; Logline -logstring $text -step $step
                    $processesKilled = $true
                }
            }                catch {
                    $text = "Error checking/killing process ${processName}.exe: $_"; Logline -logstring $text -step $step
            }
        }
    }
    catch {
        $text = "tasklist/taskkill method failed: $_"; Logline -logstring $text -step $step
    }

    # Method 3: Use pskill if available
    if (Test-Path "$scriptBin\pskill.exe") {
        try {
            $text = "Using pskill method for remaining ITM processes"; Logline -logstring $text -step $step

            foreach ($processName in $itmProcessNames) {
                try {
                    $pskillResult = & "$scriptBin\pskill.exe" -t $processName -accepteula -nobanner 2>$null
                    if ($pskillResult -and $pskillResult -notmatch "not found") {
                        $text = "pskill result for ${processName}: $pskillResult"; Logline -logstring $text -step $step
                        $processesKilled = $true
                    }
                }
                catch {
                    $text = "pskill failed for ${processName}: $_"; Logline -logstring $text -step $step
                }
            }
        }
        catch {
            $text = "pskill method failed: $_"; Logline -logstring $text -step $step
        }
    }

    # Method 4: Use wmic as final fallback
    try {
        $text = "Using wmic method as final fallback"; Logline -logstring $text -step $step

        foreach ($processName in $itmProcessNames) {
            try {
                $wmicResult = & cmd /C "wmic process where `"name='$processName.exe'`" delete" 2>$null
                if ($wmicResult -and $wmicResult -match "successful") {
                    $text = "wmic successfully terminated $processName.exe"; Logline -logstring $text -step $step
                    $processesKilled = $true
                }
            }                catch {
                    $text = "wmic failed for ${processName}.exe: $_"; Logline -logstring $text -step $step
            }
        }
    }
    catch {
        $text = "wmic method failed: $_"; Logline -logstring $text -step $step
    }

    if ($processesKilled) {
        $text = "ITM processes termination completed - waiting 3 seconds for cleanup"; Logline -logstring $text -step $step
        Start-Sleep -Seconds 3
    } else {
        $text = "No IBM/ITM processes found to terminate"; Logline -logstring $text -step $step
    }

    return $true
}

function Remove-BlockedPath {
    param (
        [string]${path},
        [string]$blockedFilePath = $null,
        [int]$depth = 0
    )

    if ($depth -gt 3) {
        $text = "Maximum retry depth reached for path: ${path}"; Logline -logstring $text -step $step
        return $false
    }

    # Try to delete the path
    try {
        $text = "Attempting to remove: ${path} (depth: $depth)"; Logline -logstring $text -step $step
        Remove-Item -Path ${path} -Recurse -Force
        $text = "Successfully removed: ${path}"; Logline -logstring $text -step $step
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
                return Remove-BlockedPath -path ${path} -blockedFilePath $null -depth ($depth + 1)
            }
        }

        $text = "Failed to remove: ${path} - $_"; Logline -logstring $text -step $step
        return $false
    }
}
function Test-CleanupProductFiles {

    $isAllFilesGone = $true
    $filesNotRemoved = @()

    $text = "cleanup all product files, if uninstall didnt do it"; $step++; Logline -logstring $text -step $step
    foreach (${path} in $global:RemoveDirs) {
        ${path} = [System.Text.RegularExpressions.Regex]::Replace(${path}, "\", "/")
        if (Test-Path ${path}) {
            $text = "Found directory to remove: ${path}"; Logline -logstring $text -step $step

            if (${path} -like "*BigFix*") {
                $text = "Attempting to set permissions for ${path}"; Logline -logstring $text -step $step
                try {
                    $text = "Taking ownership of ${path}"; Logline -logstring $text -step $step
                    $takeownCmd = "takeown /F `"${path}`" /R /A"
                    Invoke-Expression $takeownCmd | Out-Null

                    $text = "Granting full control to Administrators for ${path}"; Logline -logstring $text -step $step
                    $icaclsCmd = "icacls `"${path}`" /grant Administrators:F /T /C /Q"
                    Invoke-Expression $icaclsCmd | Out-Null
                }
                catch {
                    $text = "ERROR: Failed to set permissions for ${path}: $_"; Logline -logstring $text -step $step
                }
            }

            $result = Remove-BlockedPath -path ${path}
            if (-not $result) {
                $isAllFilesGone = $false
                $filesNotRemoved += ${path}
            }
        }
        else {
            $text = "Directory not found (already removed): ${path}"; Logline -logstring $text -step $step
        }

        if ( $isAllFilesGone ) {
            $text = "SUCCESS: all files are gone"; Logline -logstring $text -step $step
        }
        else {
            $text = "WARNING: some files could not be removed"; Logline -logstring $text -step $step
        }
    }
    return $isAllFilesGone
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
                                            $text = "Failed to kill process $processName (PID: $processId) with all methods"; Logline -logstring $text -step $step
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

function Test-AdditionalDirectoriesRemoved {
    $text = "--- CHECKING ADDITIONAL DIRECTORIES FOR REMOVAL ---"; Logline -logstring $text -step $step

    $allDirectoriesRemoved = $true
    $additionalDirs = @(
        "C:/ansible_workdir",
        "C:/ProgramData/BigFix",
        "C:/ProgramData/ansible",
        "C:/ProgramData/ilmt",
        "C:/PROGRA~1/BigFix",
        "C:/PROGRA~1/ansible",
        "C:/PROGRA~1/ilmt"
        # Skipping "C:/Windows/Temp/KMD-AEVEN-TOOLS" as script runs from this location
    )

    foreach ($dir in $additionalDirs) {
        $normalizedPath = $dir -replace "/", "\"
        if (Test-Path $normalizedPath) {
            $allDirectoriesRemoved = $false
            $text = "WARNING: Directory still exists: $normalizedPath"; Logline -logstring $text -step $step

            # Try to remove using handle.exe to kill any locking processes
            $text = "Attempting to remove directory $normalizedPath using handle.exe"; Logline -logstring $text -step $step

            # Check for locking processes using handle.exe
            if (Test-Path "$scriptBin\handle.exe") {
                try {
                    $handleOutput = & "$scriptBin\handle.exe" -nobanner $normalizedPath 2>$null
                    if ($handleOutput) {
                        $text = "Found processes locking $normalizedPath"; Logline -logstring $text -step $step
                        foreach ($line in $handleOutput) {
                            if ($line -match "^\s*(\w+)\s+pid:\s*(\d+)\s+type:\s*(\w+)\s+(.+)$") {
                                $processName = $matches[1]
                                $processId = $matches[2]
                                $text = "  Locking process: $processName (PID: $processId)"; Logline -logstring $text -step $step

                                # Kill the locking process
                                try {
                                    Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
                                    $text = "Killed process $processName (PID: $processId)"; Logline -logstring $text -step $step
                                } catch {
                                    $text = "Failed to kill process $processName (PID: $processId): $_"; Logline -logstring $text -step $step
                                }
                            }
                        }

                        # Wait a moment for processes to fully terminate
                        Start-Sleep -Seconds 2
                    }
                } catch {
                    $text = "Error running handle.exe for $normalizedPath : $_"; Logline -logstring $text -step $step
                }
            }

            # Change file attributes to normal before attempting removal
            try {
                $text = "Changing file attributes to normal for $normalizedPath"; Logline -logstring $text -step $step
                Get-ChildItem -Path $normalizedPath -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
                    try {
                        $_.Attributes = 'Normal'
                    } catch {
                        # Ignore individual file attribute errors
                    }
                }
                Start-Sleep -Seconds 1
            } catch {
                $text = "Warning: Could not change all file attributes in $normalizedPath : $_"; Logline -logstring $text -step $step
            }

            # Now try to remove the directory
            try {
                Remove-Item -Path $normalizedPath -Recurse -Force -ErrorAction Stop
                $text = "SUCCESS: Removed directory $normalizedPath"; Logline -logstring $text -step $step

                # Verify removal
                if (-not (Test-Path $normalizedPath)) {
                    $text = "VERIFIED: Directory $normalizedPath successfully removed"; Logline -logstring $text -step $step
                } else {
                    $text = "WARNING: Directory $normalizedPath still exists after removal attempt"; Logline -logstring $text -step $step
                    $allDirectoriesRemoved = $false
                }
            } catch {
                $text = "ERROR: Failed to remove directory $normalizedPath : $_"; Logline -logstring $text -step $step
                $allDirectoriesRemoved = $false
            }
        } else {
            $text = "SUCCESS: Directory not found (already removed): $normalizedPath"; Logline -logstring $text -step $step
        }
    }
    if ($allDirectoriesRemoved) {
        $text = "SUCCESS: All additional directories have been removed or were not present"; Logline -logstring $text -step $step
    } else {
        $text = "WARNING: Some additional directories could not be removed"; Logline -logstring $text -step $step
    }

    $text = "--- END OF ADDITIONAL DIRECTORIES CHECK ---"; Logline -logstring $text -step $step
}
# ----------------------------------------------------------------------------------------------------------------------------
# Enhanced service management functions for restricted environments
# ----------------------------------------------------------------------------------------------------------------------------

function Get-ServicesWithFallback {
    param([string]$ServicePattern = "", [string]$DisplayNamePattern = "")

    $services = @()

    # Method 1: Try Get-Service if available
    try {
        if (Test-CmdletAvailable "Get-Service") {
            $allServices = Get-Service -ErrorAction SilentlyContinue
            if ($ServicePattern -and $DisplayNamePattern) {
                $services = $allServices | Where-Object {
                    $_.Name -match $ServicePattern -and $_.DisplayName -match $DisplayNamePattern
                }
            } elseif ($ServicePattern) {
                $services = $allServices | Where-Object { $_.Name -match $ServicePattern }
            } elseif ($DisplayNamePattern) {
                $services = $allServices | Where-Object { $_.DisplayName -match $DisplayNamePattern }
            } else {
                $services = $allServices
            }
            return $services
        }
    }
    catch {
        $text = "Get-Service method failed: $_"; Logline -logstring $text -step $step
    }

    # Method 2: Use sc query as fallback
    try {
        $text = "Using 'sc query' fallback method for service enumeration"; Logline -logstring $text -step $step
        $scOutput = & cmd /C "sc query" 2>$null

        if ($scOutput) {
            $serviceLines = $scOutput | Where-Object { $_ -match "SERVICE_NAME: (.+)" }
            foreach ($line in $serviceLines) {
                if ($line -match "SERVICE_NAME: (.+)") {
                    $serviceName = $matches[1].Trim()

                    # Get additional details if patterns are specified
                    if ($ServicePattern -or $DisplayNamePattern) {
                        $serviceDetails = & cmd /C "sc qc `"$serviceName`"" 2>$null
                        $displayName = ""

                        if ($serviceDetails) {
                            $displayNameLine = $serviceDetails | Where-Object { $_ -match "DISPLAY_NAME\s*:\s*(.+)" }
                            if ($displayNameLine -and $displayNameLine -match "DISPLAY_NAME\s*:\s*(.+)") {
                                $displayName = $matches[1].Trim()
                            }
                        }

                        # Apply filters
                        $matchesPattern = $true
                        if ($ServicePattern -and $serviceName -notmatch $ServicePattern) { $matchesPattern = $false }
                        if ($DisplayNamePattern -and $displayName -notmatch $DisplayNamePattern) { $matchesPattern = $false }

                        if ($matchesPattern) {
                            $services += [PSCustomObject]@{
                                Name = $serviceName
                                DisplayName = $displayName
                                Status = "Unknown"
                            }
                        }
                    } else {
                        $services += [PSCustomObject]@{
                            Name = $serviceName
                            DisplayName = "Unknown"
                            Status = "Unknown"
                        }
                    }
                }
            }
        }
    }
    catch {
        $text = "sc query fallback method failed: $_"; Logline -logstring $text -step $step
    }

    return $services
}

function Stop-ServiceWithFallback {
    param([string]$ServiceName)

    $success = $false

    # Method 1: Try Stop-Service if available
    try {
        if (Test-CmdletAvailable "Get-Service" -and Test-CmdletAvailable "Stop-Service") {
            $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            if ($service) {
                $text = "Stopping service $ServiceName using Stop-Service"; Logline -logstring $text -step $step
                $service | Stop-Service -Force -ErrorAction Stop
                $success = $true
                return $success
            }
        }
    }
    catch {
        $text = "Stop-Service method failed for $ServiceName : $_"; Logline -logstring $text -step $step
    }

    # Method 2: Use net stop as fallback
    try {
        $text = "Stopping service $ServiceName using 'net stop'"; Logline -logstring $text -step $step
        $netResult = & cmd /C "net stop `"$ServiceName`"" 2>$null
        if ($netResult -and $netResult -match "successfully|stopped") {
            $text = "net stop successful for $ServiceName"; Logline -logstring $text -step $step
            $success = $true
            return $success
        }
    }
    catch {
        $text = "net stop failed for $ServiceName : $_"; Logline -logstring $text -step $step
    }

    # Method 3: Use sc stop as final fallback
    try {
        $text = "Stopping service $ServiceName using 'sc stop'"; Logline -logstring $text -step $step
        $scResult = & cmd /C "sc stop `"$ServiceName`"" 2>$null
        if ($scResult -and $scResult -match "STOP_PENDING|STOPPED") {
            $text = "sc stop successful for $ServiceName"; Logline -logstring $text -step $step
            $success = $true
        }
    }
    catch {
        $text = "sc stop failed for $ServiceName : $_"; Logline -logstring $text -step $step
    }

    return $success
}

function Stop-ProcessWithFallback {
    param(
        [Parameter(Mandatory=$true)][string]$ProcessName,
        [string]$ProcessId = ""
    )

    $success = $false
    $processName = $ProcessName -replace "\.exe$", ""  # Remove .exe extension if present

    # Method 1: Try Stop-Process if available
    try {
        if (Test-CmdletAvailable "Stop-Process" -and Test-CmdletAvailable "Get-Process") {
            if ($ProcessId) {
                $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
                if ($process) {
                    $text = "Stopping process $($process.Name) (PID: $ProcessId) using Stop-Process"; Logline -logstring $text -step $step
                    Stop-Process -Id $ProcessId -Force -ErrorAction Stop
                    $success = $true
                }
            } else {
                $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
                foreach ($proc in $processes) {
                    $text = "Stopping process $($proc.Name) (PID: $($proc.Id)) using Stop-Process"; Logline -logstring $text -step $step
                    Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                    $success = $true
                }
            }
        }
    }
    catch {
        $text = "Stop-Process method failed for $processName : $_"; Logline -logstring $text -step $step
    }

    # Method 2: Try taskkill as fallback
    if (-not $success) {
        try {
            if ($ProcessId) {
                $text = "Stopping process (PID: $ProcessId) using taskkill"; Logline -logstring $text -step $step
                $killResult = & cmd /C "taskkill /F /PID `"$ProcessId`" /T" 2>$null
            } else {
                $text = "Stopping process $processName using taskkill"; Logline -logstring $text -step $step
                $killResult = & cmd /C "taskkill /F /IM `"$processName.exe`" /T" 2>$null
            }

            if ($? -or ($killResult -and $killResult -match "SUCCESS|TERMINATED")) {
                $text = "taskkill successful for $processName"; Logline -logstring $text -step $step
                $success = $true
            }
        }
        catch {
            $text = "taskkill failed for $processName : $_"; Logline -logstring $text -step $step
        }
    }

    # Method 3: Try pskill if available
    if (-not $success -and (Test-Path "$scriptBin\pskill.exe")) {
        try {
            if ($ProcessId) {
                $text = "Stopping process (PID: $ProcessId) using pskill"; Logline -logstring $text -step $step
                $pskillResult = & "$scriptBin\pskill.exe" -t $ProcessId -accepteula -nobanner 2>$null
            } else {
                $text = "Stopping process $processName using pskill"; Logline -logstring $text -step $step
                $pskillResult = & "$scriptBin\pskill.exe" -t $processName -accepteula -nobanner 2>$null
            }

            if ($pskillResult -and $pskillResult -notmatch "not found|Process not found") {
                $text = "pskill successful for $processName : $pskillResult"; Logline -logstring $text -step $step
                $success = $true
            } else {
                $text = "pskill reported process not found for $processName"; Logline -logstring $text -step $step
            }
        }
        catch {
            $text = "pskill failed for $processName : $_"; Logline -logstring $text -step $step
        }
    }

    # Method 4: Try wmic as final fallback
    if (-not $success) {
        try {
            if ($ProcessId) {
                $text = "Stopping process (PID: $ProcessId) using wmic"; Logline -logstring $text -step $step
                $wmicResult = & cmd /C "wmic process where `"processid='$ProcessId'`" delete" 2>$null
            } else {
                $text = "Stopping process $processName using wmic"; Logline -logstring $text -step $step
                $wmicResult = & cmd /C "wmic process where `"name='$processName.exe'`" delete" 2>$null
            }

            if ($wmicResult -and $wmicResult -match "successful") {
                $text = "wmic successfully terminated $processName"; Logline -logstring $text -step $step
                $success = $true
            }
        }
        catch {
            $text = "wmic failed for $processName : $_"; Logline -logstring $text -step $step
        }
    }

    return $success
}

function Get-ProcessesWithFallback {
    param([string]$ProcessPattern = "")

    $processes = @()

    # Method 1: Try Get-Process if available
    try {
        if (Test-CmdletAvailable "Get-Process") {
            $allProcesses = Get-Process -ErrorAction SilentlyContinue
            if ($ProcessPattern) {
                $processes = $allProcesses | Where-Object { $_.Name -match $ProcessPattern }
            } else {
                $processes = $allProcesses
            }
            return $processes
        }
    }
    catch {
        $text = "Get-Process method failed: $_"; Logline -logstring $text -step $step
    }

    # Method 2: Use tasklist as fallback
    try {
        $text = "Using 'tasklist' fallback method for process enumeration"; Logline -logstring $text -step $step

        if ($ProcessPattern) {
            $tasklistOutput = & cmd /C "tasklist /FI `"IMAGENAME eq $ProcessPattern*`" /FO CSV" 2>$null
        } else {
            $tasklistOutput = & cmd /C "tasklist /FO CSV" 2>$null
        }

        if ($tasklistOutput -and $tasklistOutput.Count -gt 1) {
            # Skip header line and process CSV output
            for ($i = 1; $i -lt $tasklistOutput.Count; $i++) {
                $line = $tasklistOutput[$i]
                if ($line -match '"([^"]+)","([^"]+)"') {
                    $processName = $matches[1].Replace(".exe", "")
                    $processId = $matches[2]

                    $processes += [PSCustomObject]@{
                        Name = $processName
                        Id = $processId
                        Path = "Unknown"
                    }
                }
            }
        }
    }
    catch {
        $text = "tasklist fallback method failed: $_"; Logline -logstring $text -step $step
    }

    return $processes
}

# ----------------------------------------------------------------------------------------------------------------------------
#
# BEGIN
#
# ----------------------------------------------------------------------------------------------------------------------------
# ----------------------------------------------------------------------------------------------------------------------------
# Get full system status before we start
# ----------------------------------------------------------------------------------------------------------------------------
$text = "--- RUNNING COMPREHENSIVE ITM STATUS REPORT BEFORE UNINSTALL ---"; $step++; Logline -logstring $text -step $step
Get-ITMStatusReport

# ----------------------------------------------------------------------------------------------------------------------------
# Get installation logs before we start to have a baseline
# ----------------------------------------------------------------------------------------------------------------------------
$text = "run Get-InstallationLogs (before uninstall)"; $step++; Logline -logstring $text -step $step
Get-InstallationLogs -Phase "pre-uninstall"

# ----------------------------------------------------------------------------------------------------------------------------
# run Start-ProductAgent
# ----------------------------------------------------------------------------------------------------------------------------
if ( $continue ) {
    $text = "run Start-ProductAgent"; $step++; Logline -logstring $text -step $step
    $continue = Start-ProductAgent
}
# ----------------------------------------------------------------------------------------------------------------------------
# run Test-lastUninstall
# ----------------------------------------------------------------------------------------------------------------------------
if ( $continue ) {
    $text = "run Test-lastUninstall"; $step++; Logline -logstring $text -step $step
    $continue = Test-lastUninstall
}
# ----------------------------------------------------------------------------------------------------------------------------
# run Stop-ProductAgent
# ----------------------------------------------------------------------------------------------------------------------------
if ( $continue ) {
    $text = "run Stop-ProductAgent"; $step++; Logline -logstring $text -step $step
    $continue = Stop-ProductAgent
}
# ----------------------------------------------------------------------------------------------------------------------------
# Check for locked files that might prevent uninstall
# ----------------------------------------------------------------------------------------------------------------------------
if ( $continue ) {
    $text = "run Find-LockedFiles"; $step++; Logline -logstring $text -step $step
    Find-LockedFiles
}
# ----------------------------------------------------------------------------------------------------------------------------
# Stop all remaining IBM and ITM-related processes
# ----------------------------------------------------------------------------------------------------------------------------
if ( $continue ) {
    $text = "run Stop-AllITMProcesses"; $step++; Logline -logstring $text -step $step
    $continue = Stop-AllITMProcesses
}
# ----------------------------------------------------------------------------------------------------------------------------
# run Uninstall-ProductAgent
# ----------------------------------------------------------------------------------------------------------------------------
if ( $continue ) {
    $text = "run Uninstall-ProductAgent"; $step++; Logline -logstring $text -step $step
    $continue = Uninstall-ProductAgent
}
# ----------------------------------------------------------------------------------------------------------------------------
# run Test-CleanupRegistry.
# ----------------------------------------------------------------------------------------------------------------------------
if ( $continue ) {
    $text = "run Test-CleanupRegistry"; $step++; Logline -logstring $text -step $step
    $continue = Test-CleanupRegistry
}
# ----------------------------------------------------------------------------------------------------------------------------
# run Test-CleanupProductFiles.
# ----------------------------------------------------------------------------------------------------------------------------
if ( $continue ) {
    $text = "run Test-CleanupProductFiles"; $step++; Logline -logstring $text -step $step
    $continue = Test-CleanupProductFiles
}
# ----------------------------------------------------------------------------------------------------------------------------
# Check logs after uninstall
# ----------------------------------------------------------------------------------------------------------------------------
$text = "run Get-InstallationLogs (after uninstall)"; $step++; Logline -logstring $text -step $step
Get-InstallationLogs -Phase "post-uninstall"
# ----------------------------------------------------------------------------------------------------------------------------
# final test.
# ----------------------------------------------------------------------------------------------------------------------------
# Always run final test regardless of previous step status
$text = "run Test-IsAllGone"; $step++; Logline -logstring $text -step $step
$isAllGone = Test-IsAllGone

# If standard methods didn't work, try force uninstall as a last resort
if (-not $isAllGone) {
    $text = "Standard uninstall methods failed. Attempting force uninstall as last resort"; $step++; Logline -logstring $text -step $step
    Invoke-ForceUninstall

    # Check one more time after force uninstall
    $text = "Checking if ITM components are removed after force uninstall"; Logline -logstring $text -step $step
    $isAllGone = Test-IsAllGone
    if ($isAllGone) {
        $text = "SUCCESS: Force uninstall successfully removed all ITM components"; $step++; Logline -logstring $text -step $step
    } else {
        $text = "WARNING: Some ITM components may still remain on the system"; $step++; Logline -logstring $text -step $step
    }
} else {
    $text = "SUCCESS: Standard uninstall methods successfully removed all ITM components"; $step++; Logline -logstring $text -step $step
}

# Set final continue status based on whether ITM is completely gone
$continue = $isAllGone

# Check for additional directories and remove them if necessary
$text = "Checking and removing additional directories (ansible, BigFix, ilmt, tools)"; $step++; Logline -logstring $text -step $step
Test-AdditionalDirectoriesRemoved

# Perform final registry scan to show any remaining ITM-related entries
$text = "Performing final registry scan for any remaining ITM components"; $step++; Logline -logstring $text -step $step
Show-RemainingRegistryEntries

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
$Difference = '{0:00}:{1:00}:{2:00}' -f $Hrs, $Mins, $Secs
$text = "The End, Elapsed time: ${Difference}"; $step++; Logline -logstring $text -step $step
$text = "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"; Logline -logstring $text -step $step