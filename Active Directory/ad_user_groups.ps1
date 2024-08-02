<#
    Выгрузить группы пользователей в csv
#>

$Users = Get-ADUser -Filter { Enabled -eq $false -and name -notlike "svc.*" } -Properties *

$Properties = @{"login" = ""; "email" = ""; "display_name" = ""; "disable_date" = ""; "groups" = "" }
$UserGroups = @()

foreach ($user in $users) {
    $i = $null
    $i = Get-ADPrincipalGroupMembership $user | select name
    $obj = $null
    $obj = New-Object -TypeName psobject -Property $properties
    $obj.login = [string] $user.SamAccountName
    $obj.email = [string] $user.mail
    $obj.display_name = [string] $user.DisplayName
    $obj.disable_date = [string] $user.whenChanged
    $obj.groups = [array] $i.name
    $UserGroups += $obj
    Write-Host $user.name -ForegroundColor Yellow
}

$UserGroups | Export-Csv -Path C:\temp\1.csv -Encoding UTF8