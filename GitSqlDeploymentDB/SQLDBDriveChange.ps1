
function SQLDBDriveChange($ServerName)
{
	
	Try
	{
        write-host -ForegroundColor Green "*********** Entering method SQLDBDriveChange ******"
        
        $SQLQuery= "C:\gitSqlDeploymentDB\SqlDefaultLocationChange.sql"
        $result = invoke-sqlcmd -InputFile $SQLQuery -serverinstance $ServerName
        Write-host"result Output $($result)"
        $Services = get-service -ComputerName $serverName
            foreach ($SQLService in $Services | where-object {$_.Name -match "MSSQLSERVER" -or $_.Name -like "MSSQL$*"})
            {
            Write-Verbose "Restarting SQL Service.."
            Restart-Service $SQLService -Verbose
            }
        write-host -ForegroundColor Green "****** Exiting from method SQLDBDriveChange *****"
        
	}
	Catch [system.exception]
	{
		Write-Verbose $Error[0] $_.Exception
	}
	
}

SQLDBDriveChange -ServerName "fdw-a-SQLDB-01"

