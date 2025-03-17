"------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
Remove-Variable * -ErrorAction SilentlyContinue
[int]$psvers = $PSVersionTable.PSVersion | select-object -ExpandProperty major
$ReturnArray = @{}
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
# SCCMAgentUninstall.ps1  :   complete uninstall of SCCM, also legacy versions
#
# 2025-03-13  Initial release ( Benny.Skov@kyndryl.dk )
#
#>
# ----------------------------------------------------------------------------------------------------------------------------
#region begining - INIT
# ----------------------------------------------------------------------------------------------------------------------------
$begin = (get-date -format "yyyy-MM-dd HH:mm:ss.fff")
$step = 0
$windir = "$env:WINDIR/Temp"
$scriptName = $myinvocation.mycommand.Name
$scriptpath = $myinvocation.mycommand.Path

$scriptName = [System.Text.RegularExpressions.Regex]::Replace($scriptName, ".ps1", "")
$scriptDir = [System.Text.RegularExpressions.Regex]::Replace($scriptpath, "\\", "/")
$scriptarray = $scriptDir.split("/")
$scriptDir = $scriptarray[0..($scriptarray.Count-2)] -join "/"
"scriptName:       " + $scriptName
"scriptDir:        " + $scriptDir

$project = "de-tooling"
$function = "SCCMAgentUninstall"
${tempDir} = "${scriptDir}/${project}/${function}/"
$logfile = "${scriptDir}/${project}/${function}/${scriptName}.log"
if (-not (Test-Path -Path ${tempDir})) {
    try {
        New-Item -Path ${tempDir} -ItemType Directory -Force | Out-Null
        $icaclsCmd = "icacls `"${tempDir}`" /grant `"Users`":`(OI`)`(CI`)F"
        $result = Invoke-Expression $icaclsCmd
        $text = "Created directory ${tempDir} and set permissions"; Lognewline -logstring $text
    }
    catch {
        $text = "Error creating directory ${tempDir}: $_"; Lognewline -logstring $text
    }
}
$hostname = hostname
$hostname = $hostname.ToLower()
$x64 = (Get-WmiObject -Class Win32_OperatingSystem).OSArchitecture -like '64-bit'
$hostIp = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPENABLED=TRUE | Select-Object IPAddress | select-object -expandproperty IPAddress | select-object -first 1
$ccmsetup = $env:WINDIR + '/ccmsetup/'
$result = Get-WmiObject Win32_Process -Filter "name = 'ccmsetup.exe'" | Select-Object ProcessId, CommandLine | ? { $_.CommandLine -like "*ccmsetup.exe*" } | % { Stop-Process -Id $_.ProcessId -Force -PassThru -ErrorAction Stop -Verbose }
"begin:             " + $begin
"hostname:          " + $hostname
"scriptName:        " + $scriptName
"logfile:           " + $logfile
"scriptDir:         " + $scriptDir
"tempDir:           " + ${tempDir}
"checkSame:         " + $checkSame
"hostIp:            " + $hostIp
"Powershell ver:    " + $psvers
"ccmsetup:          " + $ccmsetup
"windir:            " + $windir
"x64:               " + $x64
"result:            " + $result
"------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
$text = "Set initial parms"; $step++; Logline -logstring $text -step $step
Lognewline -logstring "OK"
Exit(0)
# ----------------------------------------------------------------------------------------------------------------------------
# functions
# ----------------------------------------------------------------------------------------------------------------------------
Function Logline
{
Param ([string]$logstring,$step)
   $now = (get-date -format "yyyy-MM-dd HH:mm:ss.fff")
   $text = ( "{0,-23} : $hostname : step {1:d4} : {2,-75} : {3}" -f $now,$step,$logstring,"" )
   if ( $psvers -gt 4 ) {
       Add-content -NoNewline -LiteralPath $Logfile -value $text
       Write-Host -NoNewline $text
    } else {
       Add-content -LiteralPath $Logfile -value ""
       Add-content -LiteralPath $Logfile -value $text
       Write-Host
       Write-Host $text
    }
}
Function Lognewline
{
Param ([string]$logstring)
   Add-content -LiteralPath $Logfile -value $logstring
   Write-Host $logstring
}
Function finish
{
Param(
    [string]$f_result = "",
    [string]$f_message = ""
)
    if ( $f_message ) { Write-Host f_message  }
    if ( $f_message ) { " : $f_result" }
    if ( $f_result -eq 0 ) { exit 12 }
}

