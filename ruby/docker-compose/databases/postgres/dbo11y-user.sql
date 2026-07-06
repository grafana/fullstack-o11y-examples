-- Grafana Database Observability — least-privilege collector role.
-- Runs after the seed (mounted as 02-dbo11y-user.sql, after 01-init.sql). Grants the
-- monitoring/read roles the database_observability.postgres collector needs, and opts
-- the collector's own role out of pg_stat_statements tracking. Role settings persist
-- in the catalog (unlike MySQL's in-memory performance_schema).
CREATE USER "db-o11y" WITH PASSWORD 'db-o11y-pass';
GRANT pg_monitor TO "db-o11y";
GRANT pg_read_all_stats TO "db-o11y";
ALTER ROLE "db-o11y" SET pg_stat_statements.track = 'none';
GRANT pg_read_all_data TO "db-o11y";
