<#
.SYNOPSIS
    Fix for VS Code PowerShell terminal integration issues
.DESCRIPTION
    This script helps fix the "You cannot call a method on a null-valued expression" error
    in VS Code's PowerShell terminal integration script
.PARAMETER AutoConfirm
    Automatically answer 'y' to all prompts. Default is $true.
.NOTES
    Created to address the error at:
    C:\Program Files\Microsoft VS Code Insiders\resources\app\out\vs\workbench\contrib\terminal\common\scripts\shellIntegration.ps1:109
#>
param (
    [Parameter(Mandatory=$false)]
    [bool]$AutoConfirm = $true
)

$ErrorActionPreference = "Stop"
Write-Host "VS Code PowerShell Terminal Integration Fix" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

if ($AutoConfirm) {
    Write-Host "Auto-confirmation is enabled. Will automatically answer 'y' to all prompts." -ForegroundColor Yellow
}

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "`nThis script may require administrator privileges to modify certain files." -ForegroundColor Yellow
    Write-Host "Consider rerunning as administrator if fixes don't work." -ForegroundColor Yellow
}

# Path to the shellIntegration.ps1 file
$shellIntegrationPath = "C:\Program Files\Microsoft VS Code Insiders\resources\app\out\vs\workbench\contrib\terminal\common\scripts\shellIntegration.ps1"
if (-not (Test-Path $shellIntegrationPath)) {
    $shellIntegrationPath = "C:\Program Files\Microsoft VS Code\resources\app\out\vs\workbench\contrib\terminal\common\scripts\shellIntegration.ps1"
}

if (Test-Path $shellIntegrationPath) {
    Write-Host "`nFound shell integration script at:" -ForegroundColor Green
    Write-Host $shellIntegrationPath

    # Check for the problematic line
    $content = Get-Content $shellIntegrationPath
    $line109 = $content[108] # Line 109 is index 108 (0-based)

    Write-Host "`nContent of line 109:" -ForegroundColor Yellow
    Write-Host $line109

    Write-Host "`nPossible fixes:" -ForegroundColor Magenta

    # Option 1: Create a backup and fix the problematic line with null check
    Write-Host "`n1. Create a backup of PowerShell profile and disable shell integration" -ForegroundColor White

    $profilePath = $PROFILE
    $backupPath = "$profilePath.backup"

    if (Test-Path $profilePath) {
        Write-Host "   - PowerShell profile found at: $profilePath" -ForegroundColor Green

        if ($AutoConfirm) {
            $createBackup = 'y'
            Write-Host "   Would you like to create a backup of your PowerShell profile? (y/n): y (Auto)" -ForegroundColor Gray
        } else {
            $createBackup = Read-Host "   Would you like to create a backup of your PowerShell profile? (y/n)"
        }

        if ($createBackup -eq 'y') {
            Copy-Item -Path $profilePath -Destination $backupPath -Force
            Write-Host "   - Backup created at: $backupPath" -ForegroundColor Green

            if ($AutoConfirm) {
                $updateProfile = 'y'
                Write-Host "   Would you like to disable shell integration in your profile? (y/n): y (Auto)" -ForegroundColor Gray
            } else {
                $updateProfile = Read-Host "   Would you like to disable shell integration in your profile? (y/n)"
            }

            if ($updateProfile -eq 'y') {
                # Add environment variable to disable shell integration
                $profileContent = Get-Content $profilePath
                if (-not ($profileContent -match 'TERM_SHELL_INTEGRATION')) {
                    Add-Content -Path $profilePath -Value "`n# Temporarily disable VS Code shell integration"
                    Add-Content -Path $profilePath -Value '$env:TERM_SHELL_INTEGRATION = "0"'
                    Write-Host "   - Shell integration disabled in profile" -ForegroundColor Green
                } else {
                    Write-Host "   - Shell integration setting already exists in profile" -ForegroundColor Yellow
                }
            }
        }
    } else {
        Write-Host "   - No PowerShell profile found. Would you like to create one? (y/n)" -ForegroundColor Yellow

        if ($AutoConfirm) {
            $createProfile = 'y'
            Write-Host "   y (Auto)" -ForegroundColor Gray
        } else {
            $createProfile = Read-Host
        }

        if ($createProfile -eq 'y') {
            New-Item -Path $profilePath -ItemType File -Force
            Add-Content -Path $profilePath -Value "# PowerShell Profile"
            Add-Content -Path $profilePath -Value "`n# Temporarily disable VS Code shell integration"
            Add-Content -Path $profilePath -Value '$env:TERM_SHELL_INTEGRATION = "0"'
            Write-Host "   - Created profile and disabled shell integration" -ForegroundColor Green
        }
    }

    # Option 2: Create settings.json modification for VS Code
    Write-Host "`n2. Update VS Code settings to disable shell integration" -ForegroundColor White

    $settingsPath = "$env:APPDATA\Code\User\settings.json"
    $insidersSettingsPath = "$env:APPDATA\Code - Insiders\User\settings.json"

    $settingsToUse = if (Test-Path $insidersSettingsPath) { $insidersSettingsPath } else { $settingsPath }

    if (Test-Path $settingsToUse) {
        Write-Host "   - VS Code settings found at: $settingsToUse" -ForegroundColor Green

        if ($AutoConfirm) {
            $updateSettings = 'y'
            Write-Host "   Would you like to update VS Code settings to disable terminal shell integration? (y/n): y (Auto)" -ForegroundColor Gray
        } else {
            $updateSettings = Read-Host "   Would you like to update VS Code settings to disable terminal shell integration? (y/n)"
        }

        if ($updateSettings -eq 'y') {
            try {
                $settings = Get-Content $settingsToUse -Raw | ConvertFrom-Json
                $settings | Add-Member -NotePropertyName "terminal.integrated.shellIntegration.enabled" -NotePropertyValue $false -Force
                $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsToUse
                Write-Host "   - VS Code settings updated to disable shell integration" -ForegroundColor Green
            } catch {
                Write-Host "   - Error updating VS Code settings: $_" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "   - VS Code settings file not found" -ForegroundColor Yellow
    }
} else {
    Write-Host "`nCould not find shell integration script. You may have a different VS Code installation path." -ForegroundColor Red
}

Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Restart VS Code" -ForegroundColor White
Write-Host "2. Restart any PowerShell terminal sessions" -ForegroundColor White
Write-Host "3. If the problem persists, consider reinstalling the PowerShell extension" -ForegroundColor White
Write-Host "4. You can also create a new issue at https://github.com/microsoft/vscode/issues" -ForegroundColor White

Write-Host "`nTemporary workaround:" -ForegroundColor Cyan
Write-Host "Run this command before starting VS Code: `$env:TERM_SHELL_INTEGRATION = '0'" -ForegroundColor White
