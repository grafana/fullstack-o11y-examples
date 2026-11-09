output "endpoint" {
  description = "RDS endpoint hostname; use as MSSQL_HOST."
  value       = aws_db_instance.sqlserver.address
}

output "port" {
  description = "SQL Server port."
  value       = aws_db_instance.sqlserver.port
}

output "arn" {
  description = "RDS instance ARN; use as RDS_ARN in Alloy."
  value       = aws_db_instance.sqlserver.arn
}

output "identifier" {
  description = "RDS instance identifier."
  value       = aws_db_instance.sqlserver.identifier
}

output "vpc_id" {
  description = "Existing VPC used by the RDS instance."
  value       = data.aws_vpc.selected.id
}

output "vpc_cidr" {
  description = "Primary CIDR of the existing VPC."
  value       = data.aws_vpc.selected.cidr_block
}

output "engine_version" {
  description = "Actual RDS SQL Server engine version."
  value       = aws_db_instance.sqlserver.engine_version_actual
}
