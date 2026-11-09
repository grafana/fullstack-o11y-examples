variable "aws_region" {
  description = "AWS region for this disposable demo environment."
  type        = string
}

variable "identifier" {
  description = "Unique RDS DB instance identifier."
  type        = string
  default     = "dbo11y-mssql-demo"
}

variable "instance_class" {
  description = "RDS instance class supported by SQL Server Express in the selected region."
  type        = string
  default     = "db.t3.micro"
}

variable "allowed_cidr" {
  description = "Single IPv4 CIDR allowed to connect to port 1433; use your public IP with /32."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.allowed_cidr)) && try(tonumber(split("/", var.allowed_cidr)[1]) >= 24 && tonumber(split("/", var.allowed_cidr)[1]) <= 32, false)
    error_message = "Use a valid IPv4 CIDR between /24 and /32; never use 0.0.0.0/0."
  }
}

variable "master_username" {
  description = "RDS master login name."
  type        = string
  default     = "dbadmin"
}

variable "master_password" {
  description = "RDS master password. Supply through a local tfvars file or TF_VAR_master_password."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.master_password) >= 8 && length(var.master_password) <= 128
    error_message = "The RDS master password must be 8 to 128 characters."
  }
}

variable "vpc_id" {
  description = "ID of the existing default VPC for the RDS demo."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "Set vpc_id to an AWS VPC ID, such as vpc-0123456789abcdef0."
  }
}

variable "vpc_cidr" {
  description = "Expected primary CIDR of the existing VPC; Terraform checks it before provisioning."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "Set vpc_cidr to a valid IPv4 CIDR block."
  }
}
