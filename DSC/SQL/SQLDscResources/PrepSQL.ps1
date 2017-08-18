
configuration PrepSQL
{
    param
    (
        
        [String]$DomainName,

        [System.Management.Automation.PSCredential]$Admincreds,

        [System.Management.Automation.PSCredential]$SQLServicecreds,

        #[String]$Username = "azureamdin",
        #[String]$Password = "Password@12345",


        [UInt32]$DatabaseEnginePort = 1433,
        
        [UInt32]$DatabaseMirrorPort = 5022,

        [UInt32]$NumberOfDisks = 1,
	[UInt32]$NumberOfLogDisks = 1,
	[String]$WorkloadType = "OLTP",

        [String]$DomainNetbiosName=(Get-NetBIOSName -DomainName $DomainName),

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    )

    Import-DscResource -ModuleName xComputerManagement,CDisk,xActiveDirectory,XDisk,xSql, xSQLServer, xSQLps,xNetworking
    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($Admincreds.UserName)", $Admincreds.Password)
    [System.Management.Automation.PSCredential]$DomainFQDNCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
    [System.Management.Automation.PSCredential]$SQLCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SQLServicecreds.UserName)", $SQLServicecreds.Password)

    #[System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($Username)", $Password)
    #[System.Management.Automation.PSCredential]$DomainFQDNCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Username)", $Password)
    #[System.Management.Automation.PSCredential]$SQLCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($Username)", $Password)

Write-Host $($DomainName)
    $RebootVirtualMachine = $false

    if ($DomainName)
    {
        $RebootVirtualMachine = $true
    }

      
   WaitForSqlSetup

   Node locahost
   {
        WindowsFeature ADPS
        {
            Name = "RSAT-AD-PowerShell"
            Ensure = "Present"
        }

        xWaitForADDomain DscForestWait 
        { 
            DomainName = $DomainName 
            DomainUserCredential= $DomainCreds
            RetryCount = $RetryCount 
            RetryIntervalSec = $RetryIntervalSec 
	        DependsOn = "[WindowsFeature]ADPS"
        }
        
        xComputer DomainJoin
        {
            Name = $env:COMPUTERNAME
            DomainName = $DomainName
            Credential = $DomainCreds
	        DependsOn = "[xWaitForADDomain]DscForestWait"
        }
        xFirewall DatabaseEngineFirewallRule
        {
            Direction = "Inbound"
            Name = "SQL-Server-Database-Engine-TCP-In"
            DisplayName = "SQL Server Database Engine (TCP-In)"
            Description = "Inbound rule for SQL Server to allow TCP traffic for the Database Engine."
            DisplayGroup = "SQL Server"
            State = "Enabled"
            Access = "Allow"
            Protocol = "TCP"
            LocalPort = $DatabaseEnginePort -as [String]
            Ensure = "Present"
            DependsOn = "[xComputer]DomainJoin"
        }
        xSqlLogin AddDomainAdminAccountToSysadminServerRole
        {
            Name = $DomainCreds.UserName
            LoginType = "WindowsUser"
            ServerRoles = "sysadmin"
            Enabled = $true
            Credential = $Admincreds
            DependsOn = "[xComputer]DomainJoin"
   
        }
        xADUser CreateSqlServerServiceAccount
        {
            DomainAdministratorCredential = $DomainCreds
            DomainName = $DomainName
            UserName = $SQLServicecreds.UserName
            Password = $SQLServicecreds
            Ensure = "Present"
            DependsOn = "[xSqlLogin]AddDomainAdminAccountToSysadminServerRole"
        }
        xSqlLogin AddSqlServerServiceAccountToSysadminServerRole
        {
            Name = $SQLCreds.UserName
            LoginType = "WindowsUser"
            ServerRoles = "sysadmin"
            Enabled = $true
            Credential = $Admincreds
            DependsOn = "[xADUser]CreateSqlServerServiceAccount"
        }
        
        
        
        LocalConfigurationManager 
        {
            RebootNodeIfNeeded = $true
        }
   
   
   
   
   } #End of Node.




} #End of Configuration function

function Get-NetBIOSName
{ 
    [OutputType([string])]
    param(
        [string]$DomainName
    )

    if ($DomainName.Contains('.')) {
        $length=$DomainName.IndexOf('.')
        if ( $length -ge 16) {
            $length=15
        }
        return $DomainName.Substring(0,$length)
    }
    else {
        if ($DomainName.Length -gt 15) {
            return $DomainName.Substring(0,15)
        }
        else {
            return $DomainName
        }
    }
}#end of get-netBiosName

function WaitForSqlSetup
{
    # Wait for SQL Server Setup to finish before proceeding.
    while ($true)
    {
        try
        {
            Get-ScheduledTaskInfo "\ConfigureSqlImageTasks\RunConfigureImage" -ErrorAction Stop
            Start-Sleep -Seconds 5
        }
        catch
        {
            break
        }
    }
}#end of WaitForSQLSetup

<#

$cd = @{    AllNodes = @(        @{            NodeName = 'localhost'            PSDscAllowPlainTextPassword = $true        }    )}

#$Admincreds = Get-Credential -UserName azureadmin -Message "Password please"#$SQLServicecreds = $Admincreds;#PrepSQL -Admincreds $Admincreds -ConfigurationData $cd
PrepSQL -ConfigurationData $cd
#>