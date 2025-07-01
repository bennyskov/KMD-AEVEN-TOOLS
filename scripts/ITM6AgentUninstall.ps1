$defaultErrorActionPreference = 'SilentlyContinue'
$global:ErrorActionPreference = $defaultErrorActionPreference
$global:VerbosePreference = "SilentlyContinue"
$PSModuleAutoLoadingPreference = "None"
$global:PSModuleAutoLoadingPreference = "None"

# Try to import essential modules if they're not available
try {
    # Test if Get-Service is available, if not try to import the module
    if (-not (Get-Command "Get-Service" -ErrorAction SilentlyContinue)) {
        Import-Module Microsoft.PowerShell.Management -ErrorAction SilentlyContinue
    }
    # Test if Get-WmiObject is available, if not try to import the module
    if (-not (Get-Command "Get-WmiObject" -ErrorAction SilentlyContinue)) {
        Import-Module Microsoft.PowerShell.Management -ErrorAction SilentlyContinue
    }
} catch {
    # Continue if module import fails - the script will use fallback methods
}

# Define Test-CmdletAvailable early since it's used in initialization
function Test-CmdletAvailable {
    param([string]$CmdletName)
    try {
        $cmd = Get-Command $CmdletName -ErrorAction SilentlyContinue
        return ($null -ne $cmd)
    }
    catch {
        return $false
    }
}

$global:scriptName = $myinvocation.mycommand.Name
<# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
#   V1.4
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
# For this script is to do a complete uninstall of ${DisplayName} agent and all legacy versions, if any on a given server.
# Also check and uninstall if any legacy versions. But do not uninstall if an OpenText version exists on server.
#
# Steps performed:
# • Get-ITMStatusReport - Collects comprehensive information about ITM installation before uninstallation
# • Get-InstallationLogs - Gathers installation logs before and after uninstall, filtering irrelevant messages and only checking the most recent log file
# • Start-ProductAgent - Starts any monitoring agents found, setting them to Automatic start
# • Test-lastUninstall - Check for any hanging uninstall processes from previous runs
# • Stop-ProductAgent - Stops all monitoring agent services using multiple methods if needed
# • Find-LockedFiles - Identifies any locked files that might prevent removal
# • Stop-AllITMProcesses - Forcefully terminates any remaining ITM-related processes
# • Uninstall-ProductAgent - Runs the uninstallation process using various methods (uninstaller, MSI, WMIC)
# • Reset-FileAttributes - Recursively resets read-only, hidden, and system attributes on files to facilitate removal
# • Test-CleanupRegistry - Removes any leftover registry entries
# • Test-CleanupProductFiles - Cleans up any remaining product files
# • Test-IsAllGone - Final verification that all components are removed
# • Invoke-ForceUninstall - Emergency cleanup for stubborn installations (if needed)
# • Test-AdditionalDirectoriesRemoved - Removes related directories with aggressive permission resets (ansible, BigFix, ilmt)
# • Show-RemainingRegistryEntries - Final scan for any leftover registry entries
#
# 2025-03-13  Initial release ( Benny.Skov@kyndryl.dk )
#
#>
# ----------------------------------------------------------------------------------------------------------------------------
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
# Logline
# ----------------------------------------------------------------------------------------------------------------------------
Function Logline {
    Param ([string]$logstring, $step)
    $now = (get-date -format "yyyy-MM-dd HH:mm:ss.fff")
    $text = ( "{0,-23} : $hostname : step {1:d4} : {2}" -f $now, $step, $logstring)

    # Try to write to log file with error handling
    try {
        Add-content -LiteralPath $global:logfile -value $text -Force -ErrorAction Stop
    }
    catch {
        # If file is locked or inaccessible, continue without logging to file
        # This prevents the script from failing due to logging issues
    }

    # Add color output to help with visibility
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
}

