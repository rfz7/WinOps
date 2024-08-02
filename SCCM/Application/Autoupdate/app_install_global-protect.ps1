# Global Protect Install
# https://jira.contoso.com/browse/ID-57504

# Variables
$Hostname = [System.Net.Dns]::GetHostByName($env:computerName).HostName
$GP_Path = "C:\Program Files\Palo Alto Networks\GlobalProtect\PanGPA.exe" # app location
$GP_ProductVersion = "6.2.2-259"
$PathToApp = Join-Path (Get-Location).path "GlobalProtect64.msi"
$PanGpd = "HKLM:\SYSTEM\CurrentControlSet\Services\PanGpd"
$PanGpd_Enum = "HKLM:\SYSTEM\CurrentControlSet\Services\PanGpd\Enum"
$PanGps = "HKLM:\SYSTEM\CurrentControlSet\Services\PanGps"
$PanSetup = "HKLM:\SOFTWARE\Palo Alto Networks\GlobalProtect\PanSetup"
$PrelogonKeyPath = "HKLM:\SOFTWARE\Palo Alto Networks\GlobalProtect\PanSetup"
$RegistryPaths = @($PanSetup, $PanGpd, $PanGpd_Enum, $PanGps) # fqdn
$LogFile = "$env:SystemDrive\GlobalProtect.log"

# Notification with timer
$wshell = New-Object -ComObject Wscript.Shell
$Output = $wshell.Popup("На твоём компьютере установлена устаревшая версия VPN-клиента GlobalProtect, что несёт в себе риски кибербезопасности (КБ). Необходимо выполнить обновление. Во время обновления может кратковременно пропасть доступ к корпоративным ресурсам. Нажмите ОК чтобы обновить. ",180,"Техническая поддержка Сбермаркет",0x1)
If ($Output -eq 1) {
    Write-Output "[CONTOSO] Выполняется установка новой версии программного обеспечения Palo Alto Global Protect VPN Client"
} else {
    Exit 1
    Break;
}

# File version info function
function Get-FileVersionInfo
{
[CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FileName)

    if(!(test-path $filename))
        {
            Write-Error "File not found"
        }

Write-Output ([System.Diagnostics.FileVersionInfo]::GetVersionInfo($FileName))
}


# Test-RegistryValue function
Function Test-RegistryValue {
    param(
        [Alias("PSPath")]
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [String]$Path
        ,
        [Parameter(Position = 1, Mandatory = $true)]
        [String]$Name
        ,
        [Switch]$PassThru
    )

    process {
        if (Test-Path $Path) {
            $Key = Get-Item -LiteralPath $Path
            if ($Key.GetValue($Name, $null) -ne $null) {
                if ($PassThru) {
                    Get-ItemProperty $Path $Name
                } else {
                    $true
                }
            } else {
                $false
            }
        } else {
            $false
        }
    }
}

# Check registry keys
foreach ($i in $RegistryPaths)
    {
        if(-not(Test-Path -Path $i))
        {
            New-Item -Path $i -Force
        }
    }

# Install app
if(-not(Test-path $GP_Path -PathType leaf))
    {
        # if file doesn't exist
        $Process = Start-Process $PathToApp -Argumentlist {ALLUSERS=1 /qn /norestart /l*v C:\GlobalProtect_msi.log PORTAL="ra-yc.contoso.com"} -Wait -Passthru
            if (($process.ExitCode -eq 0) -or ($process.ExitCode -eq 3010))
            {
                Write-Host "Exit 0"
            }
            else
            {
                Write-host "Part 1"
                Write-Host "Exit 1"
                Exit 1
            }

        if(Test-RegistryValue -Path $PrelogonKeyPath -Name "Prelogon")
            {
                Set-ItemProperty -Path $PrelogonKeyPath -Name "Prelogon" -Value "1" -Force
            }
        else
            {
                New-ItemProperty -Path $PrelogonKeyPath -Name "Prelogon" -Value "1" -PropertyType String -Force
            }
    }

else
    {
        # if file exist
        if((Get-FileVersionInfo -FileName $GP_Path).ProductVersion -ge $GP_ProductVersion)
            {
                Write-Host "Application already installed"
            }
        else
            {
                $Process = Start-Process $PathToApp -Argumentlist {ALLUSERS=1 /qn /norestart /l*v C:\GlobalProtect_msi.log PORTAL="ra-yc.contoso.com"} -Wait -Passthru
                if (($process.ExitCode -eq 0) -or ($process.ExitCode -eq 3010))
                {
                    Write-Host "Exit 0"
                }
                else
                {
                    Write-host "Part 2"
                    Write-Host "Exit 1"
                    Exit 1
                }
        }
        Write-Host "Application already installed"
    }

# Registry
$FailureActions_source = "ff,ff,ff,ff,00,00,00,00,00,00,00,00,01,00,00,00,14,00,00,00,01,00,00,00,60,ea,00,00"
$hexified = $FailureActions_source.Split(',') | % { "0x$_"}
$RegKeyBinaryValue = ([byte[]]$hexified)

