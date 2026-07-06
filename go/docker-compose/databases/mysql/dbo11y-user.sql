-- Grafana Database Observability — least-privilege collector user.
-- Runs after the seed (mounted as 02-dbo11y-user.sql, after 01-init.sql) so the
-- schema/data exist first. Grants the privileges the database_observability.mysql
-- collector needs. performance_schema instrumentation is managed by the collector
-- at runtime (allow_update_performance_schema_settings / auto_enable_setup_consumers);
-- it can't be pre-set here because performance_schema is in-memory and resets on
-- every server start (including MySQL's post-initdb restart).
CREATE USER 'db-o11y'@'%' IDENTIFIED BY 'db-o11y-pass';
GRANT PROCESS, REPLICATION CLIENT ON *.* TO 'db-o11y'@'%';
GRANT SELECT ON performance_schema.* TO 'db-o11y'@'%';
GRANT SELECT, SHOW VIEW ON *.* TO 'db-o11y'@'%';
GRANT UPDATE ON performance_schema.setup_consumers TO 'db-o11y'@'%';