function add-host([string]$filename, [string]$ip, [string]$hostname) {
    # remove-host $filename $ip
    # $ip + "`t`t" + $hostname | Out-File -encoding ASCII -append $filename
}
function remove-host([string]$filename, [string]$hostname) {
    $c = Get-Content $filename
    $newLines = @()
    foreach ($line in $c) {
        if ( $line -notmatch $ip) { $newLines += $line }
    }

    # Write file
    $ErrorActionPreference = 'Stop'
    Clear-Content $filename
    foreach ($line in $newLines) {
        $line | Out-File -encoding ASCII -append $filename
    }
    $ErrorActionPreference = 'Continue'
}

function print_hostfile([string]$filename) {
    $c = Get-Content $filename

    foreach ($line in $c) {
            Write-Host $line
    }
}
#endregion

# $localdir       = [System.Text.RegularExpressions.Regex]::Replace($scriptpath,".$scriptName","")

# $wintemp        = "${tempDir}/KMD-AEVEN-TOOLS/SCCMAgentUninstall/${scriptName}.log"


# remove-item -Path $logfile -Force -ErrorAction SilentlyContinue
# Copy-Item -Path $localdir -Destination "C:\Drawings" -Recurse

# # Function to uninstall SCCM agent
# function Uninstall-SCCMAgent {
#     param(
#         [switch]$Force
#     )

#     $text = "Starting SCCM agent uninstallation process";$step++;Logline -logstring $text -step $step

#     # Stop services first
#     $services = @("CcmExec", "SMS Agent Host", "ccmsetup")
#     foreach ($service in $services) {
#         try {
#             $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
#             if ($svc) {
#                 $text = "Stopping service: $service";Lognewline -logstring $text
#                 Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
#             }
#         } catch {
#             $text = "Error stopping service $service: $_";Lognewline -logstring $text
#         }
#     }

#     # Kill any running processes
#     $processes = @("ccmexec.exe", "ccmsetup.exe", "ccmrepair.exe")
#     foreach ($process in $processes) {
#         try {
#             Get-Process -Name ($process -replace '\.exe$', '') -ErrorAction SilentlyContinue |
#                 Stop-Process -Force -ErrorAction SilentlyContinue
#             $text = "Terminated process if running: $process";Lognewline -logstring $text
#         } catch {
#             $text = "Error stopping process $process: $_";Lognewline -logstring $text
#         }
#     }

#     # Method 1: Use ccmsetup.exe /uninstall
#     if (Test-Path "$env:WinDir\ccmsetup\ccmsetup.exe") {
#         $text = "Uninstalling using ccmsetup.exe";Lognewline -logstring $text
#         $result = Start-Process -FilePath "$env:WinDir\ccmsetup\ccmsetup.exe" -ArgumentList "/uninstall" -Wait -PassThru
#         $text = "ccmsetup /uninstall exit code: $($result.ExitCode)";Lognewline -logstring $text
#     }

#     # Method 2: Use WMIC (for older systems)
#     try {
#         $text = "Attempting uninstall via WMI";Lognewline -logstring $text
#         $result = Invoke-Expression "wmic product where 'name like ""Configuration Manager Client""' call uninstall /nointeractive"
#         $text = "WMI uninstall attempted";Lognewline -logstring $text
#     } catch {
#         $text = "WMI uninstall error: $_";Lognewline -logstring $text
#     }

#     # Method 3: MsiExec for direct uninstall (if other methods fail)
#     try {
#         $clientMsi = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*Configuration Manager Client*" }
#         if ($clientMsi) {
#             $text = "Uninstalling via MSI: $($clientMsi.Name)";Lognewline -logstring $text
#             $result = $clientMsi.Uninstall()
#             $text = "MSI uninstall result: $($result.ReturnValue)";Lognewline -logstring $text
#         }
#     } catch {
#         $text = "MSI uninstall error: $_";Lognewline -logstring $text
#     }