$null = $RegKeys
$RegKeys = @(
    # Prelogon key
    # [pscustomobject]@{RegKeyPath=$PrelogonKeyPath ;RegKeyName='Prelogon';RegKeyValue='00000001';RegKeyType='String'},
    # PanGpd
    [pscustomobject]@{RegKeyPath=$PanGpd;RegKeyName='Type';RegKeyValue='00000001';RegKeyType='DWord'},
    [pscustomobject]@{RegKeyPath=$PanGpd;RegKeyName='Start';RegKeyValue='00000003';RegKeyType='DWord'},
    [pscustomobject]@{RegKeyPath=$PanGpd;RegKeyName='ErrorControl';RegKeyValue='00000001';RegKeyType='DWord'},
    [pscustomobject]@{RegKeyPath=$PanGpd;RegKeyName='Tag';RegKeyValue='00000013';RegKeyType='DWord'},
    [pscustomobject]@{RegKeyPath=$PanGpd;RegKeyName='NdisMajorVersion';RegKeyValue='00000006';RegKeyType='DWord'},
    [pscustomobject]@{RegKeyPath=$PanGpd;RegKeyName='NdisMinorVersion';RegKeyValue='30';RegKeyType='DWord'},
    [pscustomobject]@{RegKeyPath=$PanGpd;RegKeyName='DriverMajorVersion';RegKeyValue='00000006';RegKeyType='DWord'},
    [pscustomobject]@{RegKeyPath=$PanGpd;RegKeyName='DriverMinorVersion';RegKeyValue='00000000';RegKeyType='DWord'},
    [pscustomobject]@{RegKeyPath=$PanGpd;RegKeyName='ImagePath';RegKeyValue='\SystemRoot\system32\DRIVERS\pangpd.sys';RegKeyType='ExpandString'},
    [pscustomobject]@{RegKeyPath=$PanGpd;RegKeyName='DisplayName';RegKeyValue='@oem0.inf,%PanGpd.Service.DispName%;PanGP Virtual Miniport';RegKeyType='String'},
    [pscustomobject]@{RegKeyPath=$PanGpd;RegKeyName='Group';RegKeyValue='NDIS';RegKeyType='String'},
    [pscustomobject]@{RegKeyPath=$PanGpd;RegKeyName='Owners';RegKeyValue='oem0.inf';RegKeyType='MultiString'},
    [pscustomobject]@{RegKeyPath=$PanGpd_Enum;RegKeyName='Count';RegKeyValue='00000001';RegKeyType='DWord'},
    [pscustomobject]@{RegKeyPath=$PanGpd_Enum;RegKeyName='NextInstance';RegKeyValue='00000001';RegKeyType='DWord'},
    [pscustomobject]@{RegKeyPath=$PanGpd_Enum;RegKeyName='0';RegKeyValue='ROOT\PANGPD\0000';RegKeyType='String'},

    # PanGps
    [pscustomobject]@{RegKeyPath=$PanGps;RegKeyName='Type';RegKeyValue='00000016';RegKeyType='Dword'},
    [pscustomobject]@{RegKeyPath=$PanGps;RegKeyName='Start';RegKeyValue='00000002';RegKeyType='Dword'},
    [pscustomobject]@{RegKeyPath=$PanGps;RegKeyName='ErrorControl';RegKeyValue='00000001';RegKeyType='Dword'},
    [pscustomobject]@{RegKeyPath=$PanGps;RegKeyName='ImagePath';RegKeyValue='"C:\Program Files\Palo Alto Networks\GlobalProtect\PanGPS.exe"';RegKeyType='ExpandString'},
    [pscustomobject]@{RegKeyPath=$PanGps;RegKeyName='DisplayName';RegKeyValue='PanGPS';RegKeyType='String'},
    [pscustomobject]@{RegKeyPath=$PanGps;RegKeyName='ObjectName';RegKeyValue='LocalSystem';RegKeyType='String'},
    [pscustomobject]@{RegKeyPath=$PanGps;RegKeyName='Description';RegKeyValue='Palo Alto Networks GlobalProtect App for Windows';RegKeyType='String'},
    [pscustomobject]@{RegKeyPath=$PanGps;RegKeyName='FailureActions';RegKeyValue=$RegKeyBinaryValue;RegKeyType="Binary"}
    )

#
ForEach ($RegKey in $RegKeys)
{
    if(Test-RegistryValue -Path $RegKey.RegKeyPath  -Name $RegKey.RegKeyName )
        {
            Set-ItemProperty -Path $RegKey.RegKeyPath  -Name $RegKey.RegKeyName -Value $RegKey.RegKeyValue -Force
        }
    else
        {
            New-ItemProperty -Path $RegKey.RegKeyPath  -Name $RegKey.RegKeyName  -Value $RegKey.RegKeyValue -PropertyType $RegKey.RegKeyType -Force
            Add-Content -Path $LogFile -Value ("$(Get-Date) [$Hostname] Missed registry key: "+ $RegKey.RegKeyPath + "\" + $RegKey.RegKeyName) -Encoding UTF8
        }
}

Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\PanGps" -Name "Type" -Value "00000016" -Force