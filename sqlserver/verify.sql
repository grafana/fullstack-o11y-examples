-- Verify the db-o11y collector privileges created by setup.sql.
-- Source: Database Observability docs, "Verify user privileges" (Amazon RDS for SQL Server).
--
-- Connect as the db-o11y login, NOT the RDS master login, so the results show the
-- privileges that are effective for the collector. For example:
--   sqlcmd -S <rds-endpoint>,1433 -U db-o11y -P '<DBO11Y_LOGIN_PASSWORD>' -C -i verify.sql

USE [master];
GO

-- Databases schema details can reach. Should list bookstore and shipping.
SELECT name FROM sys.databases WHERE HAS_DBACCESS(name) = 1;
GO

-- ─── bookstore ──────────────────────────────────────────────────────────────
USE [bookstore];
GO

-- Query Store is readable on the connected database. Expect one row with actual_state_desc = READ_WRITE.
SELECT DB_NAME() AS database_name, actual_state_desc FROM sys.database_query_store_options;
GO

-- Effective permission to read schema metadata on the current database. Expect 1.
SELECT HAS_PERMS_BY_NAME(DB_NAME(), 'DATABASE', 'VIEW DEFINITION') AS can_view_definition;
GO

-- ─── shipping ───────────────────────────────────────────────────────────────
USE [shipping];
GO

-- Expect one row with actual_state_desc = READ_WRITE.
SELECT DB_NAME() AS database_name, actual_state_desc FROM sys.database_query_store_options;
GO

-- Expect 1.
SELECT HAS_PERMS_BY_NAME(DB_NAME(), 'DATABASE', 'VIEW DEFINITION') AS can_view_definition;
GO

-- If a Query Store query returns no rows or an error, or can_view_definition returns 0,
-- the grants are not effective on that database. Re-run the database-level grants from
-- setup.sql (VIEW DATABASE [PERFORMANCE] STATE and VIEW DEFINITION) in that database.
