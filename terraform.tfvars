region          = "us-east-2"
vpc_id                 = # vpc id
aws_public_subnet_ids = # public subnets of vpc as list
aws_private_subnet_ids = # private subnets of vpc as list

# RDS
identifier        = "mysql"
engine            = "aurora-mysql"
engine_version    = "5.7.12"
instance_type    = "db.t3.small"
allocated_storage = 10
rds_storage_encrypted = false     # not supported for db.t2.micro instance
name              = "demo-aurora"        # use empty string to start without a database created
rds_username          = "admin"   # rds_password is generated

rds_port                    = 3306
rds_maintenance_window      = "Mon:00:00-Mon:03:00"
rds_backup_window           = "10:46-11:16"
rds_backup_retention_period = 1
rds_publicly_accessible     = false

rds_final_snapshot_identifier = "demo-rds-db-snapshot" # name of the final snapshot after deletion
rds_snapshot_identifier       = null # used to recover from a snapshot

rds_performance_insights_enabled  = true
db_subnet_group_name   = ""

# EKS

eks_key-pair  = "Test"
eks_instance_type = "c5.large"
eks_allow_port = 65535
ec2_instance_type = "t3.micro"


