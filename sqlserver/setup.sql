-- Run as the RDS master login with a SQL client in SQLCMD mode if using the
-- :setvar directives below. Replace the password placeholders before execution.
:setvar AppLoginPassword "REPLACE_WITH_A_UNIQUE_APP_PASSWORD"
:setvar Dbo11yLoginPassword "REPLACE_WITH_A_UNIQUE_MONITOR_PASSWORD"

USE [master];
GO
IF DB_ID(N'bookstore') IS NULL EXEC(N'CREATE DATABASE [bookstore]');
GO
IF DB_ID(N'shipping') IS NULL EXEC(N'CREATE DATABASE [shipping]');
GO

ALTER DATABASE [bookstore] SET QUERY_STORE = ON
  (OPERATION_MODE = READ_WRITE, QUERY_CAPTURE_MODE = ALL);
GO
ALTER DATABASE [shipping] SET QUERY_STORE = ON
  (OPERATION_MODE = READ_WRITE, QUERY_CAPTURE_MODE = ALL);
GO

IF SUSER_ID(N'bookstore_app') IS NULL
  EXEC(N'CREATE LOGIN [bookstore_app] WITH PASSWORD = N''$(AppLoginPassword)''');
GO
IF SUSER_ID(N'db-o11y') IS NULL
  EXEC(N'CREATE LOGIN [db-o11y] WITH PASSWORD = N''$(Dbo11yLoginPassword)''');
GO

USE [bookstore];
GO
IF USER_ID(N'bookstore_app') IS NULL CREATE USER [bookstore_app] FOR LOGIN [bookstore_app];
IF USER_ID(N'db-o11y') IS NULL CREATE USER [db-o11y] FOR LOGIN [db-o11y];
GRANT CONNECT TO [db-o11y];
ALTER ROLE [db_datareader] ADD MEMBER [bookstore_app];
ALTER ROLE [db_datawriter] ADD MEMBER [bookstore_app];
IF CONVERT(int, SERVERPROPERTY('ProductMajorVersion')) >= 16
  EXEC(N'GRANT VIEW DATABASE PERFORMANCE STATE TO [db-o11y]');
ELSE
  GRANT VIEW DATABASE STATE TO [db-o11y];
GRANT VIEW DEFINITION TO [db-o11y];
GO

USE [shipping];
GO
IF USER_ID(N'bookstore_app') IS NULL CREATE USER [bookstore_app] FOR LOGIN [bookstore_app];
IF USER_ID(N'db-o11y') IS NULL CREATE USER [db-o11y] FOR LOGIN [db-o11y];
GRANT CONNECT TO [db-o11y];
ALTER ROLE [db_datareader] ADD MEMBER [bookstore_app];
ALTER ROLE [db_datawriter] ADD MEMBER [bookstore_app];
IF CONVERT(int, SERVERPROPERTY('ProductMajorVersion')) >= 16
  EXEC(N'GRANT VIEW DATABASE PERFORMANCE STATE TO [db-o11y]');
ELSE
  GRANT VIEW DATABASE STATE TO [db-o11y];
GRANT VIEW DEFINITION TO [db-o11y];
GO
