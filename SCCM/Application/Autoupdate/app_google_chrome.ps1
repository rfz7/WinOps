<#
        Script for check new versions of Google Chrome, create application and deploy
#>


# Connect to SCCM
$SiteCode = "ABC"
$ProviderMachineName = "msk-s-sccm01.contoso.com"
$initParams = @{}
    if($null -eq (Get-Module ConfigurationManager)) {
        Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams
    }
    if($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
        New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
    }
Set-Location "$($SiteCode):\" @initParams


# telegram
$Telegram_Url = 'https://api.telegram.org/bot123:ABCFGH_g4g4g-asd3/sendMessage'
$Telegram_ChatID = "-100123456789"

function telegram
    {
    param ($message)
    Invoke-WebRequest -Uri $Telegram_Url -UseBasicParsing -Method POST -Body @{chat_id=$Telegram_ChatID;text=$message} | Out-Null
    }


# Variables
$Hostname = [System.Net.Dns]::GetHostByName($env:computerName).HostName # Get fqdn
$URIchrome = "https://dl.google.com/edgedl/chrome/install/GoogleChromeStandaloneEnterprise64.msi" # Google Chrome download URL
$OutFile = "C:\Temp\GoogleChromeStandaloneEnterprise64.msi" # Path for save
$collection = "Update | Google Chrome (required)" # Collection for deploy
$SCCMSource = "\\contoso.com\dfs\SCCM_Files\Application\Google\Chrome\autoupdate" # Content folder path
#$Uri = "https://versionhistory.googleapis.com/v1/chrome/platforms/win/channels/stable/versions" # Google Chrome version JSON
$Uri = "https://cdn.jsdelivr.net/gh/berstend/chrome-versions/data/stable/windows/version/latest.json"

# Logging function
$logfile = "D:\Autodeploy\logs\chrome.log"
function WriteLog
{
Param ([string]$LogString)
$Stamp = (Get-Date).toString("dd/MM/yyyy HH:mm:ss")
$LogMessage = "$Stamp $LogString"
Add-content $LogFile -value $LogMessage
}

# JSON parsing and convert data to PSObject
$chromeVersions = (Invoke-WebRequest -uri $Uri).Content | ConvertFrom-Json
#$webversion = $chromeVersions.versions[0].version
$webversion = $chromeVersions.version

# Set application name
$appnamecr = "Google Chrome - autodeploy"

# Get current deployed google chrome version
#$versions = Get-CMApplication -Name $appnamecr -Fast | Select-Object SoftwareVersion, isdeployed | ?{$_.isdeployed -eq 'True'} | Select-Object -ExpandProperty SoftwareVersion
$versions = Get-CMApplication -Name $appnamecr -Fast | Select-Object SoftwareVersion | Select-Object -ExpandProperty SoftwareVersion

