<#
    https://jira.contoso.com/browse/ID-68857

    1. Получить из Jira Insight два списка компьютеров и ноутбоков, которые имеют отличный от "In Use" и "In stock" статус
    2. Получить список включённых УЗ ПК из Active Directory
    3. Получить список рабочих станций из SCCM
    4. Сравнить списки на наличие неактивных компьютеров и ноутбуков в Active Directory
    5. Сравнить списки на наличие неактивных компьютеров и ноутбуков в SCCM
    6. Отключить и переместить найденные в OU Disabled
    7. Удалить найденные из SCCM
    8. Удалить найденные из KSC

#>

$Token = "YOUR TOKEN HERE" # Токен для подключения
$ApiUrl = "https://jira.contoso.com/rest/assets/1.0/iql/objects?iql=" # Адрес Jira API
$ApiParam = "&includeAttributes=false&resultPerPage=10000" # Дополнительные параметры запроса: не выводить расширенные аттрибуты и максимальное кол-во устройств в выводе 10к
$ApiLaptopsFilter = '(objectType = "Laptops" AND "Status" = "In use" AND "Manufacture" != "Apple") OR (objectType = "Laptops" AND "Status" = "In Stock" AND "Manufacture" != "Apple")' # Фильтр запроса для ноутбуков. Копируется из веб и интерфейса
$ApiCompsFilter = '(objectType = "PC" AND Status = "In use" AND Manufacture != "Apple") OR (objectType = "PC" AND Status = "In Stock" AND Manufacture != "Apple")' # Фильтр запроса для компьютеров. Копируется из веб и интерфейса
$ApiMacBooksFilter = '(objectType = "Laptops" AND Status = "In use" AND Manufacture = "Apple") OR (objectType = "Laptops" AND Status = "In Stock" AND Manufacture = "Apple")' # Фильтр запроса для компьютеров. Копируется из веб и интерфейса
$DisabledOU = "OU=Disabled,OU=Computers,OU=ABCD,DC=contoso,DC=com" # OU куда будут перемещаться неактивные учётные записи компьютеров
$CMCollectionId = "ABC00061" # SCCM коллекция со всеми рабочими станциями

# Подключение к SCCM
$SiteCode = "ABC" # Site code
$ProviderMachineName = "sccm.contoso.com" # SMS Provider machine name
$initParams = @{}
if($null -eq (Get-Module ConfigurationManager)) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams
}
if($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
}
Set-Location "$($SiteCode):\" @initParams

######### Laptops
# Получение списка неактивных ноутбуков из Jira Insight
$LaptopUri = $ApiUrl + $ApiLaptopsFilter + $ApiParam
$GetNB = Invoke-RestMethod -Headers @{ 'Authorization' = 'Bearer ' + $Token } -Method 'GET' -Uri $LaptopUri -ErrorAction Continue

# Список ноутбуков по имени NB-ISC
$InactiveLaptopNamesList = $GetNB.objectEntries.objectKey
$InactiveLaptopNames = $null
$InactiveLaptopNames = @()
foreach ($Item in $InactiveLaptopNamesList) {
    $InactiveLaptopNames += "NB-" + $Item
}

# Список ноутбуков по серийному номеру
$InactiveLaptopSerialsList = $GetNB.objectEntries.name
$InactiveLaptopSerials = $null
$InactiveLaptopSerials = @()
foreach ($Item in $InactiveLaptopSerialsList) {
    $InactiveLaptopSerials += "NB-" + $Item
}

######### Computer
# Получение списка неактивных стационарных компьютеров из Jira Insight
$CompUri = $ApiUrl + $ApiCompsFilter + $ApiParam
$GetPC = Invoke-RestMethod -Headers @{ 'Authorization' = 'Bearer ' + $Token } -Method 'GET' -Uri $CompUri -ErrorAction Continue

# Список компьютеров по имени NB-ISC
$InactiveCompNamesList = $GetPC.objectEntries.objectKey
$InactiveCompNames = $null
$InactiveCompNames = @()
foreach ($Item in $InactiveCompNamesList) {
    $InactiveCompNames += "NB-" + $Item
}

# Список компьютеров по серийному номеру
$InactiveCompSerialsList = $GetPC.objectEntries.name
$InactiveCompSerials = $null
$InactiveCompSerials = @()
foreach ($Item in $InactiveCompSerialsList) {
    $InactiveCompSerials += "PC-" + $Item
}

$InactiveDevices = $null
$InactiveDevices = $InactiveLaptopNames + $InactiveCompNames
$InactiveSerials = $null
$InactiveSerials = $InactiveLaptopSerials + $InactiveCompSerials

# Получить включенные учётные записи компьютеро в Active Directory
$ActiveDirectoryEnabledComputersList = Get-ADComputer -Filter "enabled -eq 'true'" -SearchBase "OU=Computers,OU=ABCD,DC=contoso,DC=com"
# Оставить только имена компьютеров
$ActiveDirectoryEnabledComputers = $ActiveDirectoryEnabledComputersList.name

# Найти компьютеры из списка $InactiveDevices в $ActiveDirectoryEnabledComputers
$ListForDisableAD = (Compare-Object -ReferenceObject $ActiveDirectoryEnabledComputers -DifferenceObject $InactiveDevices -IncludeEqual | ? {$_.SideIndicator -eq "=="}).InputObject

# Отключить УЗ ПК в AD
foreach ($device in $ListForDisableAD) {
    Get-ADComputer -Identity $device -ErrorAction SilentlyContinue | Disable-ADAccount -PassThru | Move-ADObject -TargetPath $DisabledOU
}

# SCCM Все рабочие станции
$CMDevices = Get-CMCollectionMember -CollectionId $CMCollectionId

# Найти компьютеры из списка $InactiveDevices в ($CMDevices).Name
$CmUnistallNameList = (Compare-Object -ReferenceObject $InactiveDevices -DifferenceObject ($CMDevices).Name -IncludeEqual -ErrorAction SilentlyContinue | ? {$_.SideIndicator -eq "=="}).InputObject
# Найти компьютеры из списка $InactiveDevices в ($CMDevices).SerialNumber
$CmUnistallSerialNumberList = (Compare-Object -ReferenceObject @($InactiveSerials | Select-Object) -DifferenceObject @(($CMDevices).SerialNumber | Select-Object) -IncludeEqual -ErrorAction SilentlyContinue | ? {$_.SideIndicator -eq "=="}).InputObject

# SCCM: Удаление девайса по имени / Добавление в коллекцию удаления ссм клиента
foreach ($device in $InactiveDevices) {
    #Get-ADComputer -Identity $device -ErrorAction SilentlyContinue | Disable-ADAccount -PassThru | Move-ADObject -TargetPath $DisabledOU
    #Get-CMDevice -Name $device -ErrorAction SilentlyContinue | Remove-CMDevice -Confirm:$false -Force
}

# SCCM: Удаление девайса по серийному номеру / Добавление в коллекцию удаления ссм клиента [Выбрать что необходимо делать с девайсом]

# Certification Authtority: Отзыв сертификата

# KSC: Удаление девайса

# Jamf: Удалие девайса