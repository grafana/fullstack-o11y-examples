# SQL Server 2022 RDS demo instance

This module creates SQL Server 2022 Express (`16.00.4265.3.v1`), an RDS subnet
group, and a security group in an existing default VPC. The VPC must have at
least two public default subnets across two Availability Zones. Terraform
verifies its primary CIDR before provisioning. Ingress on port 1433 is limited
to `allowed_cidr`; use the application's and Alloy's public egress address.

Configure AWS credentials using your AWS CLI profile or environment variables
and confirm them with `aws sts get-caller-identity` before running Terraform.

```sh
cp terraform.tfvars.example terraform.tfvars
# Edit the region, VPC ID/CIDR, and allowed_cidr for your account.
export TF_VAR_master_password='choose-a-unique-password'
terraform init
terraform plan
terraform apply
terraform output -raw endpoint
terraform output -raw arn
```

Keep tfvars, plans, state, and credentials private. The state contains the
master password. This is a public demo configuration with a single-AZ instance,
one day of backups, immediate changes, and no final snapshot on deletion.
Review private networking, backups, availability, and deletion protection for
shared environments. SQL Server Express avoids the SQL Server license fee, but
AWS compute, storage, and snapshots still incur charges.

To inspect the subnet Availability Zones in `us-west-1`:

```sh
aws ec2 describe-subnets --region us-west-1 \
  --filters Name=vpc-id,Values=YOUR_VPC_ID Name=default-for-az,Values=true \
  --query 'Subnets[].{Subnet:SubnetId,AZ:AvailabilityZone}' --output table
```

Each selected subnet must use a route table with `0.0.0.0/0` pointing to an
internet gateway. RDS also requires DNS support and DNS hostnames enabled.

The module permits an in-place major upgrade if a tracked older instance exists.
That causes downtime; RDS takes snapshots when backup retention is greater than
zero. Engine downgrades are not supported. To recover, restore the pre-upgrade
snapshot to another instance. If your RDS instance belongs to another Terraform
state, reuse its endpoint/ARN and manage it there rather than applying this
module with the same identifier.

After provisioning, follow the [SQL Server setup guide](../../sqlserver/README.md)
to create the databases and logins. To remove resources owned by this state, run
`terraform destroy`. It deletes the DB instance without a final snapshot and
leaves the existing VPC intact.