# Compare $webversion and $versions
Foreach ($version in $versions)
{

        if ([System.version]$version -ge [System.version]$webversion)
    {
    Write-Output "Chrome in sccm is up to date!"
    Writelog "Chrome in sccm is up to date!"
    }

        if ([System.version]$version -lt [System.version]$webversion)
    {
    Write-Output "Chrome will be updated!"
    Writelog "Chrome will be updated!"

# Remove old deploy of Google Chrome
Write-Output "Removing the old deploy of Google Chrome"
Get-CMApplicationDeployment -Name $appnamecr | Remove-CMApplicationDeployment -Force

# Rename and move old google chrome version
Write-Output "Renaming and moving the old google chrome version"
$app = Get-CMApplication -Name $appnamecr
Set-CMApplication -InputObject $app -NewName "Google Chrome - $version"
Move-CMObject -FolderPath "ABC:\Application\Auto updates\Old versions" -InputObject $app

# Download new google chrome
Write-Output "Downloading new google chrome version"
(New-Object Net.WebClient).DownloadFile($URIchrome, $OutFile)

# Copy google chrome to application source directory
Write-Output "Downloaded version: $webversion"
Writelog "Downloaded version: $webversion"
$Filename = $((get-item $OutFile).name)
$destinationfolder = "$SCCMSource\$webversion"
Write-Output "Destination folder is $destinationfolder"
Writelog "Destination folder is $destinationfolder"

IF (!(test-path $destinationfolder)) {
    Writelog "$destinationfolder does not exist"
    [System.IO.Directory]::CreateDirectory($destinationfolder)
    Writelog "Creating $destinationfolder"
    [System.IO.File]::Move($OutFile,"$destinationfolder\$Filename")
    Writelog "Moving $OutFile to $destinationfolder"
    }

# Create application
Write-Output "Create application"
New-CMApplication -Name "$appnamecr" -Description "Chrome Web Browser" -AutoInstall $true
$cla1=new-CMDetectionClauseFile -FileName "chrome.exe" -PropertyType Version -ExpectedValue $webversion -ExpressionOperator GreaterEquals -Path "%ProgramFiles%\Google\Chrome\Application\" -Value
$cla2=new-CMDetectionClauseFile -FileName "new_chrome.exe" -PropertyType Version -ExpectedValue $webversion -ExpressionOperator GreaterEquals -Path "%ProgramFiles%\Google\Chrome\Application\" -Value
$logic1=$cla1.Setting.LogicalName
$logic2=$cla2.Setting.LogicalName
Add-CMMsiDeploymentType -ApplicationName "$appnamecr" -ContentLocation "$destinationfolder\$filename" -DeploymentTypeName "Google Chrome - $webversion" -InstallationBehaviorType InstallForSystem -InstallCommand 'msiexec /i "googlechromestandaloneenterprise64.msi" /qn reboot=reallysuppress' -UserInteractionMode Hidden
Set-CMMsiDeploymentType -ApplicationName $appnamecr -DeploymentTypeName "Google Chrome - $webversion" -AddDetectionClause $cla1,$cla2 -GroupDetectionClauses $logic1,$logic2 -DetectionClauseConnector @{LogicalName=$logic1;Connector="or"},@{LogicalName=$logic2;Connector="or"} -Force32BitDetectionScript $true
$app = Get-CMApplication -Name $appnamecr
Move-CMObject -FolderPath "ABC:\Application\Auto updates" -InputObject $app

# Add requirements
$myGC = Get-CMGlobalCondition -Name "Disk space"
$myRule = $myGC | New-CMRequirementRuleFreeDiskSpaceValue -PartitionOption System -RuleOperator GreaterEquals -Value1 1024
Set-CMMsiDeploymentType -ApplicationName $appnamecr -DeploymentTypeName "Google Chrome - $webversion" -AddRequirement $myRule

# Delete MSI detection method
Write-Output "Delete MSI detection method"
$SDMPackageXML = (Get-CMDeploymentType -ApplicationName $appnamecr -DeploymentTypeName "Google Chrome - $webversion").SDMPackageXML
[string[]]$OldDetections = (([regex]'(?<=SettingLogicalName=.)([^"]|\\")*').Matches($SDMPackageXML)).Value
Set-CMMsiDeploymentType -ApplicationName $appnamecr -DeploymentTypeName "Google Chrome - $webversion" -RemoveDetectionClause $OldDetections

# Distribute content
Write-Output "Distribute content"
Start-CMContentDistribution -ApplicationName $appnamecr -DistributionPointGroupName "All Distribution Points"
Set-CMApplication -ApplicationName $appnamecr -SoftwareVersion $webversion
New-CMApplicationDeployment -Name "$appnamecr" -AvailableDateTime '01/01/2020 00:00:00' -CollectionName "$collection" -DeadlineDateTime '01/01/2020 00:00:00' -DeployAction Install -DeployPurpose Required -UserNotification DisplaySoftwareCenterOnly -OverrideServiceWindow $true

# telegram push message
$message = "ℹ️ [SCCM] Обновление ПО`nGoogle Chrome $webversion"
telegram -message $message

}
}

# Output to console
Write-Output "Available Google Chrome Version in web - $webversion"
Write-Output "Deployed Google Chrome Version in SCCM - $version"

# Output to log file
Writelog "Available Google Chrome Version in web - $webversion"
Writelog "Deployed Google Chrome Version in SCCM - $version"
