# var
$AlarmLicCount = "300"
$Telegram_Url = 'https://api.telegram.org/bot123:ABC_FGH-RZGV/sendMessage'
$Telegram_ChatID = "-1234567890"
$Telegram_Symbol_Warning = "⚠️"

# ksc mssql
$Hostname = [System.Net.Dns]::GetHostByName($env:computerName).HostName
$dataSource = "ksc-db01.contoso.com"
$database = "KAV"

# mssql query
$sql = "USE [KAV]
SELECT
SUM(nLicCount) - SUM(nHostsCurrent) as 'Licences'
FROM v_lickey
JOIN v_lickey_installed ON v_lickey.nId = v_lickey_installed.nKeyId
WHERE
nappid = '1105' and binKeyData IS NOT NULL and tmExpirationLimit > current_timestamp or strSerial = 'ABCG435348SAFDG3239' and tmExpirationLimit > current_timestamp or strSerial = '1688-123456-789101112' and tmExpirationLimit > current_timestamp "

# mssql auth
$auth = "Integrated Security=SSPI;"
$connectionString = "Provider=sqloledb; " +
"Data Source=$dataSource; " +
"Initial Catalog=$database; " +
"$auth; "
$connection = New-Object System.Data.OleDb.OleDbConnection $connectionString

# mssql connect
$command = New-Object System.Data.OleDb.OleDbCommand $sql,$connection
$connection.Open()
$adapter = New-Object System.Data.OleDb.OleDbDataAdapter $command
$dataset = New-Object System.Data.DataSet
[void] $adapter.Fill($dataSet)
$connection.Close()
$rows=($dataset.Tables | Select-Object -Expand Rows)

#
function telegram
    {
    param ($message)
    Invoke-WebRequest -Uri $Telegram_Url -UseBasicParsing -Method POST -Body @{chat_id=$Telegram_ChatID;text=$message} | Out-Null
    }

# send tg msg
if ($rows.licences -le $AlarmLicCount)
    {
    $message = $Telegram_Symbol_Warning + "[$Hostname] Cвободных лицензий Kaspersky: " + $rows.licences
    Write-Host -ForegroundColor Yellow $message
    telegram -message $message
    }
else
    {
    Write-Host -ForegroundColor Green "Свободных лицензий Kaspersky:" $rows.licences
    }