#     # Force removal of client directory if requested
#     if ($Force) {
#         $clientPaths = @(
#             "$env:WinDir\CCM",
#             "$env:WinDir\ccmsetup",
#             "$env:WinDir\ccmcache",
#             "$env:ProgramData\Microsoft\CCMSETUP",
#             "$env:ProgramData\Microsoft\CCM"
#         )

#         foreach ($path in $clientPaths) {
#             if (Test-Path $path) {
#                 try {
#                     $text = "Force removing directory: $path";Lognewline -logstring $text
#                     Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
#                 } catch {
#                     $text = "Error removing $path: $_";Lognewline -logstring $text
#                 }
#             }
#         }

#         # Clean up registry
#         $regKeys = @(
#             "HKLM:\SOFTWARE\Microsoft\CCM",
#             "HKLM:\SOFTWARE\Microsoft\SMS",
#             "HKLM:\SOFTWARE\Microsoft\CCMSetup",
#             "HKLM:\SOFTWARE\Wow6432Node\Microsoft\CCM",
#             "HKLM:\SOFTWARE\Wow6432Node\Microsoft\SMS",
#             "HKLM:\SOFTWARE\Wow6432Node\Microsoft\CCMSetup"
#         )

#         foreach ($key in $regKeys) {
#             if (Test-Path $key) {
#                 try {
#                     $text = "Removing registry key: $key";Lognewline -logstring $text
#                     Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
#                 } catch {
#                     $text = "Error removing registry key $key: $_";Lognewline -logstring $text
#                 }
#             }
#         }

#         # Remove WMI namespaces
#         try {
#             $text = "Removing CCM WMI namespaces";Lognewline -logstring $text
#             Get-WmiObject -Query "SELECT * FROM __Namespace WHERE Name='CCM'" -Namespace "root" -ErrorAction SilentlyContinue |
#                 Remove-WmiObject -ErrorAction SilentlyContinue
#             Get-WmiObject -Query "SELECT * FROM __Namespace WHERE Name='SMSDM'" -Namespace "root\cimv2" -ErrorAction SilentlyContinue |
#                 Remove-WmiObject -ErrorAction SilentlyContinue
#         } catch {
#             $text = "Error removing WMI namespaces: $_";Lognewline -logstring $text
#         }
#     }

#     # Check if uninstallation was successful
#     $success = -not (Test-Path "$env:WinDir\CCM\CcmExec.exe")
#     if ($success) {
#         $text = "SCCM client uninstallation appears successful";Lognewline -logstring $text
#     } else {
#         $text = "SCCM client may still be installed. Consider using -Force parameter";Lognewline -logstring $text
#     }

#     return $success
# }

# # Example usage of the uninstall function can be added to the script:
# # To use: Uninstall-SCCMAgent
# # For forceful removal: Uninstall-SCCMAgent -Force

# #endregion
# # ----------------------------------------------------------------------------------------------------------------------------
# #region add sccm to host file
# # ----------------------------------------------------------------------------------------------------------------------------
# $hostsFile  = "${windir}\system32\Drivers\etc\hosts"
# $null = add-host $hostsFile -ip 84.255.67.200 -hostname "kmdwinccm003.adminkmd.local kmdwinccm003 # SCCM PaaS" -ErrorAction SilentlyContinue
# # $null = add-host $hostsFile -ip 84.255.126.40 -hostname "kmdwinccm004.adminkmd.local kmdwinccm004 # SCCM Classic" -ErrorAction SilentlyContinue
# # $null = add-host $hostsFile -ip 84.255.94.50 -hostname "kmdwinccm005.adminkmd.local kmdwinccm005 # SCCM FMO" -ErrorAction SilentlyContinue
# # print_hostfile $hostsFile
# #endregion
# # ----------------------------------------------------------------------------------------------------------------------------
# #region set parm
# # ----------------------------------------------------------------------------------------------------------------------------
# $text = "Set initial parms";$step++;Logline -logstring $text -step $step
# Lognewline -logstring "OK"
# #endregion
# #
# # kill all old running install hanging
# $result = Get-WmiObject Win32_Process -Filter "name = 'ccmsetup.exe'" | Select-Object ProcessId,CommandLine | ?{$_.CommandLine -like "*ccmsetup.exe*"} | %{Stop-Process -Id $_.ProcessId -Force -PassThru -ErrorAction Stop -Verbose}
# #
# $iparray = @{}
# # Port der skulle være åben er
# # - Port 80 TCP   <->  Distribution Point, Management point
# # - Port 445 TCP   <-> Server Message Block (SMB)
# # - Port 8530 TCP  <-> Software Update Point
# # - Port 10123 TCP  <-> Management Point

