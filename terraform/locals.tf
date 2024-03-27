data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  common_tags = {
    Terraform  = "true"
    CostCentre = var.billing_tag_value
  }
  database_kinesis_stream_arn = "arn:aws:kinesis:${var.region}:${local.account_id}:stream/${aws_rds_cluster_activity_stream.database.kinesis_stream_name}"
  decrypt_lambda_function     = "${var.project_name}-decrypt"
}