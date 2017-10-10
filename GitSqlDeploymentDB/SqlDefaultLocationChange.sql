
USE [master]
GO
 
EXEC   xp_instance_regwrite
       N'HKEY_LOCAL_MACHINE',
       N'Software\Microsoft\MSSQLServer\MSSQLServer',
       N'DefaultData',
       REG_SZ,
       N'C:\MSSQL01\Data'
GO

EXEC   xp_instance_regwrite
       N'HKEY_LOCAL_MACHINE',
       N'Software\Microsoft\MSSQLServer\MSSQLServer',
       N'DefaultLog',
       REG_SZ,
       N'C:\MSSQL01\Logs'
GO
 
EXEC   xp_instance_regwrite
       N'HKEY_LOCAL_MACHINE',
       N'Software\Microsoft\MSSQLServer\MSSQLServer',
       N'BackupDirectory',
       REG_SZ,
       N'C:\MSSQL01\Backups'
GO
