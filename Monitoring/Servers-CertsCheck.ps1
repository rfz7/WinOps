$telegram_Url = 'https://api.telegram.org/bot1234567:ABSD32423_asfsdfgGF-asdas/sendMessage'
$telegram_ChatID = "-1234567890"
$telegram_Symbol_Stop = "⛔"
$telegram_Symbol_Done = "✅"
$telegram_Symbol_Warning = "⚠️"
$telegram_Alarm_Users = "@durov"

function telegram
{
    param ($message)
    Invoke-WebRequest -Uri $telegram_Url -UseBasicParsing -Method POST -Body @{chat_id=$telegram_ChatID;text=$message} | Out-Null
}

$psw_filename = "C:\TaskScheduler\Stg\svc.script01.dat"
$username = "corp\svc.script01"
$passw = Get-Content -Encoding ascii -Path $psw_filename | ConvertTo-SecureString # пароль (System.Security.SecureString)
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $passw

$servers = Get-ADComputer -Filter * -SearchBase "OU=Inf, OU=Servers, OU=CORP, DC=contoso, DC=com" | ? { ($_.DistinguishedName -notlike "*OU=cluster,*") -and ($_.DistinguishedName -notlike "*OU=disabled,*")} | select Name

$date = Get-Date -Format "yyyy_MM_dd"
$errorServersFile = "C:\TaskScheduler\Monitoring\certsInfo\" + $($date) + "_error_servers.log"
$certsInfoFile = "C:\TaskScheduler\Monitoring\certsInfo\certs_info.csv"

if (Test-Path $certsInfoFile) {
        Remove-Item $certsInfoFile -verbose
    }

"Value;CN;Server;Thumbprint;FriendlyName" | out-file $certsInfoFile

$totalErrors = 0

foreach($server in $servers) {
try {
        $url = $server.name + ".contoso.com"
        $s = New-PSSession $url -UseSSL -Authentication Kerberos -Credential $cred
        $req_results = Invoke-Command -Session $s -ScriptBlock {
        Get-ChildItem cert:\LocalMachine\my | Select subject, notafter, friendlyname, thumbprint}

        foreach ($result in $req_results) {

            $today = Get-Date
            $ts = New-TimeSpan -Start $today -End $result.NotAfter
            "$($ts.TotalHours);$($result.Subject);$($result.PSComputerName);$($result.Thumbprint);$($result.FriendlyName)" | Out-File $certsInfoFile -Append
}
}
catch {
    $ErrorMessage = $Error[1].Exception.Message
    $ErrorMessage = ($ErrorMessage -split '\n')[0]
    $ErrorMessage = $ErrorMessage.split(':')[1,2]
    $ErrorMessage = $ErrorMessage[0] + ":" + $ErrorMessage[1]
    (Get-Date -Format "dd.MM.yyyy HH:mm") + " " + $server.Name + $ErrorMessage | Out-File $errorServersFile -Append
    $totalErrors++
    }
}


if ($totalErrors -gt 0){
    $message = $telegram_Symbol_Warning + " Servers($($totalErrors)) are unavailable to connect for certificate's check job. Please verify log file." + $telegram_Alarm_Users
    telegram -message $message
}
else {
    $message = $telegram_Symbol_Done + " Servers certificates has been successfully checked."
    telegram -message $message
}
