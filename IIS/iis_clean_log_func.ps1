Function Delete-IISLogFiles
    {
        param ([string]$FolderPath,[int]$FileAge=45)
        if (Test-Path -Path $FolderPath)
            {
                Write-Host -ForegroundColor Green "Удаление из"$FolderPath" файлов старше "$FileAge" дней"
                Get-ChildItem -Path $FolderPath -File -Include *.log -Recurse | ? LastWriteTime -lt (Get-Date).AddDays(-$FileAge) | Remove-Item -Force -ErrorAction SilentlyContinue
            }
        else {SendErrMail -errpath $FolderPath}
    }