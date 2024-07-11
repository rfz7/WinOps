# SCCM
$SiteCode = "ABC"
$SiteServer = [System.Net.Dns]::GetHostByName($env:computerName).HostName # FQDN of Site Server

# Application
$AppName = "7-Zip"
$ApplicationName = "7-Zip (auto-update)"
$Description = "7-Zip — свободный файловый архиватор с высокой степенью сжатия данных. Поддерживает несколько алгоритмов сжатия и множество форматов данных, включая собственный формат 7z c высокоэффективным алгоритмом сжатия LZMA"
$URL = "https://www.7-zip.org/download.html"
$Response = Invoke-WebRequest -Uri $URL
$WebVersionPattern = '7-Zip\s(\d+\.\d+)'
$WebVersion = $response.Content | Select-String -Pattern $WebVersionPattern -AllMatches | ForEach-Object { $_.Matches.Groups[1].Value }
$Links = $Response.Links | % { $_.href } | ? { $_ -match "a/7z" -and $_ -match "-x64.exe" }
$DownloadURI = $WebAddress + $links[0]
$AppFileName = $DownloadURI.Split('/')[-1]

# Application settings
$AppDirectory = "Auto updates"
$AppDirectoryOld = "Auto updates\Old versions"
$AppPath = "%ProgramFiles%\7-Zip"
$AppFileNameDetection = "7z.exe"
$install_cmd = "install.cmd"
$install_text = "taskkill.exe /IM `"7z*`" /F`r`ncmd.exe /C START /WAIT /MIN WMIC product where `"Name LIKE '7-Zip%%'`" call uninstall /nointeractive`r`n%~dp0$AppFileName /S"
$AppUninstall = "$AppPath\uninstall.exe /S"

#
$LogFile = "D:\Autodeploy\logs\$AppName.log"
$DistributionPointGroupName = "All Distribution Points"
$CollecionId = "ABC0004B"
$OutFile = "C:\Temp\$AppFileName"
$SCCMSource = "\\consto.com\dfs\SCCM_Files\Application\7-Zip\autoupdate"
$LocalSource = "D:\SCCM_Files\Application\7-Zip\autoupdate"

# telegram
$TelegramBotId = "123_abc-defghj"
$TelegramChatID = "-999999"

# Set security protocol is TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Telegram function
function Send-Telegram {
    param ($message)
    $TelegramUrl = "https://api.telegram.org/bot$TelegramBotid/sendMessage"
    Invoke-WebRequest -Uri $TelegramUrl -UseBasicParsing -Method POST -Body @{chat_id=$TelegramChatID;text=$message} | Out-Null
}

# Logging function
function Write-Log {
    Param ([string]$LogString)
    $Stamp = (Get-Date).toString("dd.MM.yyyy HH:mm:ss")
    $LogMessage = "$Stamp $LogString"
    Add-content $LogFile -value $LogMessage
}

# Connect to SCCM
$initParams = @{}
    if($null -eq (Get-Module ConfigurationManager)) {
        Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams
    }
    if($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
        New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $SiteServer @initParams
    }
Set-Location "$($SiteCode):\" @initParams

# Get current deployed application version
$CurrentVersion = Get-CMApplication -Name $ApplicationName -Fast | Select-Object SoftwareVersion, isdeployed | ?{$_.isdeployed -eq 'True'} | Select-Object -ExpandProperty SoftwareVersion

# Compare $webversion and $versions
Foreach ($version in $CurrentVersion) {
        if ([System.version]$version -ge [System.version]$WebVersion) {
            Write-Output "Current of $AppName version is latest."
            Write-Log "Current version of $AppName is latest."
        }

        if ([System.version]$version -lt [System.version]$WebVersion) {
            Write-Output "$AppName will be updated!"
            Write-Log "$AppName will be updated!"

# Remove old deploy
Write-Output "Removing the old deploy of $AppName"
Write-Log "Removing the old deploy of $AppName"
Get-CMApplicationDeployment -Name $ApplicationName | Remove-CMApplicationDeployment -Force

# Rename and move old version
Write-Output "Renaming and moving the old $AppName"
Write-Log "Renaming and moving the old $AppName"
$app = Get-CMApplication -Name $ApplicationName
$AppOld = $AppName + " " + "(" + $version + ")"
Set-CMApplication -InputObject $app -NewName $AppOld
Move-CMObject -FolderPath "$($SiteCode):\Application\$AppDirectoryOld" -InputObject $app

# Download new version
Write-Output "Downloading new version $AppName"
Write-Log "Downloading new version $AppName"
(New-Object Net.WebClient).DownloadFile($DownloadURI, $OutFile)

# Copy to application source directory
Write-Output "Downloaded version: $Webversion"
Write-Log "Downloaded version: $Webversion"
$filename = $((Get-Item $OutFile).name)
$destinationfolder = "$SCCMSource\$Webversion"
Write-Output "Destination folder is $destinationfolder"
Write-Log "Destination folder is $destinationfolder"

if (!(test-path $destinationfolder)) {
    Write-Output "$destinationfolder does not exist"
    Write-Log "$destinationfolder does not exist"
    [System.IO.Directory]::CreateDirectory($destinationfolder)
    Write-Output "Creating $destinationfolder"
    Write-Log "Creating $destinationfolder"
    [System.IO.File]::Move($outfile,"$destinationfolder\$filename")
    Write-Output "Moving $outfile to $destinationfolder"
    Write-Log "Moving $outfile to $destinationfolder"
    }

# Make install.cmd
$install_text | Out-File "$LocalSource\$webversion\$install_cmd" -Force -Encoding ASCII

# Create application
Write-Output "Create application"
Write-Log "Create application"
New-CMApplication -Name $ApplicationName -Description $Description -AutoInstall $true
$cla1 = New-CMDetectionClauseFile -FileName $AppFileNameDetection -PropertyType Version -ExpectedValue $Webversion -ExpressionOperator GreaterEquals -Path $AppPath -Value

Add-CMScriptDeploymentType -ApplicationName $ApplicationName -DeploymentTypeName "$ApplicationName - $webversion" -InstallCommand "$install_cmd" `
    -UninstallCommand $AppUninstall -AddDetectionClause $cla1 `
    -ContentLocation $destinationfolder -InstallationBehaviorType InstallForSystem -EstimatedRuntimeMins 30 -LogonRequirementType WhetherOrNotUserLoggedOn

$app = Get-CMApplication -Name $ApplicationName
Move-CMObject -FolderPath "$($SiteCode):\Application\$AppDirectory" -InputObject $app

# Distribute content
Write-Output "Distribute content"
Write-Log "Distribute content"
Start-CMContentDistribution -ApplicationName $ApplicationName -DistributionPointGroupName $DistributionPointGroupName
Set-CMApplication -ApplicationName $ApplicationName -SoftwareVersion $WebVersion
New-CMApplicationDeployment -Name $ApplicationName -AvailableDateTime '01/01/2020 00:00:00' -CollectionId $CollecionId -DeadlineDateTime '01/01/2020 00:00:00' -DeployAction Install -DeployPurpose Required -UserNotification DisplaySoftwareCenterOnly -OverrideServiceWindow $true

# telegram push message
$message = "[SCCM] Application update`n$AppName $webversion"
Send-Telegram -message $message

    }
}

# Output to console
Write-Output "Available $AppName Version in Web - $webversion"
Write-Output "Deployed $AppName Version in SCCM - $version"

# Output to log file
Write-Log "Available $AppName Version in Web - $webversion"
Write-Log "Deployed $AppName Version in SCCM - $version"