#!powershell
#Requires -Module Ansible.ModuleUtils.Legacy
#$ErrorActionPreference = "Stop"
$ErrorActionPreference = "Continue"

$params = Parse-Args $args -supports_check_mode $true
$silentFilename = Get-AnsibleParam -obj $params -name "silent_file_name" -type "str" -failifempty $true
$silentLogFilename = Get-AnsibleParam -obj $params -name "silent_log_file_name" -type "str" -failifempty $true

# Script to find and Uninstall "IBM Tivoli Monitoring" from a windows server.
# This script will search in the registry for the Tivoli uninstall string and will modify it accordingly for a SILENT uninstall.
# The function CreateSilentFile will create a "silent_uninstall.txt" file on the temp folder. This file is required for the
# uninstall command to work properly and uninstall Tivoli endpoint without interaction.
# Part of the command line instructions can be found on the link below:
# https://www.ibm.com/docs/en/tivoli-monitoring/6.3.0?topic=silently-performing-silent-uninstallation-windows-computer
#
# Script author= emurari@kyndryl.com
#-------
function CreateSilentFile{
    $silentContent = ";*********************************************************************
;
;                   Monitoring Agent for Windows OS
;
;                 Silent Un-Installation Response File
;
;*********************************************************************
;
;
;---------------------------------------------------------------------
[ACTION TYPE]
;---------------------------------------------------------------------
UNINSTALLALL=Yes
;
;---------------------------------------------------------------------
[INSTALLATION SECTION]
;---------------------------------------------------------------------
;
AgentDeploy=yes
License Agreement=I agree to use the software only in accordance with the installed license.
;
;---------------------------------------------------------------------
[FEATURES]
;---------------------------------------------------------------------
;
KNT64CMA=Monitoring Agent for Windows OS
;
;---------------------------------------------------------------------
[CMA_CONFIG]
;---------------------------------------------------------------------
;
;   No configuration information is needed for uninstall
;
;*********************************************************************
; 			END OF SILENT UN-INSTALLATION FILE.
;*********************************************************************
"
Try{
    #$silentFilename = "c:\temp\ITMsilent_uninstall.txt"
    if(test-path $silentFilename){
        Get-Item -path $silentFilename | Remove-Item
    }
    New-Item -ItemType File -path $silentFilename
    Add-Content -Path $silentFilename -Value $silentContent
    [PSCustomObject]@{
        Result	= "File Created"
        Status	= $true
    }
}
Catch{
    $strError = "CreateSilentFile(): Exception: $($_.Exception)"
    [PSCustomObject]@{
        Result	= $strError
        Status	= $false
    }
}
}

$resultCreateFile = CreateSilentFile
if(-Not($resultCreateFile.Status)){
#$resultCreateFile.Result
$result = @{task="Silent File Creation Failed";message=$strError;status="failed"}
}
else
{
Try{
$found = $false
$appName = "IBM Tivoli Monitoring"
$InstalledSoftware = Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
foreach($obj in $InstalledSoftware){
    $tempname = $obj.GetValue("DisplayName")
    If($tempname -eq $appname){
        $uninstString = $obj.GetValue('UninstallString')
        $found = $true
    }
}

if (!($found)){
    $InstalledSoftware = Get-ChildItem "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    #$i =1
    foreach($obj in $InstalledSoftware){
        $tempname = $obj.GetValue("DisplayName")
        If($tempname -eq $appname){
            $uninstString = $obj.GetValue('UninstallString')
            $found = $true
            break
        }
    }
}

if($found){
    #$cmdToRun = -join($uninstString," /s /z`"/sfC:\temp\ITMsilent_uninstall.txt`" /f2`"c:\temp\silentITM_removal.log`"")
    $cmdToRun = -join($uninstString," /s /z`"/sf$silentFilename`" /f2`"$silentLogFilename`"")
    $cmdToRun | cmd

    $found = $false
    $appName = "IBM Tivoli Monitoring"
    $InstalledSoftware = Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
    foreach($obj in $InstalledSoftware)
    {
        $tempname = $obj.GetValue("DisplayName")
        If($tempname -eq $appname)
        {
            $uninstString = $obj.GetValue('UninstallString')
            $found_validation = $true
        }
    }

    if (!($found_validation))
    {
        $InstalledSoftware = Get-ChildItem "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        foreach($obj in $InstalledSoftware)
        {
            $tempname = $obj.GetValue("DisplayName")
            If($tempname -eq $appname)
            {
                $uninstString = $obj.GetValue('UninstallString')
                $found_validation = $true
                break
            }
        }
    }
    if (!($found_validation))
    {
    $result = @{task="Uninstall String Command Executed Successfully";message=$cmdToRun;status="success"}
    }
    else
    {
        $result = @{task="Uninstall String Command Executed Successfully, But ITM is still found in registry";message=$cmdToRun;status="failed"}
    }
}
}
Catch{
$strError = "Exception: $($_.Exception)"
#$strError
$result = @{task="Uninstall String not found";message=$strError;status="failed"}
}
}

Exit-Json $result
#-------------