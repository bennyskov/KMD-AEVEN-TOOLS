# $defaultErrorActionPreference = 'Continue'
$defaultErrorActionPreference = 'SilentlyContinue'
$global:ErrorActionPreference = $defaultErrorActionPreference
$global:scriptName = $myinvocation.mycommand.Name

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
. "$PSScriptRoot\AgentUninstall_init.ps1" # load settings for an agent uninstall
# ----------------------------------------------------------------------------------------------------------------------------
#
# settings for ITM6 agent uninstall
#
# ----------------------------------------------------------------------------------------------------------------------------
$global:UninstName          = 'ITMRmvAll.exe'
$global:DisplayName         = 'monitoring Agent'
$global:ServiceName         = '^k.*'
$global:CommandLine         = '^C:\\IBM.ITM\\.*\\K*'
$global:UninstPath          = "${scriptDir}/${UninstName}"
$global:UninstCmdexec       = @("start", "/WAIT", "/MIN", "`"${UninstPath}`"", "-batchrmvall", "-removegskit")
$global:DisableService      = $false
$global:step                = 0
$global:RegistryKeys = @(
    "HKLM:\SOFTWARE\Candle"
    "HKLM:\SOFTWARE\Wow6432Node\Candle",
    "HKLM:\SYSTEM\CurrentControlSet\Services\Candle",
    "HKLM:\SYSTEM\CurrentControlSet\Services\IBM\ITM"
)
# $global:RemoveDirs = @(
#     "C:/Windows/Temp",
#     "C:/Temp/scanner_logs",
#     "C:/Temp/jre",
#     "C:/Temp/report",
#     "C:/Temp/exclude_config.txt",
#     "C:/Temp/Get-Win-Disks-and-Partitions.ps1",
#     "C:/Temp/log4j2-scanner-2.6.5.jar",
#     "C:/salt",
#     "${scriptBin}"
# )
$global:RemoveDirs = @(
    "C:/Temp"
)
. "$PSScriptRoot\AgentUninstall_functions.ps1" # load all functions
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
exit 0

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
    # $text = "run Test-CleanupRegistry"; $step++; Logline -logstring $text -step $step
    # $continue = Test-CleanupRegistry
}
# ----------------------------------------------------------------------------------------------------------------------------
# run Test-CleanupProductFiles.
# ----------------------------------------------------------------------------------------------------------------------------
if ( $continue ) {
    # $text = "run Test-CleanupProductFiles"; $step++; Logline -logstring $text -step $step
    # $continue = Test-CleanupProductFiles
}
# ----------------------------------------------------------------------------------------------------------------------------
# final test.
# ----------------------------------------------------------------------------------------------------------------------------
if ( $continue ) {
    $text = "run Test-IsAllGone"; $step++; Logline -logstring $text -step $step
    $continue = Test-IsAllGone
}# ----------------------------------------------------------------------------------------------------------------------------
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