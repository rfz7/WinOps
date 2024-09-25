$hostname = $env:COMPUTERNAME
$regValue = Get-ItemPropertyValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName" -Name "ComputerName"
if ($hostname -match "PC-" -or $regValue -match "PC-") { Write-Host "Installed" } else { }
