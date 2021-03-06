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
    #Enable CredSSP
    Enable-WSManCredSSP -Role server -Force
    Enable-WSManCredSSP -Role Client -DelegateComputer * -Force
    $allowed = @('WSMAN/*.*')
    $key = 'hklm:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation'
        if (!(Test-Path $key)) {
            md $key
        }
    New-ItemProperty -Path $key -Name AllowFreshCredentials -Value 1 -PropertyType Dword -Force            
    $key = Join-Path $key 'AllowFreshCredentials'
        if (!(Test-Path $key)) {
            md $key
        }
    $i = 1
    $allowed |% {
        # Script does not take into account existing entries in this key
        New-ItemProperty -Path $key -Name $i -Value $_ -PropertyType String -Force -Verbose
        $i++
    }
    #Enable PS Remoting
    winrm set winrm/config/client/auth '@{Basic="true"}'
    winrm set winrm/config/service/auth '@{Basic="true"}'
    winrm set winrm/config/service '@{AllowUnencrypted="true"}'
    winrm set winrm/config/client '@{AllowUnencrypted="true"}'
    Set-Item wsman:\localhost\client\trustedhosts *.* -Force -Verbose
    Restart-Service WinRM -Verbose
    sleep 5

    ########################################################################################
    # PowerShell Script to Install features, services, login and DB's #
    ########################################################################################

    $s = New-PSSession -ComputerName "$BrokerServer.$DomainFQDN" -Credential $cred -Authentication Credssp
    Invoke-Command -ComputerName $env:computername  -Credential $credential -ScriptBlock {
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
    } -ArgumentList $ComputerName, $UserName, $Domain, $SqlAdminRole, $Password
    Remove-PSSession $s
    
}
else
{
    Write-Host " PS remote Script did not work, as could not found the C:\gitSqlDeploymentDB\SQLFinalConfiguration.ps1 at its location"
}
