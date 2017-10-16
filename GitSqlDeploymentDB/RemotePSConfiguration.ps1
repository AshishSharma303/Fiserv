param 
    ( 
    [string]$ComputerName = $env:computername,
    [string]$UserName,
    [string]$Domain,
    $Password,
    [string]$SqlAdminRole
    )

#$password =  ConvertTo-SecureString $Password -AsPlainText -Force
#$credential = New-Object System.Management.Automation.PSCredential("$env:COMPUTERNAME\$($UserName)", $password)

function InvokeWebRequest()
    {
       Write-host -ForegroundColor Green "Executing InvokeWebRequest Function : Downloding Code from public repository ConfigurationFile.ini, SqlDeployment.ps1, SqlDefaultLocationChange.sql, SQLFinalConfiguration.ps1"
       Invoke-WebRequest -Uri "https://raw.githubusercontent.com/AshishSharma303/Fiserv/master/GitSqlDeploymentDB/ConfigurationFile.ini" -OutFile "C:\gitSqlDeploymentDB\ConfigurationFile.ini" -Verbose
       Invoke-WebRequest -Uri "https://raw.githubusercontent.com/AshishSharma303/Fiserv/master/GitSqlDeploymentDB/SqlDeployment.ps1" -OutFile "C:\gitSqlDeploymentDB\SqlDeployment.ps1" -Verbose
       Invoke-WebRequest -Uri "https://raw.githubusercontent.com/AshishSharma303/Fiserv/master/GitSqlDeploymentDB/SqlDefaultLocationChange.sql" -OutFile "C:\gitSqlDeploymentDB\SqlDefaultLocationChange.sql" -Verbose
       Invoke-WebRequest -Uri "https://raw.githubusercontent.com/AshishSharma303/Fiserv/master/GitSqlDeploymentDB/SQLFinalConfiguration.ps1" -OutFile "C:\gitSqlDeploymentDB\SQLFinalConfiguration.ps1" -Verbose
       Invoke-WebRequest -Uri "https://github.com/AshishSharma303/Fiserv/blob/master/GitSqlDeploymentDB/RemotePSConfiguration.ps1" -OutFile "C:\gitSqlDeploymentDB\RemotePSConfiguration.ps1" -Verbose
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
    $Password =  ConvertTo-SecureString $Password -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential("$env:COMPUTERNAME\$($UserName)", $Password)
    #$credential = New-Object System.Management.Automation.PSCredential -ArgumentList @($UserName,(ConvertTo-SecureString -String $Password -AsPlainText -Force))
    # $command = $file = $PSScriptRoot + "\SQLFinalConfiguration.ps1"
    $command = "C:\gitSqlDeploymentDB\SQLFinalConfiguration.ps1"
    Enable-PSRemoting –force -Verbose
    Invoke-Command -FilePath $command -Credential $credential -ComputerName $env:COMPUTERNAME  -UserName $UserName -Domain $Domain  -SqlAdminRole $SqlAdminRole -Verbose
    # Disable-PSRemoting -Force -Verbose
}
else
{
    Write-Host " PS remote Script did not work, as could not found the C:\gitSqlDeploymentDB\SQLFinalConfiguration.ps1 at its location"
}
