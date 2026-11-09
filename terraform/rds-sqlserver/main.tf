data "aws_vpc" "selected" {
  id = var.vpc_id

  lifecycle {
    postcondition {
      condition     = self.cidr_block == var.vpc_cidr
      error_message = "VPC ${var.vpc_id} has CIDR ${self.cidr_block}; expected ${var.vpc_cidr}."
    }
  }
}

data "aws_subnets" "default_vpc" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

locals {
  common_tags = {
    Project   = "dbo11y-mssql-server"
    ManagedBy = "Terraform"
  }
}

resource "aws_security_group" "sqlserver" {
  name_prefix = "${var.identifier}-"
  description = "SQL Server ingress restricted to the configured client CIDR."
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    description = "SQL Server from the operator-supplied CIDR"
    from_port   = 1433
    to_port     = 1433
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.identifier}-sqlserver" })
}

resource "aws_db_subnet_group" "sqlserver" {
  name       = "${var.identifier}-subnets"
  subnet_ids = data.aws_subnets.default_vpc.ids
  tags       = local.common_tags

  lifecycle {
    precondition {
      condition     = length(data.aws_subnets.default_vpc.ids) >= 2
      error_message = "The selected default VPC must have default subnets in at least two Availability Zones for RDS."
    }
  }
}

resource "aws_db_instance" "sqlserver" {
  identifier                  = var.identifier
  engine                      = "sqlserver-ex"
  engine_version              = "16.00.4265.3.v1" # SQL Server 2022 CU26
  allow_major_version_upgrade = true
  instance_class              = var.instance_class
  license_model               = "license-included"
  allocated_storage           = 20
  storage_type                = "gp2"
  username                    = var.master_username
  password                    = var.master_password
  port                        = 1433
  db_subnet_group_name        = aws_db_subnet_group.sqlserver.name
  vpc_security_group_ids      = [aws_security_group.sqlserver.id]
  publicly_accessible         = true
  storage_encrypted           = true
  multi_az                    = false
  backup_retention_period     = 1
  auto_minor_version_upgrade  = true
  apply_immediately           = true
  deletion_protection         = false
  skip_final_snapshot         = true

  tags = merge(local.common_tags, { Name = var.identifier })
}
