<#
    Backup FileVault recovery keys
#>

# Connect to Jamf and get temporary token
$jamfUser = "api-user"
$psw_filename = "C:\temp\api-use.dat"
$passw = Get-Content -Encoding ascii -Path $psw_filename | ConvertTo-SecureString
$jamfPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($passw))
$jamfAddress = "https://jamf.contoso.com"
$sqlServerName = "mssql01.contoso.com"
$database = "JamfBackupDataBase"
$tableName = "dbo.JamfRecovery"

# Get Jamf temporary token
$pair = "$($jamfUser):$($jamfPassword)"
$encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
$tokenHeaders = @{ Authorization = "Basic $encodedCredentials" }
$tokenRequest = Invoke-WebRequest -Uri "$($jamfAddress)/api/v1/auth/token" -Method POST -Headers $tokenHeaders -UseBasicParsing
$token = $tokenRequest.Content
$token = $token | ConvertFrom-Json
$token = $token.token
$headers = @{ 'accept' = 'application/json'; 'Authorization' = 'Bearer ' + $token }

# Get all available recovery keys
$recoveryKeysRequest = Invoke-WebRequest -Uri "$($jamfAddress)/api/v1/computers-inventory/filevault?page=0&page-size=10000" -Method GET -Headers $headers -UseBasicParsing
$recoveryKeysRaw = ConvertFrom-Json $([String]::new($recoveryKeysRequest.Content))

# Add id-name-sn-rk to var
$devicesData = $null
$devicesData = @()
$recoveryKeysProperties = @{"id" = ""; "name" = ""; "serialNumber" = ""; "recoveryKey" = ""}

foreach ($key in $recoveryKeysRaw.results) {
    #if ($key.personalRecoveryKey)
    $obj = New-Object -TypeName psobject -Property $recoveryKeysProperties
    $obj.id = [string] $key.computerId
    $obj.name = [string] $key.name
    $obj.serialNumber = [string] $key.DisplayName
    $obj.recoveryKey = [string] $key.personalRecoveryKey
    #$obj.date = [string] (get-date -format "dd.MM.yyyy HH:mm:ss")
    $devicesData += $obj
    $obj = $null
}

# Get info about all managed computers
$AllDevicesInventoryRaw = Invoke-WebRequest -Uri "$($jamfAddress)/api/preview/computers?page=0&page-size=10000" -Method GET -Headers $headers -UseBasicParsing
$AllDevicesInventory = ConvertFrom-Json $([String]::new($AllDevicesInventoryRaw.Content))
$AllDevicesInventory = $AllDevicesInventory.results
$AllDevicesInventoryHashId = @{}
$AllDevicesInventory | % { $AllDevicesInventoryHashId[$_.id]=$_ }
$AllDevicesInventoryHashName = @{}
$AllDevicesInventory | % { $AllDevicesInventoryHashName[$_.Name]=$_ }

#
foreach ($device in $devicesData) {
    $rec = $null
    $rec = $AllDevicesInventoryHashId[$device.Id]
    if (!$rec) {
        $rec = $AllDevicesInventoryHashName[$device.Name]
    }

    if($rec) {
        $device.serialNumber = $rec.serialNumber
    }
    else {
        $device.serialNumber = "NoSerialNumber"
    }
}

# mssql query
$sqlQuery = "select id, name, serialNumber, recoveryKey from dbo.JamfRecovery"
# mssql auth
$auth = "Integrated Security=SSPI;"
$connectionString = "Provider=sqloledb; Data Source=$sqlServerName; Initial Catalog=$database; TrustServerCertificate=True; $auth; "
$connection = New-Object System.Data.OleDb.OleDbConnection $connectionString
# mssql connect
$command = New-Object System.Data.OleDb.OleDbCommand $sqlQuery,$connection
$connection.Open()
$adapter = New-Object System.Data.OleDb.OleDbDataAdapter $command
$dataset = New-Object System.Data.DataSet
[void] $adapter.Fill($dataSet)
$connection.Close()

# Get data from backup database
$dbArray = @()
$dbArray = ForEach($Row in $dataset.Tables[0].Rows){
    $Record = New-Object PSObject
    ForEach($Col in $dataset.Tables[0].Columns.ColumnName){
        Add-Member -InputObject $Record -NotePropertyName $Col -NotePropertyValue $Row.$Col
    }
    $Record
}

# Compare arrays
$finalDeviceList = Compare-Object -ReferenceObject $dbArray -DifferenceObject $devicesData -Property id, name, serialNumber, recoveryKey -ErrorAction SilentlyContinue | ? {$_.SideIndicator -eq "=>"}

# Write to MSSQL Database
if ($null -ne $finalDeviceList) {
    $Connection = New-Object System.Data.SQLClient.SQLConnection
    $Connection.ConnectionString = "server='$sqlServerName';database='$database';trusted_connection=true;"
    $Connection.Open()
    $Command = New-Object System.Data.SQLClient.SQLCommand
    $Command.Connection = $Connection
        foreach($device in $finalDeviceList) {
            $date = Get-Date -format "yyyy-MM-dd HH:mm:ss"
                $insertquery="
            INSERT INTO $tableName
                ([id],[name],[serialNumber],[recoveryKey],[LastUpdateTime])
                VALUES
            ('$($device.Id)','$($device.name)','$($device.serialNumber)','$($device.recoveryKey)','$date')"
            $Command.CommandText = $insertquery
            $Command.ExecuteNonQuery()
        }
    $Connection.Close();
}
else {
    Write-host "No data to write into database" -ForegroundColor Yellow
}