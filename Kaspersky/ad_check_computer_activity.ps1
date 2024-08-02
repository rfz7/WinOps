<#
    Скрипт сверяет давно неиспользуемые в AD учётные записи компьютеров с базой KSC, не подключались ли они к KSC, за заданый период времени
    Если учётная запись ПК не использовалась и не подключалась к KSC, тогда она будет отключена и перенесена в contoso.com/ABCD/Computers/Disabled
    Если учётная запись ПК не активна в AD, но при этом подключалась к KSC, тогда она будет перенесена в contoso.com/ABCD/Computers/Unknown
    Если учётная запись находится в OU Exclusions, то скрипт не будет проверять её
#>

# Variables
$InactiveDays = 30 # Количество неактивных дней
$Days = (Get-Date).Adddays(-($InactiveDays)) # Дата минус неактивные дни
$dataSource = "KSC-SQL01.contoso.com" # fqdn сервера баз данных Kaspersky Security Center
$database = "KAV" # Имя базы данных Kaspersky Security Center
$ouDisabled = "OU=Disabled,OU=Computers,OU=ABCD,DC=contoso,DC=com" # Сюда будут перемещаться неиспользуемые УЗ ПК
$ouUnknown = "OU=Unknown,OU=Computers,OU=ABCD,DC=contoso,DC=com" # Сюда будут перемещаться компьютеры, которые не подключаются к AD, но подключаются к KSC
$ouExclusion = "OU=Exclusion,OU=Computers,OU=ABCD,DC=contoso,DC=com" # Здесь находятся компьютеры, которые скрипт не должен проверять

# Получаем список неактивных компьютеров и исключаем из него, те которые находятся в $ouExclusion
$allComputersAD = Get-ADComputer -Filter {LastLogonTimeStamp -lt $Days -and enabled -eq $true -and OperatingSystem -notlike "Windows Server*" -and OperatingSystem -like "Windows 1*"} -Properties LastLogonTimeStamp
$Computers_Exclusion = Get-ADComputer -Filter {enabled -eq $true } -SearchBase $ouExclusion
$ComputersAD = $AllComputersAD | Where-Object { $_ -ne $Computers_Exclusion }

# mssql query
$sql = "USE [$database] SELECT strWinHostName AS Name,CAST(tmLastNagentConnected AS DATE) AS LastConnectionDate FROM v_hosts WHERE strWinHostName <> '' and strWinHostName is not null and tmLastNagentConnected is not null and DATEDIFF(day,tmLastNagentConnected,GETDATE()) < $InactiveDays"
# mssql auth
$auth = "Integrated Security=SSPI;"
$connectionString = "Provider=sqloledb; " + "Data Source=$dataSource; " + "Initial Catalog=$database; " + "$auth; "
$connection = New-Object System.Data.OleDb.OleDbConnection $connectionString
# mssql connect
$command = New-Object System.Data.OleDb.OleDbCommand $sql,$connection
$connection.Open()
$adapter = New-Object System.Data.OleDb.OleDbDataAdapter $command
$dataset = New-Object System.Data.DataSet
[void] $adapter.Fill($dataSet)
$connection.Close()

# Список активных компьютеров KSC
$ComputersKSC = $dataset.Tables.Name

# Исключить из $ComputersAD комьютеры которые есть в $ComputersKSC
$list_Disable = (Compare-Object -ReferenceObject $ComputersAD.name -DifferenceObject $ComputersKSC | ? {$_.SideIndicator -eq "<="}).InputObject

# Оставить те, которые есть в списке активных компьютеров KSC $ComputersKSC
$list_Unknown = (Compare-Object -ReferenceObject $ComputersKSC -DifferenceObject $ComputersAD.name -IncludeEqual | ? {$_.SideIndicator -eq "=="}).InputObject


# Переместить в Disabled и отключить УЗ ПК
$list_Disable | ForEach-Object {

    $Comp = (Get-ADComputer -Identity $_).distinguishedName

    Move-ADObject -Identity $Comp -TargetPath $ouDisabled
    $_ | Set-ADComputer -Enabled $false
    Write-Host "$_ moved to $ouDisabled"
}

# Переместить в Unknown
$list_Unknown | ForEach-Object {
    $Comp = (Get-ADComputer -Identity $_).distinguishedName
    Move-ADObject -Identity $Comp -TargetPath $ouUnknown
    Write-Host "$_ moved to $ouUnknown"
}
