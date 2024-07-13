# Variables
$AdfsServer = "adfs01.contoso.com"
$JiraApiAddress = "https://jira.contoso.com/rest/assets/1.0/aql/objects?iql="
$Token = "YOUR JIRA TOKEN HERE"
$TelegramBotId = "1234567890_abcdge-x8dh8c"
$TelegramChatID = "-1234567890"
$MailServer = "mail.contoso.ru"
$MailFrom = "from@contoso.com"
$MailTo = "to@contoso.com"

# Telegram function
function Send-Telegram {
    param ($message)
    $TelegramUrl = "https://api.telegram.org/bot$TelegramBotid/sendMessage"
    Invoke-WebRequest -Uri $TelegramUrl -UseBasicParsing -Method POST -Body @{chat_id=$TelegramChatID;text=$message} | Out-Null
}

# Connect to ADFS server and get data
$RemoteSession = New-PSSession -ComputerName $AdfsServer -UseSSL
$Data = Invoke-Command -Session $RemoteSession -ScriptBlock {
    # Get ADFS Relying Party Trustes
    $AdfsRPT = Get-AdfsRelyingPartyTrust | ? { $_.Enabled -eq $True -and $_.Notes -ne $null -and $_.Notes -like "*assets*" } | Select Name, Notes | sort name
    # Get ADFS Application Groups
    $AdfsAG = Get-AdfsApplicationGroup | ? { $_.Description -ne $null -and $_.Description -like "*assets*" } | Select Name, Description | sort name
    foreach ( $obj in $AdfsRPT) {
        $obj | Add-Member -MemberType NoteProperty -Name Description -Value $obj.Notes -Force
        $obj | Add-Member -MemberType NoteProperty -Name Type -Value "RPT" -Force
        }
    foreach ( $obj in $AdfsAG) {
        $obj | Add-Member -MemberType NoteProperty -Name Type -Value "AG" -Force
        }
    $AdfsRPT += $AdfsAG
    Return $AdfsRPT
}
Remove-PSSession -Session $RemoteSession

# Check service status in Jira cmdb
foreach ($i in $Data) {
    $lastSlashIndex = $i.Description.LastIndexOf('/')
    $parsedString = $i.Description.Substring($lastSlashIndex + 1)
    $Filter = "Key IN (""$parsedString"")"
    $Query = $JiraApiAddress + $Filter
    $Query = Invoke-RestMethod -Headers @{ 'Authorization' = 'Bearer ' + $Token } -Method 'GET' -Uri $Query
    $Status = $Query.objectEntries.attributes.objectAttributeValues.displayvalue[3]
    $i | Add-Member -MemberType NoteProperty -Name Status -Value $Status -Force
}

# Rename headers
$Renamed = $Data | Select-Object Name,Type,@{Name="Link";Expression="Description"},Status
$Inactive = $Renamed | Where-Object {$_.Status -eq "Inactive"}
$Result = ""
foreach ($item in $Inactive) {
    $Result += "Name: $($item.Name), Type: $($item.Type), Link: $($item.Link), Status: $($item.Status)<BR>"
}

# telegram send message
$message = @"
⚠️[ADFS] Relying Party Trust and Application Group inactive services:

$($Result.replace("<BR>","`r`n"))
"@

# Send message to telegram
Send-Telegram -message $message

# Send e-mail
$sendMailMessageSplat = @{
    From = $MailFrom
    To = $MailTo
    Subject = 'ADFS Services Status'
    Body = $Result
}
Send-MailMessage @sendMailMessageSplat -BodyAsHtml -SmtpServer $MailServer -Port 587
