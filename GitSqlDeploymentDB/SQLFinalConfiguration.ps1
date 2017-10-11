function MainFunction()
{
  Param(
  
  [string]$ComputerName = $env:computername,
  [string]$UserName,
  [string]$Domain,
  [string]$SqlAdminRole,
  [string]$localUser = $env:USERNAME,
  [string]$SQLQuery = "C:\gitSqlDeploymentDB\SqlDefaultLocationChange.sql"
  
  )

    if (!(Test-Path "c:\gitSqlDeploymentDB"))
    {
        New-Item c:\gitSqlDeploymentDB -type directory
    }
    else
    {
        Write-Output "gitSqlDeploymentDB Directory is present."
    }

    Write-Output "Downloding Code from public repository ConfigurationFile.ini, SqlDeployment.ps1, SqlDefaultLocationChange.sql"
    function InvokeWebRequest()
    {
       Invoke-WebRequest -Uri "https://raw.githubusercontent.com/AshishSharma303/Fiserv/master/GitSqlDeploymentDB/ConfigurationFile.ini" -OutFile "C:\gitSqlDeploymentDB\ConfigurationFile.ini"
       Invoke-WebRequest -Uri "https://raw.githubusercontent.com/AshishSharma303/Fiserv/master/GitSqlDeploymentDB/SqlDeployment.ps1" -OutFile "C:\gitSqlDeploymentDB\SqlDeployment.ps1"
       Invoke-WebRequest -Uri "https://raw.githubusercontent.com/AshishSharma303/Fiserv/master/GitSqlDeploymentDB/SqlDefaultLocationChange.sql" -OutFile "C:\gitSqlDeploymentDB\SqlDefaultLocationChange.sql"
       $ValidateFileCopy = Test-Path("C:\gitSqlDeploymentDB\*.ini")
       return $ValidateFileCopy
    }
    InvokeWebRequest
    Write-Host -ForegroundColor Cyan "Information stored inside the valiateFileCopy Parameter : $($ValidateFileCopy)"
    if($ValidateFileCopy)
    {
        $configfile = "C:\gitSqlDeploymentDB\ConfigurationFile.ini"
        $command = "C:\SQLServerFull\setup.exe /ConfigurationFile=$($configfile)"
        Invoke-Expression -Command $command
    }
    else
    {
        Write-Output "Configuration.ini file failed to download on local machine."
    }

    $DomainAdmin = $Domain + "\" + $UserName
    AddOrSetLogin -ServerName $ComputerName -UserName $DomainAdmin -serviceAccount $SqlAdminRole -DBrole $SqlAdminRole

    SQLDBDriveChange -ServerName $ComputerName -SQLQuery $SQLQuery

} # main fucntion ends


function AddOrSetLogin($ServerName,$UserName,$serviceAccount,$DBrole)
{
	
	Try
	{
        write-host -ForegroundColor Green "*********** Entering method AddOrSetLogin ******"

        Write-Host "Connecting to database ..."
        [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')  | out-null
        # PSLogActivity $fileName "Connecting to database server $ServerName"
	    $cnstr = "Server="+$ServerName+";Database=master;Integrated Security=True;"
        $cn = New-Object System.Data.SqlClient.SqlConnection
	    $cn.ConnectionString = $cnstr
	    $cn.Open()
	    $cmd = new-object System.Data.SqlClient.SqlCommand
	    $cmd.Connection = $cn

        
            try
            {
                #$UserName = "fdwdsc\azureadmin"
                #$ServiceAccount = "sysadmin"
                #$ServiceAccount = $ServiceAccount.ToUpper()
                if( ($ServiceAccount -ne "") )
                {
                    write-host "Creating login $($UserName)"
                    #PSLogActivity $fileName "Creating login $UserName "
                    $queryForExists = "SELECT Name FROM master..syslogins where NAME = '"+$UserName+"'"
                    $result = invoke-sqlcmd -serverinstance $ServerName -query $queryForExists -database "master"
                    if($result)
                    {
                        write-host "Login $UserName is already exists."
                        #PSLogActivity $fileName "Login $UserName is already exists."
                    }
                    else
                    {
                        $cmdText = "CREATE LOGIN [$UserName] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english];" 
	                    $cmd.CommandText = $cmdText
	                    $resultout = $cmd.ExecuteNonQuery()
                        #PSLogActivity $fileName "Login $UserName is added."
                    }

                    # $DBRoles = $ServiceAccount.DBRole.Split(",")
                    # $DBRole = "SYSADMIN"
                    if( $DBRole -ne "PUBLIC") #Public role membership can not be changed.
                    {
                        write-host "Adding role [$DBRole] for $UserName"
                        # PSLogActivity $fileName "Adding role [$DBRole] for $UserName"
                        $cmdText = "ALTER SERVER ROLE [$DBRole] ADD MEMBER [$UserName];" 
	                    $cmd.CommandText = $cmdText
	                    $resultout = $cmd.ExecuteNonQuery()
                    }
                    
                }
            }
            catch
            {
                Write-host -ForegroundColor Red $Error[0] $_.Exception
                # PSLogActivity $fileName "Failed to AddOrSetLogin for $UserName"
            }
        
	    $cn.Close()
        write-host -ForegroundColor Green "****** Exiting from method AddOrSetLogin *****"
        # PSLogActivity $fileName "AddOrSetLogin is completed."
	}
	Catch [system.exception]
	{
		Write-host -ForegroundColor Red $Error[0] $_.Exception
	}
	
}

#AddOrSetLogin -ServerName "fdw-a-SQLDB-01"


function SQLDBDriveChange($ServerName, $SQLQuery)
{
	
	Try
	{
        write-host -ForegroundColor Green "*********** Entering method SQLDBDriveChange ******"
        $SQLQuery= "C:\gitSqlDeploymentDB\SqlDefaultLocationChange.sql"
        Write-Host "Executing SQL code from local directory, C:\gitSqlDeploymentDB\"
        $result = invoke-sqlcmd -InputFile $SQLQuery -serverinstance $ServerName
        $Services = get-service -ComputerName $serverName
            foreach ($SQLService in $Services | where-object {$_.Name -match "MSSQLSERVER" -or $_.Name -like "MSSQL$*"})
            {
            Write-Host -ForegroundColor Cyan "Restarting SQL Service.."
            Restart-Service $SQLService -Verbose
            }
        write-host -ForegroundColor Green "****** Exiting from method SQLDBDriveChange *****"
        
	}
	Catch [system.exception]
	{
		Write-host -ForegroundColor Red $Error[0] $_.Exception
	}
	
}

#SQLDBDriveChange -ServerName "fdw-a-SQLDB-01"


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
}


Write-host -ForegroundColor Green "*********** Script Starts... Executing Main Function *****"
MainFunction -ComputerName "fdw-a-SQLDB-01" -UserName "azureadmin" -Domain "fdwdsc" -SqlAdminRole "SYSADMIN"

Write-host -ForegroundColor Green "*********** Entering method Add-FireWallRules & enable File and print Service *****"
netsh firewall set service type = fileandprint mode = enable 
netsh advfirewall firewall add rule name="SQL Server Analysis Services inbound on TCP 2383" dir=in action=allow protocol=TCP localport=2383 profile=domain
Add-FirewallRule "SQL Server" "1433" $null $null
Add-FirewallRule "SQL SSAS" "5022" $null $null
Add-FirewallRule "SQL Listener" "59999" $null $null





