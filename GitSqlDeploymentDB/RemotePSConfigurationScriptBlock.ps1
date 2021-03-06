﻿param 
    ( 
    [string]$ComputerName = $env:computername,
    [string]$UserName,
    [string]$Domain,
    $Password,
    [string]$SqlAdminRole
    )

function InvokeWebRequest()
    {
       Write-host -ForegroundColor Green "Executing InvokeWebRequest Function : Downloding Code from public repository ConfigurationFile.ini, SqlDeployment.ps1, SqlDefaultLocationChange.sql, SQLFinalConfiguration.ps1"
       Invoke-WebRequest -Uri "https://raw.githubusercontent.com/AshishSharma303/Fiserv/master/GitSqlDeploymentDB/ConfigurationFile.ini" -OutFile "C:\gitSqlDeploymentDB\ConfigurationFile.ini" -Verbose
       Invoke-WebRequest -Uri "https://raw.githubusercontent.com/AshishSharma303/Fiserv/master/GitSqlDeploymentDB/SqlDeployment.ps1" -OutFile "C:\gitSqlDeploymentDB\SqlDeployment.ps1" -Verbose
       Invoke-WebRequest -Uri "https://raw.githubusercontent.com/AshishSharma303/Fiserv/master/GitSqlDeploymentDB/SqlDefaultLocationChange.sql" -OutFile "C:\gitSqlDeploymentDB\SqlDefaultLocationChange.sql" -Verbose
       Invoke-WebRequest -Uri "https://raw.githubusercontent.com/AshishSharma303/Fiserv/master/GitSqlDeploymentDB/SQLFinalConfiguration.ps1" -OutFile "C:\gitSqlDeploymentDB\SQLFinalConfiguration.ps1" -Verbose
       Invoke-WebRequest -Uri "https://github.com/AshishSharma303/Fiserv/blob/master/GitSqlDeploymentDB/RemotePSConfigurationScriptBlock.ps1" -OutFile "C:\gitSqlDeploymentDB\RemotePSConfigurationScriptBlock.ps1" -Verbose
    } # end of InvokeFunction


    if (!(Test-Path "c:\gitSqlDeploymentDB"))
    {
        Start-Transcript -Path C:\gitSqlDeploymentDB\PsRemotetranScript.txt -NoClobber -Verbose
        New-Item c:\gitSqlDeploymentDB -type directory -Verbose
        InvokeWebRequest
    }
    else
    {
        Start-Transcript -Path C:\gitSqlDeploymentDB\PsRemotetranScript.txt -NoClobber -Verbose
        Write-Output "gitSqlDeploymentDB Directory is present."
        InvokeWebRequest
    }

