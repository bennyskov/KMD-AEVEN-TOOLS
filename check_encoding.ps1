$files = Get-ChildItem -Path "D:\scripts\GIT\KMD-AEVEN-TOOLS" -Filter "*.yml" -File -Recurse -Exclude "*/archive/*" | Select-Object -First 20

foreach ($file in $files) {
    # Check line endings
    $content = [System.IO.File]::ReadAllText($file.FullName)
    $lineEnding = if ($content -match "`r`n") { "CRLF" } else { "LF" }
    
    # Check encoding by looking for BOM
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
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
    
    Write-Host "$($file.Name): Encoding=$encoding, LineEndings=$lineEnding"
}
