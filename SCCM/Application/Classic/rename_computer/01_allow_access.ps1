# Computers list
$computerList = @{
    "MSK-SCCM-TEST01" = "PC-TEST02";
    "KRK-NB-0022" = "PC-WN-0022";
    }

foreach ($i in $computerList.keys) {
    $comp = Get-ADComputer $i
    $path = "AD:\" + $comp.DistinguishedName
    $acl = Get-Acl $path

# Create ACE
    $compSID = [System.Security.Principal.SecurityIdentifier]$comp.SID
    $aceIdentity = [System.Security.Principal.IdentityReference] $compSID
    $aceRights = [System.DirectoryServices.ActiveDirectoryRights] "GenericAll"
    $aceType = [System.Security.AccessControl.AccessControlType] "Allow"
    $aceInheritanceType = [System.DirectoryServices.ActiveDirectorySecurityInheritance] "None"
    $ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $aceIdentity,$aceRights,$aceType,$aceInheritanceType

# Add ACE to ACL
    $acl.AddAccessRule($ace)
    Set-acl -aclobject $acl $path -ErrorAction SilentlyContinue #-WhatIf
    if ($?) {
        Write-Host "$($i): Access rights granted successfully" -ForegroundColor Green
        }
    else {
        Write-Host "$($i): Error" -ForegroundColor Red
        }
    $i = $null
}