# # Test på Port 80 skulle være ok..

# # Classic:
# # 84.255.126.40
# # kmdwinccm004.adminkmd.local

# # PaaS
# # 84.255.67.200
# # kmdwinccm003.adminkmd.local

# # FMO
# # 84.255.94.50
# # kmdwinccm005.adminkmd.local
# # $iparray['84.255.94.503'] = "kmdwinccm005;FMO"
# $iparray['84.255.67.200'] = "kmdwinccm003;PaaS"
# # $iparray['84.255.126.40'] = "kmdwinccm004;Classic"
# $FMO_80 = $false; $Classic_80 = $false; $PaaS_80 = $false
# $FMO_8530 = $false; $Classic_8530 = $false; $PaaS_8530 = $false
# foreach ($key in $iparray.Keys) {
#     $text = "Ping test";$step++;Logline -logstring $text -step $step

#     $value = $($iparray.Item($key))
#     $sccmip = $key
#     # $sccmmgr = $value.split(";")[0]
#     $sccmenv = $value.split(";")[1]

#     $port = 80
#     $ReturnArray = Test-IPPort2 -target $sccmip -port $port
#     $text = $ReturnArray['result']
#     $result80 = [System.Text.RegularExpressions.Regex]::Replace($text,"(`"|`'|`r|`n)","")

#     # FMO --> PaaS --> Classic
#     if ( $sccmenv -imatch "FMO" -and $ReturnArray['rc']  ) { $FMO_80 = $true }
#     if ( $sccmenv -imatch "Classic" -and $ReturnArray['rc']  ) { $Classic_80 = $true }
#     if ( $sccmenv -imatch "PaaS" -and $ReturnArray['rc']  ) { $PaaS_80 = $true }

#     $port = 8530
#     $ReturnArray = Test-IPPort2 -target $sccmip -port $port
#     $text = $ReturnArray['result']
#     $result8530 = [System.Text.RegularExpressions.Regex]::Replace($text,"(`"|`'|`r|`n)","")

#     if ( $sccmenv -imatch "FMO" -and $ReturnArray['rc']  ) { $FMO_8530 = $true }
#     if ( $sccmenv -imatch "Classic" -and $ReturnArray['rc']  ) { $Classic_8530 = $true }
#     if ( $sccmenv -imatch "PaaS" -and $ReturnArray['rc']  ) { $PaaS_8530 = $true }

#     Lognewline -logstring "$sccmenv $result80 $result8530"
# }
# # ----------------------------------------------------------------------------------------------------------------------------
# #region Ping FTP server port for download ITM agent
# # ----------------------------------------------------------------------------------------------------------------------------
# $text = "Ping FTP server port for download ITM agent";$step++;Logline -logstring $text -step $step
# $iparray = @(
# "84.255.92.112"
# )
# $iparray | foreach-object {
#     $ReturnArray = Test-IPPort2 -target $_ -port 21
#     if ( $ReturnArray['rc'] ) {
#         $ftp3portok = $true
#         Lognewline -logstring $ReturnArray['result']
#     } else {
#         Lognewline -logstring $ReturnArray['result']
#     }
# }
# #endregion
# # ----------------------------------------------------------------------------------------------------------------------------
# #region get RTEMS distribution from FTP
# # ----------------------------------------------------------------------------------------------------------------------------
# $zipfile = "SCCM_Client_FMO.zip"
# $agentfile = $localdir+$zipfile
# $zipdir = 'SCCM_Client_FMO'

# if ( $ftp3portok ) {