# ----------------------------------------------------------------------------------------------------------------------------
# Test-LogMessageRelevance - Determine if a log message is relevant to ITM uninstallation
# ----------------------------------------------------------------------------------------------------------------------------
function Test-LogMessageRelevance {
    param (
        [string]$Message
    )

    # Skip if message is empty or too short
    if ([string]::IsNullOrWhiteSpace($Message) -or $Message.Length -lt 10) {
        return $false
    }

    # List of terms that indicate a message is relevant to ITM
    $relevantTerms = @(
        'IBM', 'Tivoli', 'ITM', 'monitoring agent', 'candle',
        'TEMA', 'itmcmd', 'kincinfo', 'kbbsspc', 'KCIIN',
        'install manager', 'agent', 'uninstall'
    )

    # Check if message contains any relevant terms (case-insensitive)
    $containsRelevantTerm = ($relevantTerms | Where-Object { $Message -match [regex]::Escape($_) }).Count -gt 0

    # List of exclusion terms that indicate a message should be ignored
    $exclusionTerms = @(
        'OFFICECL', 'click-to-run', 'appmodel', 'telemetry',
        'Microsoft Office', 'Visual Studio', 'Windows Feature',
        'chocolatey', 'appx', 'Microsoft Edge', 'OneDrive'
    )

    # Check if message contains any exclusion terms (case-insensitive)
    $containsExclusionTerm = ($exclusionTerms | Where-Object { $Message -match [regex]::Escape($_) }).Count -gt 0

    # Message is relevant if it contains a relevant term and doesn't contain any exclusion terms
    return $containsRelevantTerm -and -not $containsExclusionTerm
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
    "C:/PROGRA~1/ilmt"
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
function Get-ITMStatusReport {
    $text = "Collecting comprehensive ITM status report"; $step++; Logline -logstring $text -step $step

    # Verify ITM installation paths
    $text = "--- ITM INSTALLATION PATHS ---"; Logline -logstring $text -step $step
    $itmPaths = @(
        "C:\IBM\ITM"
    )

    foreach (${path} in $itmPaths) {
        if (Test-Path ${path}) {
            $text = "Found ITM installation at: ${path}"; Logline -logstring $text -step $step
            $files = Get-ChildItem -Path ${path} -Recurse -ErrorAction SilentlyContinue | Measure-Object
            $text = "Path contains $($files.Count) files/folders"; Logline -logstring $text -step $step

            # Get exe files for more details
            $exeFiles = Get-ChildItem -Path ${path} -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 5
            if ($exeFiles -and $exeFiles.Count -gt 0) {
                $text = "Key executable files found:"; Logline -logstring $text -step $step
                $exeFiles | ForEach-Object { Logline -logstring "- $($_.FullName)" -step $step }
            }
        }
        else {
            $text = "ITM installation not found at: ${path}"; Logline -logstring $text -step $step
        }
    }

    # Check Services
    $text = "--- ITM SERVICES ---"; Logline -logstring $text -step $step
    $itmServices = Get-ServiceSafe | Where-Object {
        ($_.Name -match "^k" -and ($_.DisplayName -match "monitoring Agent" -or $_.DisplayName -like "*ITM*")) -or
        (($_.Name -like "*IBM*" -or $_.Name -like "*Tivoli*") -and ($_.DisplayName -match "monitoring Agent" -or $_.DisplayName -like "*ITM*" -or $_.DisplayName -like "*Candle*"))
    }

    if ($itmServices -and $itmServices.Count -gt 0) {
        $text = "Found $($itmServices.Count) ITM related services"; Logline -logstring $text -step $step
        $itmServices | Select-Object Name, DisplayName, Status, StartType | Format-Table -AutoSize |
        Out-String -Width 300 | ForEach-Object { Logline -logstring $_ -step $step }
    }
    else {
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
    foreach ($regPath in $regPaths) {
        if (Test-Path $regPath) {
            $foundRegistryEntries = $true
            $text = "Found ITM registry entries at: $regPath"; Logline -logstring $text -step $step
            try {
                $regKeys = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue
                if ($regKeys -and $regKeys.Count -gt 0) {
                    $text = "Registry path contains $($regKeys.Count) keys/values"; Logline -logstring $text -step $step
                }
            }
            catch {
                $text = "Error reading registry path: $_"; Logline -logstring $text -step $step
            }
        }
    }

    if (-not $foundRegistryEntries) {
        $text = "No ITM registry entries found"; Logline -logstring $text -step $step
    }

    # Check installed software
    $text = "--- ITM INSTALLED SOFTWARE ---"; Logline -logstring $text -step $step
    try {
        if (Test-CmdletAvailable "Get-WmiObject") {
            $itmProducts = Get-WmiObject -Class Win32_Product -ErrorAction SilentlyContinue | Where-Object {
                (($_.Name -like "*IBM*" -or $_.Vendor -like "*IBM*") -and ($_.Name -like "*Tivoli*" -or $_.Name -like "*ITM*" -or $_.Name -like "*Monitoring*" -or $_.Name -like "*Candle*")) -and
                -not (Test-ShouldExcludeFromITMUninstall -DisplayName $_.Name -Publisher $_.Vendor)
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

    if ($itmProducts -and $itmProducts.Count -gt 0) {
        $text = "Found $($itmProducts.Count) IBM/ITM related software packages"; Logline -logstring $text -step $step
        foreach ($product in $itmProducts) {
            $text = "Product: $($product.Name), Version: $($product.Version), Vendor: $($product.Vendor), GUID: $($product.IdentifyingNumber)";
            Logline -logstring $text -step $step

            # Get uninstall string
            try {
                $uninstall = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -eq $product.Name }
                if (-not $uninstall) {
                    $uninstall = Get-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
                    Where-Object { $_.DisplayName -eq $product.Name }
                }

                if ($uninstall) {
                    $text = "Uninstall string: $($uninstall.UninstallString)"; Logline -logstring $text -step $step
                }
            }
            catch {
                $text = "Error getting uninstall string: $_"; Logline -logstring $text -step $step
            }
        }
    }
    else {
        $text = "No IBM/ITM related software found in Windows installer database"; Logline -logstring $text -step $step
    }

    # Check for ITM processes
    $text = "--- ITM RUNNING PROCESSES ---"; Logline -logstring $text -step $step
    $itmProcesses = Get-Process | Where-Object {
        ($_.Name -match "^k" -and ($_.Path -like "*IBM\ITM*" -or $_.Company -like "*IBM*")) -or
        (($_.Company -like "*IBM*" -or $_.Name -like "*ITM*") -and $_.Path -like "*IBM\ITM*")
    }

    if ($itmProcesses -and $itmProcesses.Count -gt 0) {
        $text = "Found $($itmProcesses.Count) ITM related processes"; Logline -logstring $text -step $step
        $itmProcesses | Select-Object Id, Name, Path | Format-Table -AutoSize |
        Out-String -Width 300 | ForEach-Object { Logline -logstring $_ -step $step }
    }
    else {
        $text = "No ITM processes currently running"; Logline -logstring $text -step $step
    }

    $text = "----- END OF ITM STATUS REPORT -----"; Logline -logstring $text -step $step
}
function Test-lastUninstall {
    try {
        # ${UninstName} = ''
        $continue = $true
        if ( [bool]$(Get-WmiObject Win32_Process -ErrorAction SilentlyContinue | Where-Object Name -imatch "${UninstName}")) {
            $text = "stop ${UninstName} if UninstPath is still running from last run."; $step++; Logline -logstring $text -step $step
            $result = $(Get-WmiObject Win32_Process -ErrorAction SilentlyContinue | Where-Object Name -imatch "${UninstName}") | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -PassThru }
            Logline -logstring $result -step $step
        }
        if ( [bool]$(Get-WmiObject Win32_Process -ErrorAction SilentlyContinue | Where-Object Name -imatch "${UninstName}")) {
            $text = "${UninstName} is still running. We try stopping it using psKill"; Logline -logstring $text -step $step
            $cmdexec = "${scriptBin}/psKill -t $UninstName -accepteula -nobanner"
            Logline -logstring $cmdexec -step $step
            $result = & cmd /C $cmdexec
            Logline -logstring $result -step $step

            if ( [bool]$(Get-WmiObject Win32_Process -ErrorAction SilentlyContinue | Where-Object Name -imatch "${UninstName}")) {
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
        $services = Get-ServiceSafe | Where-Object { $_.Name -match "${ServiceName}" -and $_.DisplayName -match "${DisplayName}" }

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
                $service | Stop-Service
                $text = "Setting startup type to Automatic for $($service.Name)..."; Logline -logstring $text -step $step
                $service | Set-Service -StartupType Automatic
                $text = "Starting service $($service.Name)..."; Logline -logstring $text -step $step
                $service | Start-Service
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
    $text = "Agents started status: $IsAgentsStarted"; Logline -logstring $text -step $step    $text = "Final services status:"; Logline -logstring $text -step $step
    Show-AgentStatus

    $runningServices = Get-ServiceSafe | Where-Object { $_.Name -match "${ServiceName}" -and $_.DisplayName -match "${DisplayName}" -and $_.Status -eq "Running" }

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
            $servicesToStop = Get-ServiceSafe | Where-Object { $_.Name -match "${ServiceName}" -and $_.DisplayName -match "${DisplayName}" }

            if ($servicesToStop -and $servicesToStop.Count -gt 0) {
                $text = "Found $($servicesToStop.Count) monitoring agent services to stop"; Logline -logstring $text -step $step
                $servicesToStop | Select-Object Name, DisplayName, Status | Format-Table -AutoSize | Out-String -Width 300 | ForEach-Object { Logline -logstring $_ -step $step }
            }
            else {
                $text = "No monitoring agent services found to stop"; Logline -logstring $text -step $step
            }

            foreach ($service in $servicesToStop) {
                try {
                    if ( $disable ) {
                        if (Test-CmdletAvailable "Set-Service") {
                            Set-Service -Name $service.Name -StartupType Disabled -ErrorAction SilentlyContinue
                        } else {
                            & sc.exe config $service.Name start= disabled
                        }
                    }
                    if (Test-CmdletAvailable "Stop-Service") {
                        Stop-Service -Name $service.Name -Force -ErrorAction SilentlyContinue
                    } else {
                        & net.exe stop $service.Name
                    }
                } catch {
                    $text = "Error stopping service $($service.Name): $($_.Exception.Message)"; Logline -logstring $text -step $step
                }
            }
            if ( Test-IsAgentsStopped -eq $true ) { $IsAgentsStopped = $true }
        }

        if ( -not $IsAgentsStopped ) {
            $text = "stop Method 2: Stop ${DisplayName} using WMI Terminate"; $step++; Logline -logstring $text -step $step
            $ReturnValue = $(Get-WmiObject Win32_Process -ErrorAction SilentlyContinue | Where-Object CommandLine -match "${CommandLine}" | ForEach-Object { $_.Terminate() }).ReturnValue
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
            $servicesToStop = $(Get-ServiceSafe | Where-Object { $_.Name -match "${ServiceName}" -and $_.DisplayName -match "${DisplayName}" }).Name
            foreach ($service in $servicesToStop) {
                $cmdexec = "net stop $service"
                $result = & cmd /C $cmdexec
                Logline -logstring "$result"
            }
            if ( Test-IsAgentsStopped -eq $true ) { $IsAgentsStopped = $true }
        }

        if ( -not $IsAgentsStopped ) {
            $text = "stop Method 4: Stop ${DisplayName} using 'psKill service'"; $step++; Logline -logstring $text -step $step
            $servicesToKill = Get-ServiceSafe | Where-Object { $_.Name -match "${ServiceName}" -and $_.DisplayName -match "${DisplayName}" }
            foreach ($service in $servicesToKill) {
                $text = "${service} is still running. We try stopping it using psKill"; Logline -logstring $result -step $step
                $cmdexec = "${scriptBin}/psKill -t $service -accepteula -nobanner"
                Logline -logstring $cmdexec -step $step
                $result = & cmd /C $cmdexec
                Logline -logstring $result -step $step
            }
            if ( Test-IsAgentsStopped -eq $true ) { $IsAgentsStopped = $true }
        }

        if ( -not $IsAgentsStopped ) {
            $text = "stop and disable services"; $step++; Logline -logstring $text -step $step
            $servicesToStop = Get-ServiceSafe | Where-Object { $_.Name -match "${ServiceName}" -and $_.DisplayName -match "${DisplayName}" }
            foreach ($service in $servicesToStop) {
                try {
                    if ( $disable ) {
                        if (Test-CmdletAvailable "Set-Service") {
                            Set-Service -Name $service.Name -StartupType Disabled -ErrorAction SilentlyContinue
                        } else {
                            & sc.exe config $service.Name start= disabled
                        }
                    }
                    if (Test-CmdletAvailable "Stop-Service") {
                        Stop-Service -Name $service.Name -Force -ErrorAction SilentlyContinue
                    } else {
                        & net.exe stop $service.Name
                    }
                } catch {
                    $text = "Error stopping service $($service.Name): $($_.Exception.Message)"; Logline -logstring $text -step $step
                }
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

    if ( Test-IsAgentsStopped -eq $true ) {
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
        }
    }

    if ( Test-IsAllGone -eq $false ) {
        $text = "uninstall via MsiExec for direct uninstall (if other methods fail)"; $step++; Logline -logstring $text -step $step
        try {
            $clientMsi = Get-WmiObject -Class Win32_Product -ErrorAction SilentlyContinue | Where-Object { $_.Description -like "*${DisplayName}*" }
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

    if ( Test-IsAllGone -eq $false ) {
        $text = "Attempting to find and uninstall by product GUID"; $step++; Logline -logstring $text -step $step
        try {
            # Find any IBM ITM related products
            # Find product GUIDs where the line contains ALL: IBM, Tivoli, and ITM (in any order)
            $guidCmd = "wmic product get name,identifyingnumber | findstr /I 'IBM' | findstr /I 'Tivoli' | findstr /I 'ITM'"
            $guidResults = Invoke-Expression $guidCmd
            Logline -logstring "Found product GUIDs: $guidResults" -step $step

            # Extract GUIDs using regex, only if $guidResults is not null or empty
            if (![string]::IsNullOrWhiteSpace($guidResults)) {
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
            else {
                $text = "No product GUIDs found for direct uninstall (wmic output empty)"; Logline -logstring $text -step $step
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
                    ) -and -not (Test-ShouldExcludeFromITMUninstall -DisplayName $props.DisplayName -Publisher $props.Publisher)
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

    return $isAllRegistryGone
}

function Stop-AllITMProcesses {
    $text = "Forcefully terminating all IBM/ITM related processes"; $step++; Logline -logstring $text -step $step

    # Stop any processes related to IBM or ITM
    $processesToStop = Get-Process | Where-Object {
        ($_.Name -match "^k" -and ($_.Path -like "*IBM\ITM*" -or $_.Company -like "*IBM*")) -or
        (($_.Company -like "*IBM*" -or $_.Name -like "*ITM*") -and $_.Path -like "*IBM\ITM*")
    }

    if ($processesToStop -and $processesToStop.Count -gt 0) {
        $text = "Found $($processesToStop.Count) processes to terminate"; Logline -logstring $text -step $step
        $processesToStop | Select-Object Id, Name, Path | Format-Table -AutoSize | Out-String -Width 300 | ForEach-Object { Logline -logstring $_ -step $step }

        foreach ($process in $processesToStop) {
            try {
                $text = "Stopping process $($process.Name) (PID: $($process.Id))"; Logline -logstring $text -step $step
                $process | Stop-Process -Force -ErrorAction SilentlyContinue
            }
            catch {
                $text = "Failed to stop process $($process.Name) : $_"; Logline -logstring $text -step $step
                try {
                    # Try with pskill as fallback
                    $cmdexec = "${binDir}/pskill -t $processId -accepteula -nobanner"
                    $text = "Attempting fallback pskill: $cmdexec"; Logline -logstring $text -step $step
                    $result = & cmd /C $cmdexec
                    Logline -logstring "$result" -step $step
                }
                catch {
                    $text = "pskill also failed: $_"; Logline -logstring $text -step $step
                }
            }
        }

        return $true
    }
    else {
        $text = "No IBM/ITM processes found to terminate"; Logline -logstring $text -step $step
        return $true
    }
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

    # First try recursive deletion from deepest subdirectories
    if (Test-Path ${path} -PathType Container) {
        $text = "Attempting recursive deletion from deepest subdirectories: ${path} (depth: $depth)"; Logline -logstring $text -step $step

        try {
            # Get all subdirectories sorted by depth (deepest first)
            $subDirectories = Get-ChildItem -Path ${path} -Directory -Recurse -ErrorAction SilentlyContinue |
                Sort-Object @{Expression={($_.FullName -split '\\').Count}; Descending=$true}

            # Delete subdirectories from deepest to shallowest
            foreach ($subDir in $subDirectories) {
                if (Test-Path $subDir.FullName) {
                    $text = "Removing subdirectory: $($subDir.FullName)"; Logline -logstring $text -step $step
                    try {
                        # Reset attributes first
                        Reset-FileAttributes -path $subDir.FullName
                        Remove-Item -Path $subDir.FullName -Recurse -Force -ErrorAction Stop
                        $text = "Successfully removed subdirectory: $($subDir.FullName)"; Logline -logstring $text -step $step
                    }
                    catch {
                        $text = "WARNING: Denied to remove subdirectory $($subDir.FullName): $_, tryieng a lower directory"; Logline -logstring $text -step $step
                        # Try handle on this specific subdirectory
                        $result = Invoke-HandleOnPath -targetPath $subDir.FullName
                        if ($result) {
                            try {
                                Remove-Item -Path $subDir.FullName -Recurse -Force -ErrorAction Stop
                                $text = "Successfully removed subdirectory after handle cleanup: $($subDir.FullName)"; Logline -logstring $text -step $step
                            }
                            catch {
                                $text = "Still failed to remove subdirectory after handle cleanup: $($subDir.FullName) - $_"; Logline -logstring $text -step $step
                            }
                        }
                    }
                }
            }
        }
        catch {
            $text = "Error during recursive subdirectory cleanup: $_"; Logline -logstring $text -step $step
        }
    }

    # Try to delete the main path
    try {
        $text = "Attempting to remove main path: ${path} (depth: $depth)"; Logline -logstring $text -step $step
        Remove-Item -Path ${path} -Recurse -Force
        $text = "Successfully removed: ${path}"; Logline -logstring $text -step $step
        return $true
    }
    catch {
        $errorMsg = $_.ToString()
        $text = "Failed to remove: ${path} - $errorMsg"; Logline -logstring $text -step $step

        # Extract blocked file/directory path from error message
        $deniedPathMatch = [regex]::Match($errorMsg, "Access to the path '([^']+)' is denied")
        $cannotAccessMatch = [regex]::Match($errorMsg, "Cannot remove item (.*?): The process cannot access the file")

        $targetPath = $null
        if ($deniedPathMatch.Success) {
            $targetPath = $deniedPathMatch.Groups[1].Value
            $text = "Extracted denied path: $targetPath"; Logline -logstring $text -step $step
        }
        elseif ($cannotAccessMatch.Success) {
            $targetPath = $cannotAccessMatch.Groups[1].Value.Trim()
            $text = "Extracted blocked file path: $targetPath"; Logline -logstring $text -step $step
        }
        elseif ($blockedFilePath) {
            $targetPath = $blockedFilePath
        }
        else {
            # If we can't extract the specific path, use the main path
            $targetPath = ${path}
        }

        # Run handle on the specific problematic path
        if ($targetPath) {
            $text = "Running handle.exe on problematic path: $targetPath"; Logline -logstring $text -step $step
            $handleResult = Invoke-HandleOnPath -targetPath $targetPath

            if ($handleResult) {
                # Wait for processes to terminate
                Start-Sleep -Seconds 2

                # Try deletion again after handle cleanup
                try {
                    $text = "Retrying deletion after handle cleanup: ${path}"; Logline -logstring $text -step $step
                    Remove-Item -Path ${path} -Recurse -Force
                    $text = "Successfully removed after handle cleanup: ${path}"; Logline -logstring $text -step $step
                    return $true
                }
                catch {
                    $text = "Still failed after handle cleanup: ${path} - $_"; Logline -logstring $text -step $step

                    # Try recursive call with increased depth
                    if ($depth -lt 3) {
                        $text = "Attempting recursive retry with depth $($depth + 1)"; Logline -logstring $text -step $step
                        Start-Sleep -Seconds 1
                        return Remove-BlockedPath -path ${path} -blockedFilePath $targetPath -depth ($depth + 1)
                    }
                }
            }
        }

        return $false
    }
}

# Helper function to run handle.exe on a specific path and kill locking processes
function Invoke-HandleOnPath {
    param(
        [string]$targetPath
    )

    try {
        $handleCmd = "${scriptBin}/handle.exe `"$targetPath`" -accepteula -nobanner"
        $text = "Executing: $handleCmd"; Logline -logstring $text -step $step
        $handleResult = & cmd /C $handleCmd
        $text = "Handle result for $targetPath : $handleResult"; Logline -logstring $text -step $step

        # Parse handle output and kill locking processes
        $handleLines = $handleResult -split "`n"
        $processesKilled = $false

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

                # Try to kill the process
                try {
                    $text = "Attempting to kill locking process: $processName (PID: $processId)"; Logline -logstring $text -step $step
                    Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
                    $text = "Successfully killed process: $processName (PID: $processId)"; Logline -logstring $text -step $step
                    $processesKilled = $true
                }
                catch {
                    $text = "Failed to kill process $processName (PID: $processId): $_"; Logline -logstring $text -step $step

                    # Try with pskill as backup
                    try {
                        $pskillCmd = "${scriptBin}/pskill.exe -t $processId -accepteula -nobanner"
                        $text = "Attempting pskill: $pskillCmd"; Logline -logstring $text -step $step
                        $pskillResult = & cmd /C $pskillCmd
                        $text = "Pskill result: $pskillResult"; Logline -logstring $text -step $step
                    }
                    catch {
                        $text = "Pskill also failed: $_"; Logline -logstring $text -step $step
                    }
                }
            }
        }

        return $processesKilled
    }
    catch {
        $text = "Error running handle.exe on $targetPath : $_"; Logline -logstring $text -step $step
        return $false
    }
}

# ----------------------------------------------------------------------------------------------------------------------------
# Reset-FileAttributes - Recursively clears read-only, hidden and system attributes on files/folders
# ----------------------------------------------------------------------------------------------------------------------------
function Reset-FileAttributes {
    param(
        [string]$path
    )

    try {
        # Check if path exists
        if (-not (Test-Path -Path $path)) {
            return $false
        }

        # Reset attributes on the directory itself
        $folder = Get-Item -Path $path -Force -ErrorAction SilentlyContinue
        if ($folder -and ($folder.Attributes -band [System.IO.FileAttributes]::ReadOnly -or
                           $folder.Attributes -band [System.IO.FileAttributes]::Hidden -or
                           $folder.Attributes -band [System.IO.FileAttributes]::System)) {
            $folder.Attributes = $folder.Attributes -band -bnot ([System.IO.FileAttributes]::ReadOnly -bor
                                                                 [System.IO.FileAttributes]::Hidden -bor
                                                                 [System.IO.FileAttributes]::System)
        }

        # Reset attributes on all child files
        Get-ChildItem -Path $path -File -Force -Recurse -ErrorAction SilentlyContinue |
        ForEach-Object {
            if ($_.Attributes -band [System.IO.FileAttributes]::ReadOnly -or
                $_.Attributes -band [System.IO.FileAttributes]::Hidden -or
                $_.Attributes -band [System.IO.FileAttributes]::System) {
                $_.Attributes = $_.Attributes -band -bnot ([System.IO.FileAttributes]::ReadOnly -bor
                                                          [System.IO.FileAttributes]::Hidden -bor
                                                          [System.IO.FileAttributes]::System)
            }
        }

        # Reset attributes on all child directories
        Get-ChildItem -Path $path -Directory -Force -Recurse -ErrorAction SilentlyContinue |
        ForEach-Object {
            if ($_.Attributes -band [System.IO.FileAttributes]::ReadOnly -or
                $_.Attributes -band [System.IO.FileAttributes]::Hidden -or
                $_.Attributes -band [System.IO.FileAttributes]::System) {
                $_.Attributes = $_.Attributes -band -bnot ([System.IO.FileAttributes]::ReadOnly -bor
                                                          [System.IO.FileAttributes]::Hidden -bor
                                                          [System.IO.FileAttributes]::System)
            }
        }

        return $true
    }
    catch {
        $text = "Error resetting file attributes on $path : $_"; Logline -logstring $text -step $step
        return $false
    }
}

function Test-CleanupProductFiles {

    $isAllFilesGone = $true
    $filesNotRemoved = @()

    $text = "cleanup all product files, if uninstall didnt do it"; $step++; Logline -logstring $text -step $step
    foreach (${path} in $global:RemoveDirs) {
        ${path} = [System.Text.RegularExpressions.Regex]::Replace(${path}, "\\", "/")
        if (Test-Path ${path}) {
            # First reset file attributes to enable deletion
            $text = "Resetting file attributes to prepare for deletion: ${path}"; Logline -logstring $text -step $step
            Reset-FileAttributes -path ${path}

            # Sleep briefly to allow filesystem to update
            Start-Sleep -Milliseconds 500

            $text = "Attempting to remove directory: ${path}"; Logline -logstring $text -step $step
            $result = Remove-BlockedPath -path ${path}

            # If first attempt fails, try one more time after a brief pause
            if (-not $result) {
                $text = "First removal attempt failed, retrying after pause: ${path}"; Logline -logstring $text -step $step
                Start-Sleep -Seconds 2
                $result = Remove-BlockedPath -path ${path}

                if (-not $result) {
                    $filesNotRemoved += ${path}
                    $isAllFilesGone = $false
                }
            }
        }
        else {
            $text = "Path does not exist: ${path}"; Logline -logstring $text -step $step
        }

        if ( $isAllFilesGone ) {
            $result = "success. All Agents files are removed"
            Logline -logstring $result -step $step
        }
        else {
            if ( $filesNotRemoved.Count -gt 0 ) {
                $text = "filesNotRemoved=" + $filesNotRemoved.Count; Logline -logstring $text -step $step
                foreach (${path} in $filesNotRemoved) {
                    Logline -logstring $line -step $step
                }
            }
        }
    }
    return $isAllFilesGone
}
function Show-AgentStatus {
    $services = $(Get-ServiceSafe | Where-Object { $_.Name -imatch "${ServiceName}" -and $_.DisplayName -imatch "${DisplayName}" })

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

    $serviceExists = $(Get-ServiceSafe | Where-Object { $_.Name -match "${ServiceName}" -and $_.DisplayName -match "${DisplayName}" }).Name
    $processExists = $(Get-Process | Where-Object { $_.ProcessName -match "${ServiceName}" -and $_.Description -match "${DisplayName}" }).ProcessName
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
    $serviceExists = [bool]$(Get-ServiceSafe | Where-Object { $_.Name -match "${ServiceName}" -and $_.DisplayName -match "${DisplayName}" })
    $processExists = [bool]$(Get-Process | Where-Object { $_.ProcessName -match "${ServiceName}" -and $_.Description -match "${DisplayName}" })

    # Also check for remaining ITM entries in Programs and Features
    $programsAndFeaturesEntries = @()
    $programsAndFeaturesEntries += Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
    Where-Object { (($_.DisplayName -like "*IBM*" -and ($_.DisplayName -like "*Tivoli*" -or $_.DisplayName -like "*ITM*" -or $_.DisplayName -like "*monitoring*")) -or
                              ($_.Publisher -like "*IBM*" -and ($_.DisplayName -like "*Tivoli*" -or $_.DisplayName -like "*ITM*" -or $_.DisplayName -like "*monitoring*"))) -and
                             -not (Test-ShouldExcludeFromITMUninstall -DisplayName $_.DisplayName -Publisher $_.Publisher) }
    $programsAndFeaturesEntries += Get-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
    Where-Object { (($_.DisplayName -like "*IBM*" -and ($_.DisplayName -like "*Tivoli*" -or $_.DisplayName -like "*ITM*" -or $_.DisplayName -like "*monitoring*")) -or
                              ($_.Publisher -like "*IBM*" -and ($_.DisplayName -like "*Tivoli*" -or $_.DisplayName -like "*ITM*" -or $_.DisplayName -like "*monitoring*"))) -and
                             -not (Test-ShouldExcludeFromITMUninstall -DisplayName $_.DisplayName -Publisher $_.Publisher) }

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
        Where-Object { (($_.DisplayName -like "*IBM*" -and ($_.DisplayName -like "*Tivoli*" -or $_.DisplayName -like "*ITM*" -or $_.DisplayName -like "*monitoring*")) -or
                                  ($_.Publisher -like "*IBM*" -and ($_.DisplayName -like "*Tivoli*" -or $_.DisplayName -like "*ITM*" -or $_.DisplayName -like "*monitoring*"))) -and
                                 -not (Test-ShouldExcludeFromITMUninstall -DisplayName $_.DisplayName -Publisher $_.Publisher) }
        $products += Get-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
        Where-Object { (($_.DisplayName -like "*IBM*" -and ($_.DisplayName -like "*Tivoli*" -or $_.DisplayName -like "*ITM*" -or $_.DisplayName -like "*monitoring*")) -or
                                  ($_.Publisher -like "*IBM*" -and ($_.DisplayName -like "*Tivoli*" -or $_.DisplayName -like "*ITM*" -or $_.DisplayName -like "*monitoring*"))) -and
                                 -not (Test-ShouldExcludeFromITMUninstall -DisplayName $_.DisplayName -Publisher $_.Publisher) }

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
        $servicesToRemove = Get-ServiceSafe | Where-Object {
            ($_.Name -match "^k" -and ($_.DisplayName -match "monitoring Agent" -or $_.DisplayName -like "*ITM*")) -or
            (($_.Name -like "*IBM*" -or $_.Name -like "*Tivoli*") -and ($_.DisplayName -match "monitoring Agent" -or $_.DisplayName -like "*ITM*" -or $_.DisplayName -like "*Candle*"))
        }

        if ($servicesToRemove -and $servicesToRemove.Count -gt 0) {
            foreach ($svc in $servicesToRemove) {
                $text = "Removing service: $($svc.Name)"; Logline -logstring $text -step $step

                # First, kill processes associated with service
                try {
                    $svc | Stop-Service -Force -ErrorAction SilentlyContinue
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

    foreach (${path} in $itmPaths) {
        if (Test-Path ${path}) {
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

                                # Try to kill the process
                                try {
                                    $text = "Attempting to kill locking process: $processName (PID: $processId)"; Logline -logstring $text -step $step
                                    Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
                                    $text = "Successfully killed process: $processName (PID: $processId)"; Logline -logstring $text -step $step
                                }
                                catch {
                                    $text = "Failed to kill process $processName (PID: $processId): $_"; Logline -logstring $text -step $step

                                    # Try with pskill as backup
                                    try {
                                        $pskillCmd = "${scriptBin}/pskill.exe -t $processId -accepteula -nobanner"
                                        $text = "Attempting pskill: $pskillCmd"; Logline -logstring $text -step $step
                                        $pskillResult = & cmd /C $pskillCmd
                                        $text = "Pskill result: $pskillResult"; Logline -logstring $text -step $step
                                    }
                                    catch {
                                        $text = "Pskill also failed: $_"; Logline -logstring $text -step $step
                                    }
                                }
                            }
                        }

                        # Wait a moment for processes to fully terminate
                        Start-Sleep -Seconds 3

                        # Try to remove the directory again after killing locking processes
                        $text = "Attempting directory removal after killing locking processes"; Logline -logstring $text -step $step
                        Remove-Item -Path $subDir.FullName -Recurse -Force -ErrorAction SilentlyContinue

                        # If still locked, try robocopy method
                        if (Test-Path $subDir.FullName) {
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
        # "HKLM:\SOFTWARE\Wow6432Node\IBM\Tivoli" # do not remove from registry, might be another product than ITM6
        # "HKLM:\SOFTWARE\IBM\Tivoli" # do not remove from registry, might be another product than ITM6

        $stubborn_registry_keys = @(
            "HKLM:\SOFTWARE\Candle",
            "HKLM:\SOFTWARE\Wow6432Node\Candle",
            "HKLM:\SYSTEM\CurrentControlSet\Services\Candle",
            "HKLM:\SOFTWARE\IBM\ITM",
            "HKLM:\SOFTWARE\Wow6432Node\IBM\ITM"
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
                    }
                    else {
                        $text = "reg.exe delete result: $deleteResult"; Logline -logstring $text -step $step

                        # Fallback to PowerShell method
                        $text = "Fallback: Using PowerShell Remove-Item for $regKey"; Logline -logstring $text -step $step
                        try {
                            Remove-Item -Path $regKey -Recurse -Force
                            $text = "Successfully force removed registry key: $regKey"; Logline -logstring $text -step $step
                        }
                        catch {
                            $text = "Error force removing registry key $regKey : $_"; Logline -logstring $text -step $step
                        }
                    }
                }
                catch {
                    $text = "Error force removing registry key $regKey : $_"; Logline -logstring $text -step $step
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
            }
            else {
                $text = "SUCCESSFULLY REMOVED: $regKey"; Logline -logstring $text -step $step
            }
        }

        if ($remainingKeys -eq 0) {
            $text = "SUCCESS: All targeted ITM registry keys have been removed"; Logline -logstring $text -step $step
        }
        else {
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
                        }
                        else {
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

                                        $text = "Killing locking process: $processName (PID: $processId)"; Logline -logstring $text -step $step
                                        try {
                                            Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
                                        }
                                        catch {
                                            try {
                                                $pskillCmd = "${scriptBin}/pskill.exe -t $processId -accepteula -nobanner"
                                                & cmd /C $pskillCmd
                                            }
                                            catch {
                                                $text = "Failed to kill process $processId"; Logline -logstring $text -step $step
                                            }
                                        }
                                    }
                                }

                                # Wait for processes to terminate
                                Start-Sleep -Seconds 3

                                # Try to remove the subdirectory again
                                Remove-Item -Path $subDir.FullName -Recurse -Force -ErrorAction SilentlyContinue

                                if (-not (Test-Path $subDir.FullName)) {
                                    $text = "Successfully removed subdirectory after killing locking processes: $($subDir.FullName)"; Logline -logstring $text -step $step
                                }
                                else {
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
                    }
                    else {
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
                                    try {
                                        Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
                                        $text = "Successfully killed process: $processName (PID: $processId)"; Logline -logstring $text -step $step
                                    }
                                    catch {
                                        try {
                                            $pskillCmd = "${scriptBin}/pskill.exe -t $processId -accepteula -nobanner"
                                            $pskillResult = & cmd /C $pskillCmd
                                            $text = "Pskill result for PID $processId : $pskillResult"; Logline -logstring $text -step $step
                                        }
                                        catch {
                                            $text = "Failed to kill process $processId with pskill: $_"; Logline -logstring $text -step $step
                                        }
                                    }
                                }
                            }

                            # Wait for processes to terminate
                            Start-Sleep -Seconds 3

                            # Try to remove the directory again
                            Remove-Item -Path $itmRootPath -Recurse -Force -ErrorAction SilentlyContinue

                            if (-not (Test-Path $itmRootPath)) {
                                $text = "Successfully removed ITM root directory after killing locking processes"; Logline -logstring $text -step $step
                            }
                            else {
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
                # Get the most recent log file only
                $mostRecentLog = $itmLogs | Sort-Object LastWriteTime -Descending | Select-Object -First 1

                $text = "Found $($itmLogs.Count) potential ITM logs, will check only the most recent one: $($mostRecentLog.FullName) (Last modified: $($mostRecentLog.LastWriteTime))"; Logline -logstring $text -step $step

                # For text log files, try to extract error messages (only during post-uninstall phase)
                if ($mostRecentLog.Extension -in ".log", ".txt" -and $Phase -eq "post-uninstall") {
                    # Skip scanning our own active log file to avoid recursive errors
                    if ($mostRecentLog.FullName -eq $global:logfile) {
                        $text = "Skipping scan of active log file: $($mostRecentLog.FullName)"; Logline -logstring $text -step $step
                        continue
                    }

                    try {
                        $text = "Scanning log for errors: $($mostRecentLog.FullName)"; Logline -logstring $text -step $step

                        # Read file with better error handling
                        $logContent = @()
                        try {
                            $logContent = Get-Content -Path $mostRecentLog.FullName -ErrorAction Stop
                        }
                        catch {
                            $text = "Cannot read log file (may be locked): $($mostRecentLog.FullName)"; Logline -logstring $text -step $step
                            continue
                        }

                        # Only process if we got valid line content
                        if ($logContent -and $logContent.Count -gt 0) {
                            # First pass filter - find lines with error indicators
                            $errorLines = $logContent | Where-Object {
                                $_ -and $_.Length -gt 10 -and $_ -match "error|fail|except|warning"
                            }

                            # Second pass filter - use central function to determine relevance
                            $filteredErrorLines = $errorLines | Where-Object {
                                Test-LogMessageRelevance -Message $_
                            }

                            if ($filteredErrorLines -and $filteredErrorLines.Count -gt 0) {
                                $text = "Found $($filteredErrorLines.Count) relevant error lines in log"; Logline -logstring $text -step $step
                                # Show only last 5 errors to avoid log spam
                                $lastErrors = if ($filteredErrorLines.Count -gt 5) { $filteredErrorLines[-5..-1] } else { $filteredErrorLines }
                                foreach ($line in $lastErrors) {
                                    if ($line -and $line.Trim().Length -gt 0) {
                                        Logline -logstring "LOG ERROR: $($line.Trim())" -step $step
                                    }
                                }
                            }
                            elseif ($errorLines -and $errorLines.Count -gt 0) {
                                $text = "Found $($errorLines.Count) error lines in log, but none were relevant to ITM"; Logline -logstring $text -step $step
                            }
                        }
                    }
                    catch {
                        $text = "Error reading log file $($mostRecentLog.FullName): $_"; Logline -logstring $text -step $step
                    }
                }
                elseif ($mostRecentLog.Extension -in ".log", ".txt" -and $Phase -eq "pre-uninstall") {
                    $text = "Skipping error scan during pre-uninstall phase to avoid false positives from previous runs"; Logline -logstring $text -step $step
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
                # Filter events using the same relevance function
                $relevantEvents = $msiEvents | Where-Object { Test-LogMessageRelevance -Message $_.Message }

                if ($relevantEvents -and $relevantEvents.Count -gt 0) {
                    $text = "Found $($relevantEvents.Count) relevant MSI installer events related to ITM"; Logline -logstring $text -step $step
                    foreach ($relEvent in $relevantEvents) {
                        $text = "Event ID $($relEvent.Id) (Level: $($relEvent.LevelDisplayName)) at $($relEvent.TimeCreated): $($relEvent.Message)"; Logline -logstring $text -step $step
                    }
                }
                else {
                    $text = "Found $($msiEvents.Count) MSI installer events, but none were relevant to ITM"; Logline -logstring $text -step $step
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

    # Check for any other IBM/ITM related registry entries using broader search
    $text = "Performing broader registry search for IBM/ITM references"; Logline -logstring $text -step $step

    $broadSearchPaths = @(
        "HKLM:\SOFTWARE\IBM",
        "HKLM:\SOFTWARE\Wow6432Node\IBM",
        "HKLM:\SYSTEM\CurrentControlSet\Services"
    )

    foreach ($searchPath in $broadSearchPaths) {
        if (Test-Path $searchPath) {
            try {
                if ($searchPath -like "*Services*") {
                    # For services, look for ITM/Candle specific services
                    $itmServices = Get-ChildItem -Path $searchPath -ErrorAction SilentlyContinue |
                    Where-Object {
                        $_.Name -match "(candle|itm|tivoli|\\IBM\\ITM\\)" -and
                        $_.Name -notmatch "(TSM|Spectrum)"
                    }

                    if ($itmServices -and $itmServices.Count -gt 0) {
                        $foundRegistryEntries = $true
                        $text = "WARNING: Found $($itmServices.Count) ITM-related service registry entries"; Logline -logstring $text -step $step
                        foreach ($service in $itmServices) {
                            $text = "  - Service: $($service.PSChildName)"; Logline -logstring $text -step $step
                        }
                    }
                }
                else {
                    # For IBM paths, look for ITM/Tivoli specific entries
                    $itmEntries = Get-ChildItem -Path $searchPath -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -match "(itm|tivoli|candle|monitoring)" }

                    if ($itmEntries -and $itmEntries.Count -gt 0) {
                        $foundRegistryEntries = $true
                        $text = "WARNING: Found $($itmEntries.Count) ITM-related entries under $searchPath"; Logline -logstring $text -step $step
                        foreach ($entry in $itmEntries) {
                            $text = "  - $($entry.PSChildName)"; Logline -logstring $text -step $step
                        }
                    }
                }
            }
            catch {
                $text = "Error searching $searchPath : $_"; Logline -logstring $text -step $step
            }
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

            # Reset file attributes before attempting to remove
            $text = "Resetting file attributes to prepare for deletion: $normalizedPath"; Logline -logstring $text -step $step
            Reset-FileAttributes -path $normalizedPath

            # Wait briefly for file system to update
            Start-Sleep -Milliseconds 500

            # Use the improved Remove-BlockedPath function
            $text = "Attempting to remove directory using improved Remove-BlockedPath: $normalizedPath"; Logline -logstring $text -step $step
            $removeResult = Remove-BlockedPath -path $normalizedPath

            if ($removeResult) {
                $text = "SUCCESS: Directory removed using Remove-BlockedPath: $normalizedPath"; Logline -logstring $text -step $step
            }
            else {
                $text = "FAILED: Could not remove directory even with Remove-BlockedPath: $normalizedPath"; Logline -logstring $text -step $step

                # Try one more time with takeown and icacls for extremely stubborn directories
                $text = "Attempting final aggressive permissions reset for $normalizedPath"; Logline -logstring $text -step $step

                try {
                    # Take ownership and set full permissions
                    $takeownCmd = "takeown /f `"$normalizedPath`" /r /d y"
                    $icaclsCmd = "icacls `"$normalizedPath`" /grant administrators:F /t /q"
                    $icaclsResetCmd = "icacls `"$normalizedPath\*`" /reset /T /Q"

                    $text = "Running: $takeownCmd"; Logline -logstring $text -step $step
                    & cmd /C $takeownCmd 2>&1 | Out-Null

                    $text = "Running: $icaclsCmd"; Logline -logstring $text -step $step
                    & cmd /C $icaclsCmd 2>&1 | Out-Null

                    $text = "Running: $icaclsResetCmd"; Logline -logstring $text -step $step
                    & cmd /C $icaclsResetCmd 2>&1 | Out-Null

                    # Wait for permissions to take effect
                    Start-Sleep -Seconds 2

                    # Try Remove-BlockedPath again after permissions reset
                    $text = "Retry Remove-BlockedPath after permissions reset: $normalizedPath"; Logline -logstring $text -step $step
                    $retryResult = Remove-BlockedPath -path $normalizedPath

                    if ($retryResult) {
                        $text = "SUCCESS: Directory removed after permissions reset: $normalizedPath"; Logline -logstring $text -step $step
                    }
                    else {
                        $text = "FINAL FAILURE: Cannot remove directory even after all attempts: $normalizedPath"; Logline -logstring $text -step $step
                        $allDirectoriesRemoved = $false
                    }
                }
                catch {
                    $text = "ERROR during final permission reset attempt for $normalizedPath : $_"; Logline -logstring $text -step $step
                    $allDirectoriesRemoved = $false
                }
            }
        }
        else {
            $text = "SUCCESS: Directory not found (already removed): $normalizedPath"; Logline -logstring $text -step $step
        }
    }

    if ($allDirectoriesRemoved) {
        $text = "SUCCESS: All additional directories have been removed or were not present"; Logline -logstring $text -step $step
    }
    else {
        $text = "WARNING: Some additional directories could not be removed"; Logline -logstring $text -step $step
    }

    $text = "--- END OF ADDITIONAL DIRECTORIES CHECK ---"; Logline -logstring $text -step $step
}
# ----------------------------------------------------------------------------------------------------------------------------
# Helper function to safely check cmdlet availability without triggering auto-imports
# ----------------------------------------------------------------------------------------------------------------------------
# Safe Get-Service wrapper function
# ----------------------------------------------------------------------------------------------------------------------------
function Get-ServiceSafe {
    param(
        [string]$Name = "*",
        [string]$DisplayName = "*"
    )

    # First try to use Get-Service if available
    if (Test-CmdletAvailable "Get-Service") {
        try {
            if ($Name -ne "*" -or $DisplayName -ne "*") {
                return Get-Service | Where-Object {
                    ($_.Name -like $Name) -and ($_.DisplayName -like $DisplayName)
                }
            } else {
                return Get-Service
            }
        }
        catch {
            # Fall through to WMI method
        }
    }

    # Fallback to WMI if Get-Service is not available
    try {
        if (Test-CmdletAvailable "Get-WmiObject") {
            $services = Get-WmiObject -Class Win32_Service -ErrorAction SilentlyContinue
            if ($services) {
                $serviceObjects = @()
                foreach ($service in $services) {
                    if (($service.Name -like $Name) -and ($service.DisplayName -like $DisplayName)) {
                        $serviceObj = New-Object PSObject -Property @{
                            Name = $service.Name
                            DisplayName = $service.DisplayName
                            Status = switch ($service.State) {
                                "Running" { "Running" }
                                "Stopped" { "Stopped" }
                                "Paused" { "Paused" }
                                default { $service.State }
                            }
                            StartType = switch ($service.StartMode) {
                                "Auto" { "Automatic" }
                                "Manual" { "Manual" }
                                "Disabled" { "Disabled" }
                                default { $service.StartMode }
                            }
                        }
                        $serviceObjects += $serviceObj
                    }
                }
                return $serviceObjects
            }
        }
    }
    catch {
        # Final fallback to SC command
        try {
            & sc.exe query state=all > $null 2>&1
            if ($LASTEXITCODE -eq 0) {
                # Parse SC output - this is a basic implementation
                # For the scope of this fix, we'll return empty array if both methods fail
                return @()
            }
        }
        catch {
            return @()
        }
    }

    return @()
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
    $text = "run Stop-ProductAgent"; Logline -logstring $text -step $step
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
    }
    else {
        $text = "WARNING: Some ITM components may still remain on the system"; $step++; Logline -logstring $text -step $step
    }
}
else {
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
# ----------------------------------------------------------------------------------------------------------------------------
# Test-ShouldExcludeFromITMUninstall - Determine if IBM software should be excluded from ITM uninstallation
# ----------------------------------------------------------------------------------------------------------------------------
function Test-ShouldExcludeFromITMUninstall {
    param (
        [string]$DisplayName,
        [string]$Publisher = ""
    )

    # Return false if DisplayName is null or empty
    if ([string]::IsNullOrWhiteSpace($DisplayName)) {
        return $false
    }

    # List of IBM software that should NOT be uninstalled during ITM cleanup
    $excludedSoftware = @(
        # TSM/Spectrum Protect Client - backup software that should remain
        'TSM', 'Tivoli Storage Manager', 'Spectrum Protect', 'Storage Manager',

        # OpenText versions of former IBM products - should remain
        'OpenText',

        # Other IBM software that should not be removed during ITM cleanup
        'WebSphere', 'DB2', 'Lotus', 'Notes', 'Domino', 'SPSS', 'Rational',
        'FileNet', 'Cognos', 'InfoSphere', 'DataStage', 'QRadar', 'AppScan',
        'BigInsights', 'PureData', 'Sterling', 'MQ', 'Message Queue',
        'Cloud Pak', 'Red Hat', 'Power Systems', 'AIX', 'i2', 'TRIRIGA',
        'Maximo', 'Planning Analytics', 'Watson', 'DOORS', 'Rhapsody'
    )

    # Check if the DisplayName contains any excluded software names (case-insensitive)
    foreach ($excludedItem in $excludedSoftware) {
        if ($DisplayName -like "*$excludedItem*") {
            $text = "EXCLUDING from ITM uninstall: '$DisplayName' (matches exclusion pattern: '$excludedItem')";
            Logline -logstring $text -step $step
            return $true
        }
    }

    # Additional check for publisher to catch edge cases
    if (-not [string]::IsNullOrWhiteSpace($Publisher)) {
        foreach ($excludedItem in $excludedSoftware) {
            if ($Publisher -like "*$excludedItem*") {
                $text = "EXCLUDING from ITM uninstall: '$DisplayName' (publisher '$Publisher' matches exclusion pattern: '$excludedItem')";
                Logline -logstring $text -step $step
                return $true
            }
        }
    }

    return $false
}

# ----------------------------------------------------------------------------------------------------------------------------
# Get-MSIProductInfo - Get MSI product information from a product code (GUID)
# ----------------------------------------------------------------------------------------------------------------------------
function Get-MSIProductInfo {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ProductCode
    )

    # Ensure the product code is properly formatted with braces
    if (-not $ProductCode.StartsWith("{")) {
        $ProductCode = "{$ProductCode}"
    }
    if (-not $ProductCode.EndsWith("}")) {
        $ProductCode = "$ProductCode}"
    }

    try {
        # Try to get product information using WMI first
        if (Test-CmdletAvailable "Get-WmiObject") {
            $msiProduct = Get-WmiObject -Class Win32_Product -Filter "IdentifyingNumber='$ProductCode'" -ErrorAction SilentlyContinue

            if ($msiProduct) {
                return [PSCustomObject]@{
                    DisplayName = $msiProduct.Name
                    Publisher = $msiProduct.Vendor
                    Version = $msiProduct.Version
                    InstallDate = $msiProduct.InstallDate
                    InstallLocation = $msiProduct.InstallLocation
                    ProductCode = $ProductCode
                    UninstallString = "msiexec.exe /x $ProductCode /qn"
                }
            }
        }

        # Fallback: Try to get information from registry
        $registryPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$ProductCode",
            "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$ProductCode"
        )

        foreach ($regPath in $registryPaths) {
            if (Test-Path $regPath) {
                $regInfo = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
                if ($regInfo) {
                    return [PSCustomObject]@{
                        DisplayName = $regInfo.DisplayName
                        Publisher = $regInfo.Publisher
                        Version = $regInfo.DisplayVersion
                        InstallDate = $regInfo.InstallDate
                        InstallLocation = $regInfo.InstallLocation
                        ProductCode = $ProductCode
                        UninstallString = $regInfo.UninstallString
                    }
                }
            }
        }

        # If we get here, the product wasn't found
        $text = "MSI Product not found for GUID: $ProductCode"; Logline -logstring $text -step $step
        return $null
    }
    catch {
        $text = "Error getting MSI product info for $ProductCode : $_"; Logline -logstring $text -step $step
        return $null
    }
}

# ----------------------------------------------------------------------------------------------------------------------------
# Show-IBMSoftwareAnalysis - Show analysis of IBM software and what would be included/excluded from cleanup
# ----------------------------------------------------------------------------------------------------------------------------
function Show-IBMSoftwareAnalysis {
    $text = "--- IBM SOFTWARE ANALYSIS FOR ITM CLEANUP ---"; $step++; Logline -logstring $text -step $step

    try {
        # Check Programs and Features for IBM software
        $uninstallPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        )

        $allIBMSoftware = @()
        foreach ($uninstallPath in $uninstallPaths) {
            if (Test-Path $uninstallPath) {
                $ibmEntries = Get-ChildItem -Path $uninstallPath -ErrorAction SilentlyContinue |
                Where-Object {
                    $props = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
                    $props -and (
                        ($props.DisplayName -like "*IBM*") -or
                        ($props.Publisher -like "*IBM*")
                    )
                }

                foreach ($entry in $ibmEntries) {
                    $props = Get-ItemProperty -Path $entry.PSPath -ErrorAction SilentlyContinue
                    if ($props) {
                        $allIBMSoftware += [PSCustomObject]@{
                            DisplayName = $props.DisplayName
                            Publisher = $props.Publisher
                            Version = $props.DisplayVersion
                            RegistryPath = $entry.PSPath
                        }
                    }
                }
            }
        }

        if ($allIBMSoftware.Count -gt 0) {
            $text = "Found $($allIBMSoftware.Count) total IBM software entries"; Logline -logstring $text -step $step

            # Analyze what would be included in ITM cleanup
            $includedSoftware = @()
            $excludedSoftware = @()

            foreach ($software in $allIBMSoftware) {
                $isITMRelated = ($software.DisplayName -like "*Tivoli*" -or
                               $software.DisplayName -like "*ITM*" -or
                               $software.DisplayName -like "*monitoring*") -or
                               ($software.Publisher -like "*IBM*" -and
                               ($software.DisplayName -like "*Tivoli*" -or
                                $software.DisplayName -like "*ITM*" -or
                                $software.DisplayName -like "*monitoring*"))

                $shouldExclude = Test-ShouldExcludeFromITMUninstall -DisplayName $software.DisplayName -Publisher $software.Publisher

                if ($isITMRelated -and -not $shouldExclude) {
                    $includedSoftware += $software
                }
                elseif ($shouldExclude) {
                    $excludedSoftware += $software
                }
            }

            $text = "SOFTWARE THAT WOULD BE INCLUDED IN ITM CLEANUP ($($includedSoftware.Count) items):"; Logline -logstring $text -step $step
            if ($includedSoftware.Count -gt 0) {
                foreach ($software in $includedSoftware) {
                    $text = "  INCLUDE: $($software.DisplayName) - Publisher: $($software.Publisher) - Version: $($software.Version)";
                    Logline -logstring $text -step $step
                }
            }
            else {
                $text = "  No IBM/ITM software found that would be included in cleanup"; Logline -logstring $text -step $step
            }

            $text = "SOFTWARE THAT WOULD BE EXCLUDED FROM ITM CLEANUP ($($excludedSoftware.Count) items):"; Logline -logstring $text -step $step
            if ($excludedSoftware.Count -gt 0) {
                foreach ($software in $excludedSoftware) {
                    $text = "  EXCLUDE: $($software.DisplayName) - Publisher: $($software.Publisher) - Version: $($software.Version)";
                    Logline -logstring $text -step $step
                }
            }
            else {
                $text = "  No IBM software found that would be excluded"; Logline -logstring $text -step $step
            }

            # Show other IBM software that doesn't match ITM patterns
            $otherIBMSoftware = $allIBMSoftware | Where-Object {
                $software = $_
                $isITMRelated = ($software.DisplayName -like "*Tivoli*" -or
                               $software.DisplayName -like "*ITM*" -or
                               $software.DisplayName -like "*monitoring*") -or
                               ($software.Publisher -like "*IBM*" -and
                               ($software.DisplayName -like "*Tivoli*" -or
                                $software.DisplayName -like "*ITM*" -or
                                $software.DisplayName -like "*monitoring*"))

                $shouldExclude = Test-ShouldExcludeFromITMUninstall -DisplayName $software.DisplayName -Publisher $software.Publisher

                return -not $isITMRelated -and -not $shouldExclude
            }

            $text = "OTHER IBM SOFTWARE NOT RELATED TO ITM ($($otherIBMSoftware.Count) items):"; Logline -logstring $text -step $step
            if ($otherIBMSoftware.Count -gt 0) {
                foreach ($software in $otherIBMSoftware) {
                    $text = "  OTHER: $($software.DisplayName) - Publisher: $($software.Publisher) - Version: $($software.Version)";
                    Logline -logstring $text -step $step
                }
            }
            else {
                $text = "  No other IBM software found"; Logline -logstring $text -step $step
            }
        }
        else {
            $text = "No IBM software found in Programs and Features"; Logline -logstring $text -step $step
        }
    }
    catch {
        $text = "Error during IBM software analysis: $_"; Logline -logstring $text -step $step
    }

    $text = "--- END OF IBM SOFTWARE ANALYSIS ---"; Logline -logstring $text -step $step
}