if (Test-Path("C:\gitSqlDeploymentDB\SQLFinalConfiguration.ps1"))
{
    $UserName = $UserName.ToUpper()
    $SqlAdminRole = $SqlAdminRole.ToUpper()
    $Password =  ConvertTo-SecureString $Password -AsPlainText -Force
    $FullUserName = $ComputerName + "\" + $Username
    $credential = New-Object System.Management.Automation.PSCredential($FullUserName, $Password)
    $command = "C:\gitSqlDeploymentDB\SQLFinalConfiguration.ps1"
    Enable-PSRemoting –force -Verbose




########################################
########## Disk related configurations##########
########################################
    $pso = New-PSSessionOption -OperationTimeout 7200000 -MaximumRedirection 100 -OutputBufferingMode Drop  -Verbose
    Invoke-Command -ComputerName $ComputerName -Credential $credential -ScriptBlock {
    Param($ComputerName,$UserName)
    Function Get_Poolable_Disk
    {
        $PhysicalDisks = Get-StorageSubSystem | Get-PhysicalDisk -CanPool $True -Verbose
        Return $PhysicalDisks
    }

    Function Get_Total_Size_For_Pool
    {
        $TotalSize = ((Get-PhysicalDisk -CanPool $True).Size) -join '+' | Invoke-Expression -Verbose
        Return $TotalSize
    }

    Function Get_Total_Number_of_Disk
    {
		$PoolNumber = 0
        $a=Get-PhysicalDisk | where { $_.CanPool -eq $true } -Verbose
		if ( $a )
		{
			$PoolNumber = $a.Count 
		}
		Return $poolNumber
    }
    $PhysicalDisks = Get_Poolable_Disk
    Write-Host "Details of the raw Disks found : $($PhysicalDisks)"
    if ($PhysicalDisks)
    {
        write-host -ForegroundColor Green "working on Initialize-Disk, Creating New-Partition and Format-Volume  for the Raw Disks"
        Get-Disk | where partitionstyle -EQ "raw" | Initialize-Disk -PartitionStyle MBR -PassThru |  New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "disk2" -Confirm:$false
    }

    } -ArgumentList $ComputerName, $UserName -SessionOption $pso  -Verbose
########################################
########## Disk related configurations Ends #####
########################################





########################################
######## Firewall and baisc rules setup#########
########################################
    $pso = New-PSSessionOption -OperationTimeout 7200000 -MaximumRedirection 100 -OutputBufferingMode Drop  -Verbose
    Invoke-Command -ComputerName $ComputerName -Credential $credential -ScriptBlock {
    Param($ComputerName,$UserName,$Domain,$SqlAdminRole,$Password)
    function Disable-InternetExplorerESC {
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
	
	<#
	if ( Get-Process -Name Explorer )
	{
	    Stop-Process -Name Explorer
	}
	Write-Host "IE Enhanced Security Configuration (ESC) has been disabled." -ForegroundColor Green
	#>
    Write-Host "IE Enhanced Security Configuration (ESC) has been disabled."
} # End Disable-IE setting
    Write-host -ForegroundColor Green "*********** Disable Internet explorer settings*****"
    Disable-InternetExplorerESC
    function Add-FirewallRule {
       param( 
          $name,
          $tcpPorts,
          $appName = $null,
          $serviceName = $null
       )
        $fw = New-Object -ComObject hnetcfg.fwpolicy2 
        $rule = New-Object -ComObject HNetCfg.FWRule
        $rule.Name = $name
        if ($appName -ne $null) { $rule.ApplicationName = $appName }
        if ($serviceName -ne $null) { $rule.serviceName = $serviceName }
        $rule.Protocol = 6 #NET_FW_IP_PROTOCOL_TCP
        $rule.LocalPorts = $tcpPorts
        $rule.Enabled = $true
        $rule.Grouping = "@firewallapi.dll,-23255"
        $rule.Profiles = 7 # all
        $rule.Action = 1 # NET_FW_ACTION_ALLOW
        $rule.EdgeTraversal = $false
        $fw.Rules.Add($rule)
    } # End of add-FirewallRule
    Write-host -ForegroundColor Green "*********** Entering method Add-FireWallRules & enable File and print Service *****"
    netsh firewall set service type = fileandprint mode = enable
    netsh advfirewall firewall add rule name="SQL Server Analysis Services inbound on TCP 2383" dir=in action=allow protocol=TCP localport=2383 profile=domain
    Add-FirewallRule "SQL Server" "1433" $null $null
    Add-FirewallRule "SQL SSAS" "5022" $null $null
    Add-FirewallRule "SQL Listener" "59999" $null $null
    } -ArgumentList $ComputerName, $UserName, $Domain, $SqlAdminRole, $Password -SessionOption $pso  -Verbose
########################################
######## Firewall and baisc rules setups Ends #####
########################################




########################################
######## SQL update Code setup Login#########
########################################
$pso = New-PSSessionOption -OperationTimeout 7200000 -MaximumRedirection 100 -OutputBufferingMode Drop  -Verbose
    Invoke-Command -ComputerName $ComputerName -Credential $credential -ScriptBlock {
    Param($ComputerName,$UserName,$Domain,$SqlAdminRole,$Password)
    Try
	{
        $DomainUser = $Domain + "\" + $UserName
        write-host -ForegroundColor Green "*********** Entering method AddOrSetLogin ******"
        Write-Host "Connecting to database ..."
        [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')  | out-null
	    $cnstr = "Server="+$ServerName+";Database=master;Integrated Security=True;"
        $cn = New-Object System.Data.SqlClient.SqlConnection
	    $cn.ConnectionString = $cnstr
	    $cn.Open()
	    $cmd = new-object System.Data.SqlClient.SqlCommand
	    $cmd.Connection = $cn
            try
            {
                $ServiceAccount = "SYSADMIN"
                if( ($ServiceAccount -ne "") )
                {
                    write-host "Creating login $($DomainUser)"
                    $queryForExists = "SELECT Name FROM master..syslogins where NAME = '"+$DomainUser+"'"
                    $result = invoke-sqlcmd -serverinstance $ComputerName -query $queryForExists -database "master"
                    if($result)
                    {
                        write-host "Login $DomainUser is already exists."
                    }
                    else
                    {
                        $cmdText = "CREATE LOGIN [$DomainUser] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english];" 
	                    $cmd.CommandText = $cmdText
	                    $resultout = $cmd.ExecuteNonQuery()
                     }
                    $DBRole = "SYSADMIN"
                    if( $DBRole -ne "PUBLIC") #Public role membership can not be changed.
                    {
                        write-host "Adding role [$SqlAdminRole] for $DomainUser"
                        $cmdText = "ALTER SERVER ROLE [$SqlAdminRole] ADD MEMBER [$DomainUser];" 
	                    $cmd.CommandText = $cmdText
	                    $resultout = $cmd.ExecuteNonQuery()
                    }
                }
            }
            catch
            {
                Write-host -ForegroundColor Red $Error[0] $_.Exception
            }
	    $cn.Close()
        write-host -ForegroundColor Green "****** Exiting from method AddOrSetLogin *****"
        Write-Host ""
	}
	Catch [system.exception]
	{
		Write-host -ForegroundColor Red $Error[0] $_.Exception
	}
    


    } -ArgumentList $ComputerName, $UserName, $Domain, $SqlAdminRole, $Password -SessionOption $pso  -Verbose
########################################
######## SQL update Code setup Login Ends #####
########################################



########################################
######## SQL Drive Change Code #############
########################################
    $pso = New-PSSessionOption -OperationTimeout 7200000 -MaximumRedirection 100 -OutputBufferingMode Drop  -Verbose
    Invoke-Command -ComputerName $ComputerName -Credential $credential -ScriptBlock {
    Param($ComputerName,$UserName,$Domain,$SqlAdminRole,$Password)
        Try
	{
        if (!(Test-Path "F:\MSSQL01\Data"))
        {
            New-Item F:\MSSQL01 -type directory -Verbose
            New-Item F:\MSSQL01\Data -type directory -Verbose
            New-Item F:\MSSQL01\Log -type directory -Verbose
            New-Item F:\MSSQL01\Backups -type directory -Verbose
            Write-Host -ForegroundColor Green " Created directory for MSSQL Data, Log and backups"
        }
        else
        {
            Write-Host -ForegroundColor Green "F:\MSSQL01 Directory is already present."
        }
        write-host -ForegroundColor Green "*********** Entering method SQLDBDriveChange ******"
        $SQLQuery= "C:\gitSqlDeploymentDB\SqlDefaultLocationChange.sql"
        Write-Host "Executing SQL code from local directory, C:\gitSqlDeploymentDB\\SqlDefaultLocationChange.sql"
        $localUserName = $ComputerName + "\" + $UserName
        $result = invoke-sqlcmd -InputFile $SQLQuery -serverinstance $ComputerName -Verbose
        $Services = get-service -ComputerName $ComputerName
            foreach ($SQLService in $Services | where-object {$_.Name -match "MSSQLSERVER" -or $_.Name -like "MSSQL$*"})
            {
            Write-Host -ForegroundColor Cyan "Restarting SQL Service.."
            Restart-Service $SQLService -Verbose
            }
        write-host -ForegroundColor Green "****** Exiting from method SQLDBDriveChange *****"
        Write-Host ""
        
	}
	Catch [system.exception]
	{
		Write-host -ForegroundColor Red $Error[0] $_.Exception
	}
    
    } -ArgumentList $ComputerName, $UserName, $Domain, $SqlAdminRole, $Password -SessionOption $pso  -Verbose
########################################
######## SQL Drive Change Code Ends #########
########################################




########################################
### SQL features amendmends though INI Code ###
########################################
    $pso = New-PSSessionOption -OperationTimeout 7200000 -MaximumRedirection 100 -OutputBufferingMode Drop  -Verbose
    Invoke-Command -ComputerName $ComputerName -Credential $credential -ScriptBlock {
    Param($ComputerName,$UserName,$Domain,$SqlAdminRole,$Password)
    $ValidateInvokeRequest = Test-Path("C:\gitSqlDeploymentDB\*.ini")
    Write-Host -ForegroundColor Cyan "ValidateInvokeRequest Parameter value : $($ValidateInvokeRequest)"
    if($ValidateInvokeRequest)
    {
        Write-Host -ForegroundColor Green "Found the configuration file and executing the sql Setup.."
        $configfile = "C:\gitSqlDeploymentDB\ConfigurationFile.ini"
        $command = "C:\SQLServerFull\setup.exe /ConfigurationFile=$($configfile)"
        Invoke-Expression -Command $command -Verbose
        Write-host -ForegroundColor Yellow "configuration done though INI file and its the time to restart the VM...."
        Restart-Computer $env:computername -Force -Verbose
    }
    else
    {
        Write-Output "Configuration.ini file failed to download on local machine."
    }

    } -ArgumentList $ComputerName, $UserName, $Domain, $SqlAdminRole, $Password -SessionOption $pso  -Verbose
########################################
### SQL features amendmends though INI Code ###
########################################

}
else
{
    Write-Host " PS remote Script did not work, as could not found the C:\gitSqlDeploymentDB\SQLFinalConfiguration.ps1 at its location"
}
