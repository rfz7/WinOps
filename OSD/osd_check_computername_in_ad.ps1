# Import Active Directory module
Import-Module -Name ActiveDirectory

# Set variables
$UserName = "contoso\user"
$PlainPassword = "password"
$SecurePassword = $PlainPassword | ConvertTo-SecureString -AsPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $SecurePassword
$DomainController = "dc.contoso.com"
$LogFile = "X:\Windows\temp\remove-adcomputer.log"

# Start logging
Start-Transcript -Path $LogFile

# Get computer name from task sequince variable
$deviceName = $null
$TSEnv = New-Object -COMObject Microsoft.SMS.TSEnvironment
$compName = $TSEnv.Value("OSDComputerName")
$deviceName = Get-ADComputer -Identity $compName -Server $DomainController -Credential $Credentials

# Try to remove computer account in Active Directory
if ($deviceName) {
    try {
        Remove-ADComputer -Identity $compName -Confirm:$false -Server $DomainController -Credential $Credentials
            if ($?) {
                Stop-Transcript
                Exit 0
            }
            else {
                Stop-Transcript
                Write-Host "ERROR! Failed to delete computer account" | Out-File $LogFile -Append -Encoding utf8
                Exit 1
            }
        }
        catch { }
}
else
        {
        Exit 0
        }

Stop-Transcript