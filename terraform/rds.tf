module "database" {
  source = "github.com/cds-snc/terraform-modules//rds?ref=v9.2.7"
  name   = var.project_name

  database_name  = "test"
  engine         = "aurora-postgresql"
  engine_version = "15.2"
  instances      = 2
  instance_class = "db.r6g.large" # https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/DBActivityStreams.Overview.html#DBActivityStreams.Overview.requirements.classes
  username       = var.database_username
  password       = var.database_password

  backup_retention_period             = 7
  preferred_backup_window             = "02:00-04:00"
  performance_insights_enabled        = false
  iam_database_authentication_enabled = true
  upgrade_immediately                 = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  billing_tag_value = var.billing_tag_value
}

resource "aws_ssm_parameter" "database_username" {
  name  = "database_username"
  type  = "SecureString"
  value = var.database_username
  tags  = local.common_tags
}

resource "aws_ssm_parameter" "database_password" {
  name  = "database_password"
  type  = "SecureString"
  value = var.database_password
  tags  = local.common_tags
}

resource "aws_kms_key" "database_activity_stream" {
  description = "AWS KMS Key to encrypt the database activity stream"
}

resource "aws_rds_cluster_activity_stream" "database" {
  resource_arn = module.database.rds_cluster_arn
  mode         = "async"
  kms_key_id   = aws_kms_key.database_activity_stream.key_id
}
