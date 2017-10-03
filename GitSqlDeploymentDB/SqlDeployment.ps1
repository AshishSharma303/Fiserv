



$configfile = "C:\SqlDeployment\ConfigurationFile.ini"
$command = "C:\SQLServerFull\setup.exe /ConfigurationFile=$($configfile)"
Invoke-Expression -Command $command