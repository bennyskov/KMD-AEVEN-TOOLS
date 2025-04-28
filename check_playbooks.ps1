# List of main playbooks to check
$mainPlaybooks = @(
    "de-tooling_begin.yml",
    "de-tooling_cleanup_CACF_linux.yml",
    "de-tooling_disable_SCCM_windows.yml",
    "de-tooling_REinstall_ITM_linux.yml",
    "de-tooling_REinstall_ITM_windows.yml",
    "de-tooling_servercheck_windows.yml",
    "de-tooling_set_maintenancemode.yml",
    "de-tooling_UNinstall_ITM_linux.yml",
    "de-tooling_UNinstall_ITM_windows.yml",
    "linux_remote_aeven_SA_install.yml",
    "linux_remote_aeven_SA_redirect.yml",
    "linux_remote_aeven_SA_Uninstall.yml",
    "windows_remote_aeven_SA_install.yml",
    "windows_remote_aeven_SA_uninstall.yml"
)

$basePath = "D:\scripts\GIT\KMD-AEVEN-TOOLS"
$results = @()

foreach ($playbookName in $mainPlaybooks) {
    $filePath = Join-Path -Path $basePath -ChildPath $playbookName
    
    if (Test-Path $filePath) {
        # Check line endings
        $content = [System.IO.File]::ReadAllText($filePath)
        $lineEnding = if ($content -match "`r`n") { "CRLF" } else { "LF" }
        
        # Check encoding by looking for BOM
        $bytes = [System.IO.File]::ReadAllBytes($filePath)
        $encoding = "Unknown"
        
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            $encoding = "UTF-8 with BOM"
        } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
            $encoding = "UTF-16 BE"
        } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
            $encoding = "UTF-16 LE"
        } else {
            $encoding = "UTF-8 without BOM or ASCII"
        }
        
        $results += [PSCustomObject]@{
            Playbook = $playbookName
            Encoding = $encoding
            LineEndings = $lineEnding
            RequiresUpdate = ($encoding -ne "UTF-8 without BOM" -or $lineEnding -ne "LF")
        }
    } else {
        Write-Host "File not found: $filePath" -ForegroundColor Yellow
    }
}

$results | Format-Table -AutoSize

Write-Host "Summary:" -ForegroundColor Green
Write-Host "- Files with CRLF line endings: $($results | Where-Object { $_.LineEndings -eq 'CRLF' } | Measure-Object | Select-Object -ExpandProperty Count)"
Write-Host "- Files with LF line endings: $($results | Where-Object { $_.LineEndings -eq 'LF' } | Measure-Object | Select-Object -ExpandProperty Count)"
Write-Host "- Files with UTF-8 with BOM: $($results | Where-Object { $_.Encoding -eq 'UTF-8 with BOM' } | Measure-Object | Select-Object -ExpandProperty Count)"
Write-Host "- Files with UTF-8 without BOM: $($results | Where-Object { $_.Encoding -like 'UTF-8 without BOM*' } | Measure-Object | Select-Object -ExpandProperty Count)"
Write-Host "- Files requiring update: $($results | Where-Object { $_.RequiresUpdate } | Measure-Object | Select-Object -ExpandProperty Count)"
