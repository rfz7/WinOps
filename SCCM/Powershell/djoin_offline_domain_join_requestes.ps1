<#
    Создание оффлайн домен джойн реквестов
#>

# Подключение к SCCM
$SiteCode = "ABC" # Site code
$ProviderMachineName = "sccm.contoso.com" # SMS Provider machine name
$initParams = @{}
if ((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams
}
if ((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
}
Set-Location "$($SiteCode):\" @initParams

<#
    1. Получить список серийников девайсов которые не в домене
    2. Получить их имена из жиры
    3. Получить список реквестов оффлайн домен джойна
    4. Сравнить массивы и получить список девайсов для которых нет реквеста
    5. Создать реквесты
#>

# Variables
$Token = "YOUR TOKEN HERE"
$ApiUrl = "https://jira.contoso.com/rest/assets/1.0/aql/objects?iql="
$ApiParam = "&includeAttributes=false"
$ApiFilter = "Serial%20like%20"
$NetworkPath = "\\contoso.com\abcd\Logs\djoin"
$CollectionId = "ABC00105" # Non domain devices with NB-ISC hostname

# 1. Получить список серийников девайсов которые не в домене
$SerialNumbersRaw = (Get-CMCollectionMember -CollectionId $CollectionId).SerialNumber
$SerialNumbers = @()

# Проверка серийников
foreach ($SerialNumber in $SerialNumbersRaw) {
    if (($SerialNumber -eq $null) -or ($SerialNumber.Contains(" ")) -or ($SerialNumber.Length -lt 5)) {
            Write-host "$SerialNumber is incorrect" -ForegroundColor Magenta
        }
        else {
            $SerialNumbers += $SerialNumber
        }
    }

# №2 Получение имён девайсов из жиры
$JiraNames = $null
$JiraNames = @()
$t = 2
$r = 120

foreach ($sn in $SerialNumbers) {
    $null = $comp
    $CompUri = $ApiUrl + $ApiFilter + $sn + $ApiParam
    $Comp = Invoke-RestMethod -Headers @{ 'Authorization' = 'Bearer ' + $Token } -Method 'GET' -Uri $CompUri -ErrorAction Continue

    if ($null -eq $Comp.objectEntries.objectKey) { continue }
    $PCname = "NB-" + $Comp.objectEntries.objectKey
    $JiraNames += $PCname
    $t++
    Write-Host "Request: $t" -ForegroundColor DarkCyan
    Write-Host $PCName":" $sn -ForegroundColor DarkYellow
    if ( $t % $r -eq 0 ) {
        Write-Host "PAUSE: 61 seconds" -ForegroundColor Magenta
        Write-Host "PAUSE: 61 seconds" -ForegroundColor Red
        Write-Host "PAUSE: 61 seconds" -ForegroundColor Cyan
        Start-Sleep 61
    }
}

$JiraNames.count

# Пункт №3. Получить список реквестов оффлайн домен джойна
$source = [System.IO.Directory]::GetFiles($NetworkPath, "*.djoin.txt")
$ExistDevices = @()
foreach ($i in $source) {
    $lastSlashIndex = $i.LastIndexOf('\')
    $parsedString = $i.Substring($lastSlashIndex + 1)
    $r = $parsedString.replace(".djoin.txt","")
    $ExistDevices += $r
    Write-Host $r -ForegroundColor Yellow
}
$ExistDevices.Count

# Получить список уже существующих объектов в AD
$AdObjects = (Get-ADComputer -Filter {enabled -eq "true"}).Name
$AdObjects = (Get-ADComputer -Filter *).Name

$ExistDevices = $ExistDevices | Select -Unique
$JiraNames = $JiraNames | Select -Unique

# Исключить из $JiraNames комьютеры которые есть в $ExistDevices
$list1 = (Compare-Object -ReferenceObject $JiraNames -DifferenceObject $ExistDevices | ? {$_.SideIndicator -eq "<="}).InputObject
$list1.Count

# Исключить из $ComputersAD комьютеры которые есть в $ComputersKSC
$OfflineDomainJoinList = @()
$OfflineDomainJoinList = (Compare-Object -ReferenceObject $list1 -DifferenceObject $AdObjects | ? {$_.SideIndicator -eq "<="}).InputObject
$OfflineDomainJoinList.count

#$OfflineDomainJoinList = gc C:\temp\djoin\nondomain-2024-07-20.txt
if (($OfflineDomainJoinList).count -ge "1") {
    foreach ($a in $OfflineDomainJoinList) {
        cmd /c djoin /provision /domain contoso.com /machine $a /machineOU "OU=djoin,OU=Computers,OU=ABCD,DC=contoso,DC=com" /ROOTCACERTS /CERTTEMPLATE "ABCDClientsCertificate" /savefile C:\temp\djoin\$a.djoin.txt
    }
}

# Скопировать Offline Domain Join Requestes в сетевую шару
