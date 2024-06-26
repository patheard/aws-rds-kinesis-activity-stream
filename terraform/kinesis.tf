resource "aws_kinesis_firehose_delivery_stream" "activity_stream" {
  name        = "${var.project_name}-firehose"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = local.database_kinesis_stream_arn
    role_arn           = aws_iam_role.firehose_activity_stream.arn
  }

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_activity_stream.arn
    bucket_arn = module.activity_stream_bucket.s3_bucket_arn

    processing_configuration {
      enabled = "true"

      processors {
        type = "Lambda"

        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = aws_lambda_function.decrypt.arn
        }
      }
    }

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose_activity_stream.name
      log_stream_name = aws_cloudwatch_log_stream.firehose_activity_stream.name
    }
  }



  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "firehose_activity_stream" {
  name              = "/aws/kinesis/${var.project_name}-firehose"
  retention_in_days = "7"
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_stream" "firehose_activity_stream" {
  name           = "logs"
  log_group_name = aws_cloudwatch_log_group.firehose_activity_stream.name
}


#
# Destination bucket
#
module "activity_stream_bucket" {
  source            = "github.com/cds-snc/terraform-modules//S3?ref=v9.2.7"
  bucket_name       = "${var.project_name}-bucket"
  billing_tag_value = var.billing_tag_value

  lifecycle_rule = [
    {
      id      = "expire-objects-after-7-days"
      enabled = true
      expiration = {
        days                         = 7
        expired_object_delete_marker = false
      }
    },
  ]
}

#
# IAM
#
resource "aws_iam_role" "firehose_activity_stream" {
  name               = "${var.project_name}-firehose"
  assume_role_policy = data.aws_iam_policy_document.firehose_assume.json
}

resource "aws_iam_policy" "firehose_activity_stream" {
  name   = "${var.project_name}-firehose"
  path   = "/"
  policy = data.aws_iam_policy_document.firehose_activity_stream.json
}

resource "aws_iam_role_policy_attachment" "firehose_activity_stream" {
  role       = aws_iam_role.firehose_activity_stream.name
  policy_arn = aws_iam_policy.firehose_activity_stream.arn
}

data "aws_iam_policy_document" "firehose_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "firehose_activity_stream" {
  statement {
    sid    = "S3Write"
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject"
    ]
    resources = [
      module.activity_stream_bucket.s3_bucket_arn,
      "${module.activity_stream_bucket.s3_bucket_arn}/*"
    ]
  }

  statement {
    sid    = "KinesisListStreams"
    effect = "Allow"
    actions = [
      "kinesis:ListStreams"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    sid    = "KinesisReadDBActivityStream"
    effect = "Allow"
    actions = [
      "kinesis:GetRecords",
      "kinesis:GetShardIterator",
      "kinesis:DescribeStream",
      "kinesis:DescribeStreamSummary",
      "kinesis:ListShards",
      "kinesis:ListStreams"
    ]
    resources = [
      local.database_kinesis_stream_arn
    ]
  }

  statement {
    sid    = "KMSDecryptDatabaseActivityStream"
    effect = "Allow"
    actions = [
      "kms:Decrypt"
    ]
    resources = [
      aws_kms_key.database_activity_stream.arn
    ]
  }

  statement {
    sid    = "LambdaInvokeDecrypt"
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction",
      "lambda:GetFunctionConfiguration"
    ]
    resources = [
      aws_lambda_function.decrypt.arn
    ]
  }
}