<#
    https://github.com/artemius1233
#>

# Включение вывода ошибок
$ErrorActionPreference = 'Stop'

# Функция логирования
Function Write-Log {
    param (
        [string]$message
    )
    Write-Host "[LOG] $message"
}

Write-Log "Запуск скрипта"

# WMI Variables
$Namespace = 'SBMT'
$Class = 'Chrome_Extensions'

# Функция создания пространства имен WMI
Function Create-Namespace {
    Write-Log "Создание пространства имен: $Namespace"
    $rootNamespace = [wmiclass]'root:__namespace'
    $NewNamespace = $rootNamespace.CreateInstance()
    $NewNamespace.Name = $Namespace
    $NewNamespace.Put() | Out-Null
    Write-Log "Пространство имен создано"
}

# Функция создания класса WMI
Function Create-Class {
    Write-Log "Создание класса: $Class"
    $NewClass = New-Object System.Management.ManagementClass("root\$namespace", [string]::Empty, $null)
    $NewClass.name = $Class
    $NewClass.Qualifiers.Add("Static", $true)
    $NewClass.Properties.Add("Counter", [System.Management.CimType]::UInt32, $false)
    $NewClass.Qualifiers.Add("Description", "Chrome_Extensions stores information on extensions add in Chrome.")
    $NewClass.Properties.Add("ProfilePath", [System.Management.CimType]::String, $false)
    $NewClass.Properties.Add("ManifestFolder", [System.Management.CimType]::String, $false)
    $NewClass.Properties.Add("FolderDate", [System.Management.CimType]::DateTime, $false)
    $NewClass.Properties.Add("Name", [System.Management.CimType]::String, $false)
    $NewClass.Properties.Add("Version", [System.Management.CimType]::String, $false)
    $NewClass.Properties.Add("ScriptLastRan", [System.Management.CimType]::String, $false)
    $NewClass.Properties["Counter"].Qualifiers.Add("Key", $true)
    $NewClass.Put() | Out-Null
    Write-Log "Класс создан"
}

# Функция парсинга JSON
Function Parse-Json {
    param (
        [Parameter(Mandatory = $true)]
        [string]$JsonString
    )
    Write-Log "Парсинг JSON: $JsonString"
    return $JsonString | ConvertFrom-Json
}

# Функция чтения сообщений из messages.json
Function Get-Message {
    param (
        [string]$MessageFile,
        [string]$MessageKey
    )
    $MessagesContent = Get-Content -Path $MessageFile -Raw -Encoding UTF8
    $MessagesJson = Parse-Json -JsonString $MessagesContent

    if ($MessagesJson.PSObject.Properties.Match($MessageKey)) {
        return $MessagesJson.$MessageKey.message
    }
    return $null
}

# Функция для замены переменных __MSG_*__ на реальные значения
Function Replace-MsgVariables {
    param (
        [string]$ManifestFileFolder,
        [string]$Value
    )
    if ($Value -like '__MSG_*__') {
        $MessageKey = $Value.Trim('__MSG_').Trim('__')
        $LocalesPath = "$ManifestFileFolder\_locales"

        $LocalePriorities = @("en", "en_US", "ru")
        $MessageValue = $null

        foreach ($Locale in $LocalePriorities) {
            $MessageFilePath = Join-Path -Path $LocalesPath -ChildPath "$Locale\messages.json"
            if (Test-Path -Path $MessageFilePath) {
                $MessageValue = Get-Message -MessageFile $MessageFilePath -MessageKey $MessageKey
                if ($MessageValue) {
                    break
                }
            }
        }

        if ($MessageValue) {
            return $MessageValue
        } else {
            Write-Log "Не удалось найти значение для переменной: $Value"
        }
    }
    return $Value
}

# Функция получения и парсинга расширений Chrome
Function Get-ChromeExtensions {
    Write-Log "Получение расширений Chrome"
    $Extensions = @()
    $Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Extensions\"
    $ExtensionFiles = Get-ChildItem -Path $Path -Recurse -Filter "manifest.json" -ErrorAction SilentlyContinue

    foreach ($File in $ExtensionFiles) {
        Write-Log "Чтение файла: $File.FullName"
        $JsonContent = Get-Content -Path $File.FullName -Raw -Encoding UTF8
        $Extension = Parse-Json -JsonString $JsonContent

        $ExtensionName = $Extension.name
        $ExtensionName = Replace-MsgVariables -ManifestFileFolder $File.DirectoryName -Value $ExtensionName

        $ExtensionData = [PSCustomObject]@{
            Name        = $ExtensionName
            Version     = $Extension.version
            Description = $Extension.description
            ID          = (Split-Path -Leaf $File.DirectoryName)
            Enabled     = $true
        }

        $Extensions += $ExtensionData
    }

    Write-Log "Получено расширений: $($Extensions.Count)"
    return $Extensions
}

# Проверка наличия пространства имен WMI и создание, если отсутствует
Write-Log "Проверка наличия пространства имен WMI"
$NSfilter = "Name = '$Namespace'"
$NSExist = Get-WmiObject -Namespace root -Class __namespace -Filter $NSfilter
If ($NSExist -eq $null) {
    Write-Log "Пространство имен отсутствует, создаем новое"
    Create-Namespace
}
Else {
    Write-Log "Пространство имен существует"
}

# Проверка наличия класса WMI и создание, если отсутствует
Write-Log "Проверка наличия класса WMI"
$ClassExist = Get-CimClass -Namespace root/$Namespace -ClassName $Class -ErrorAction SilentlyContinue
If ($ClassExist -eq $null) {
    Write-Log "Класс отсутствует, создаем новый"
    Create-Class
}
Else {
    Write-Log "Класс существует, удаляем и создаем новый"
    Remove-WmiObject -Namespace root/$Namespace -Class $Class
    Create-Class
}

# Получение расширений и сохранение в WMI
Write-Log "Получение и сохранение расширений в WMI"
$Extensions = Get-ChromeExtensions

# Переменная счетчика
$j = 1

foreach ($Extension in $Extensions) {
    Write-Log "Сохранение расширения: $($Extension.Name)"
    (Set-WmiInstance -Namespace root/$Namespace -Class $Class -Arguments @{
        Counter        = $j;
        Name           = $Extension.Name;
        ProfilePath    = $null;
        ManifestFolder = $null;
        FolderDate     = (Get-Date).ToString("yyyyMMddhhmmss") + '.000000-000';
        Version        = $Extension.Version;
        ScriptLastRan  = Get-Date
    })
    $j++
}

Write-Log "Скрипт завершен"