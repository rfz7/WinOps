# Jira token
$Token = "YOUR TOKEN HERE"
$JiraServer = "jira.consto.com"

# Get device serial number
$SerialNumber = (Get-CimInstance -class "Win32_Bios").SerialNumber
# Check serial number
if (($SerialNumber -eq $null) -or ($SerialNumber.Contains(" ")) -or ($SerialNumber.Length -lt 5)) { Exit 1 }

# API URL
$Uri = "https://$JiraServer/rest/insight/1.0/iql/objects?iql=Serial%20like%20$SerialNumber&includeAttributes=false"

# Azutorization
$Get = Invoke-RestMethod -Headers @{ 'Authorization' = 'Bearer ' + $Token } -Method 'GET' -Uri $Uri

# Get device type
$DeviceType = $Get.objectEntries.objectType.name

# Get device asset name
$ObjectKey = $Get.objectEntries.objectKey
# Сheck the number of elements returned
if ($ObjectKey.Contains(" ")) { Exit 1 }

# Set device name prefix
if ($DeviceType -eq "Laptops")
    {
        $OSDComputerName = "NB-"+ $ObjectKey
    }
    else
    {
        $OSDComputerName = "PC-"+ $ObjectKey
    }

# Set task sequence variable OSDComputerName
$TSenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
$TSenv.Value("OSDComputerName") = "$OSDComputerName"
