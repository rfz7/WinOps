# Get current hostname
$hostname = $env:COMPUTERNAME

# Get names list ("current-name" = "new-name")
$computerList = @{
    "MSK-SCCM-TEST01" = "EKB-SCCM-TEST02";
    "KRK-NB-0022" = "KRS-WN-0022";
}

# Rename
if ($null -ne $computerList[$hostname]) {
    Rename-Computer -NewName $computerList[$hostname] -Force -PassThru -Verbose
    Exit 0
}
else {
    Exit 1
}