#     $text = "get install from ftp";$step++;Logline -logstring $text -step $step
#     $remotedir = '/upload2itm/NT-smitools-scripts/'
#     ftp_get -remotedir $remotedir -localdir $localdir -filename "7za.exe"
#     ftp_get -remotedir $remotedir -localdir $localdir -filename "7za.dll"
#     ftp_get -remotedir $remotedir -localdir $localdir -filename "7zxa.dll"
#     ftp_get -remotedir $remotedir -localdir $localdir -filename $zipfile
#     $text = "OK downloaded";Lognewline -logstring $text

# }
# # kill all old running install hanging
# $result = Get-WmiObject Win32_Process -Filter "name = 'ccmsetup.exe'" | Select-Object ProcessId,CommandLine | ?{$_.CommandLine -like "*ccmsetup.exe*"} | %{Stop-Process -Id $_.ProcessId -Force -PassThru -ErrorAction Stop -Verbose}
# #
# If( test-path $agentfile ) {
#     $text = "unzip files";$step++;Logline -logstring $text -step $step

#     if ( $psvers -gt 4 ) {
#         Expand-Archive -LiteralPath $agentfile -DestinationPath $localdir -Force
#     } else {
#         $cmdexec = "$localdir/7za.exe x $agentfile -o$localdir"
#         $result = iex "& $cmdexec"
#         # $result
#     }
#     If(!(test-path $ccmsetup)) {
#         $result = New-Item -ItemType Directory -Force -Path $ccmsetup -ErrorAction SilentlyContinue
#     }
#     Copy-Item -force -Path "$localdir$zipdir/*.*" -Recurse -Destination $ccmsetup
#     Copy-Item -force -Path "$localdir$zipdir/x64/*.*" -Recurse -Destination $ccmsetup
#     $text = "OK unzipped and copied to $ccmsetup";Lognewline -logstring $text
# } else {
#     Lognewline -logstring " "
#     Lognewline -logstring "error, there is either no access to FTP, or zipfile is not in place."
#     Lognewline -logstring "Please log into FTP to get files."
#     Lognewline -logstring "ftp://FTPuser:Mokka11*@84.255.92.112 "
#     Lognewline -logstring "and get: "
#     Lognewline -logstring "/upload2itm/NT-smitools-scripts/SCCM_Client_FMO.zip"
#     Lognewline -logstring "/upload2itm/NT-smitools-scripts/7za.exe"
#     Lognewline -logstring "/upload2itm/NT-smitools-scripts/7za.dll"
#     Lognewline -logstring "/upload2itm/NT-smitools-scripts/7zxa.dll"
#     exit
# }
# # ----------------------------------------------------------------------------------------------------------------------------
# #region install
# # ----------------------------------------------------------------------------------------------------------------------------
# # the sequence is the preferred choice
# # if all have ports open, the FMO is chosen
# #
# $text = "install SCCM (64 bit) ";$step++;Logline -logstring $text -step $step
# # call %Windir%\ccmsetup\ccmsetup.exe /noservice /mp:http://kmdwinccm005.adminkmd.local SMSMP=http://kmdwinccm005.adminkmd.local SMSSITECODE=IA1 SMSSLP=kmdwinccm005.adminkmd.local FSP=kmdwinccm005.adminkmd.local /retry:3 /skipprereq:SCEPInstall.exe /forceinstall
# $oneChosen = $false
# if ( $Classic_80 -and $Classic_8530 ) {
#     $cmdexec = @(
#     "`"$localdir$zipdir\ccmsetup.exe`"",
#     "/noservice",
#     "/mp:http://kmdwinccm004.adminkmd.local",
#     "SMSMP=http://kmdwinccm004.adminkmd.local",
#     "SMSSITECODE=IA1",
#     "SMSSLP=kmdwinccm004.adminkmd.local",
#     "FSP=kmdwinccm004.adminkmd.local",
#     "/retry:3",
#     "/skipprereq:SCEPInstall.exe",
#     "/forceinstall"
#     )
#     $oneChosen = $true
#     $netenvir = "Classic"
# }
# if ( $PaaS_80 -and $PaaS_8530 ) {
#     $cmdexec = @(
#     "`"$localdir$zipdir\ccmsetup.exe`"",
#     "/noservice",
#     "/mp:http://kmdwinccm003.adminkmd.local",
#     "SMSMP=http://kmdwinccm003.adminkmd.local",
#     "SMSSITECODE=IA1",
#     "SMSSLP=kmdwinccm003.adminkmd.local",
#     "FSP=kmdwinccm003.adminkmd.local",
#     "/retry:3",
#     "/skipprereq:SCEPInstall.exe",
#     "/forceinstall"
#     )
#     $oneChosen = $true
#     $netenvir = "PaaS"
# }
# if ( $FMO_80 -and $FMO_8530 ) {
#     $cmdexec = @(
#     "`"$localdir$zipdir\ccmsetup.exe`"",
#     "/noservice",
#     "/mp:http://kmdwinccm005.adminkmd.local",
#     "SMSMP=http://kmdwinccm005.adminkmd.local",
#     "SMSSITECODE=IA1",
#     "SMSSLP=kmdwinccm005.adminkmd.local",
#     "FSP=kmdwinccm005.adminkmd.local",
#     "/retry:3",
#     "/skipprereq:SCEPInstall.exe",
#     "/forceinstall"
#     )
#     $oneChosen = $true
#     $netenvir = "FMO"
# }
# if ( -not $oneChosen ) {
#     Lognewline -logstring " ERROR No ports was available for install."
#     exit
# }
# $result = & cmd /C $cmdexec 2>&1
# if ([string]::IsNullOrEmpty($result)) {
#     $text = "OK Install started for $netenvir. $result"
# } else {
#     $text = "error - $result"
# }
# Lognewline -logstring $text
# # ----------------------------------------------------------------------------------------------------------------------------
# #region Wait for install completed
# # ----------------------------------------------------------------------------------------------------------------------------
# $text = "Wait for install completed";$step++;Logline -logstring $text -step $step
# $count = 1
# do {
#     $procMsiExec = Get-Process -Name msiexec -ErrorAction SilentlyContinue
#     $procCCMSetup = Get-Process -Name ccmsetup -ErrorAction SilentlyContinue
#     # get-process | where-object { $_.ProcessName -imatch '(msiexec|ccmexec|ccmsetup)' }
#     Write-Host -NoNewline '.'
#     Start-Sleep 10
#     $count = $count + 10
#     if ( $count -ge 300 ) { break }
# } until ( ( $count -ge 300 ) -or ($procMsiExec -eq $null) -and ($procCCMSetup -eq $null))
# Lognewline -logstring " OK install completed"
# #endregion
# # ----------------------------------------------------------------------------------------------------------------------------
# #region cleanup
# # ----------------------------------------------------------------------------------------------------------------------------
# # Remove-Item -Recurse -Path "$localdir$zipdir" -ErrorAction SilentlyContinue
# # Remove-Item -Recurse -Path "$agentfile" -ErrorAction SilentlyContinue
# # Remove-Item -Recurse -Path "${localdir}7za.exe" -ErrorAction SilentlyContinue
# # Remove-Item -Recurse -Path "${localdir}7za.dll" -ErrorAction SilentlyContinue
# # Remove-Item -Recurse -Path "${localdir}7zxa.dll" -ErrorAction SilentlyContinue
# # Remove-Item -Recurse -Path "${localdir}procexp.exe" -ErrorAction SilentlyContinue
# #endregion
# # ----------------------------------------------------------------------------------------------------------------------------
# # The End
# # ----------------------------------------------------------------------------------------------------------------------------
# $end = (get-date -format "yyyy-MM-dd HH:mm:ss.fff")
# $TimeDiff = New-TimeSpan $begin $end
# if ($TimeDiff.Seconds -lt 0) {
# 	$Hrs = ($TimeDiff.Hours) + 23
# 	$Mins = ($TimeDiff.Minutes) + 59
# 	$Secs = ($TimeDiff.Seconds) + 59
# } else {
# 	$Hrs = $TimeDiff.Hours
# 	$Mins = $TimeDiff.Minutes
# 	$Secs = $TimeDiff.Seconds
# }
# $text = 'The End, Elapsed time';$step++;Logline -logstring $text -step $step
# $Difference = '{0:00}:{1:00}:{2:00}' -f $Hrs,$Mins,$Secs
# $Difference
# "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
# exit 0