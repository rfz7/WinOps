### 2019 

# Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Import SCCM Powershell Module
Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" # Import the ConfigurationManager.psd1 module 
Set-Location "000:" # Set the current location to be the site code.

# Set variarbles
$SiteServer = "SCCM-Site01.contoso.com"
$SiteName = "000"
$Description = "SCCM Site Server"
$path2xml = "C:\temp\Maxpatrol\XML\2020\06 June\CVE-SRV-06-2020-2.xml"
#$SoftwareUpdateSource = "\\SCCM-Site01.contoso.com\Content_Source\Updates\CVE"
$DistributionGroup="All Distribution Points"
$CollectionName = "All | MS Updates testing" 
$DeploymentPackageName = "(CVE) Security Updates 2020"
$Date = [DateTime]::Now.ToString("yyyy-MM");


# Connect to SCCM Site Server
New-PSDrive -Name $SiteName -PSProvider "AdminUI.PS.Provider\CMSite" -Root $SiteServer -Description $Description
CD "$($SiteName):"

# Import XML file
(Get-Content $path2xml).Replace("<html:", "<html_").Replace("</html:", "</html_") | Out-File $path2xml
#
[xml]$f = gc $path2xml -Encoding utf8
$kbs = @()
$f.workbook.Worksheet.Table.row | % {
$list = @()
    if($_.cell[12].innertext)
{
        if($_.cell[12].innertext.contains(" "))
    {
$list = $_.cell[12].innertext.replace(" ","").split(",")
    } else {
$list = $_.cell[12].innertext
            }
}
$kbs += $list
}
cls
$kbs = $kbs | select -Unique | %{if($_ -like "KB*"){$_}}
$kbs | %{$_.substring(2,7)}

# Update data of update catalog
$UpdateCatalog = Get-CMSoftwareUpdate -Fast

# Set filter for no superseded, no preview, no expired and no Itanium\ia64\ARM64
$kbs2 = $UpdateCatalog | Where-Object -FilterScript {$_.IsDeployed -eq $false -and $_.LocalizedDisplayName.Contains("Preview") -eq $false -and $_.IsExpired -eq $false -and $_.IsSuperseded -eq $false -and $_.LocalizedDisplayName -notlike "*itanium*" -and $_.LocalizedDisplayName -notlike "*ia64*" -and $_.LocalizedDisplayName -notlike "*ARM64*"}

# $UpdateIDs = $kbs2.ArticleId 
# $UpdateIDs = $kbs2.CI_ID 

$kbs3 = @()
foreach ($rec in $kbs2)
{
    if ($kbs.Contains("KB$($rec.ArticleId)"))
    {
        $kbs3 += $rec.CI_ID
    }
}

# Create new software update group (SUG))
New-CMSoftwareUpdateGroup -Name "Maxpatrol (CVE) Security Updates $Date" -UpdateId $kbs3

# Save SUG to Deployment Package
Set-CMSoftwareUpdateDeploymentPackage -Name "$DeploymentPackageName"
Save-CMSoftwareUpdate -SoftwareUpdateGroupName "(Maxpatrol) CVE Security Updates $Date" -DeploymentPackageName "(Maxpatrol) CVE Security Updates 2020"

# Deploy deployment package to distribution point group
Start-CMContentDistribution -DeploymentPackageName "(Maxpatrol) CVE Security Updates $Date"-DistributionPointGroupName "$DistributionGroup"

# Create deployment
Start-CMSoftwareUpdateDeployment -AcceptEula -AllowRestart $false -AllowUseMeteredNetwork $true `
 -CollectionName $CollectionName -DeploymentAvailableTime ([DateTime]::Now.AddDays(1)) `
  -DeploymentName "(CVE) Security Updates $Date - $CollectionName" -DeploymentType Required -Description "(CVE) Automatic updates" `
   -DownloadFromMicrosoftUpdate $false ` -EnforcementDeadline ([DateTime]::Now.AddDays(8)) `
    -ProtectedType RemoteDistributionPoint -RestartServer $true -RestartWorkstation $true -SoftwareInstallation $true `
     -SoftwareUpdateGroupName "(CVE) Security Updates $Date" -TimeBasedOn LocalTime -UnprotectedType NoInstall -UseBranchCache $true `
      -UserNotification DisplaySoftwareCenterOnly
