Set-Location "C:\inetpub\logs\LogFiles\" -ErrorAction Stop
$files = Get-ChildItem -Filter "*.log" -Recurse

foreach ($file in $files) {
    if ($File.LastWriteTime -lt (Get-Date).AddDays(-45)) {
        Write-Host $file.FullName
        Remove-Item $file.FullName -Force
    }
}