#
# Activity stream decrypt function
#
resource "terraform_data" "decrypt_deps" {
  provisioner "local-exec" {
    command = "pip install -r ${path.module}/lambda/requirements.txt -t ${path.module}/lambda/layer/python"
  }

  triggers_replace = [
    sha256(file("${path.module}/lambda/requirements.txt")),
    sha256(file("${path.module}/lambda/decrypt.py"))
  ]
}

data "archive_file" "decrypt_deps" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/layer"
  output_path = "/tmp/decrypt_deps.zip"
  depends_on = [
    terraform_data.decrypt_deps
  ]
}

data "archive_file" "decrypt_code" {
  type        = "zip"
  source_file = "${path.module}/lambda/decrypt.py"
  output_path = "/tmp/decrypt.zip"
}

resource "aws_lambda_layer_version" "decrypt_deps" {
  layer_name          = "decrypt-deps"
  filename            = data.archive_file.decrypt_deps.output_path
  source_code_hash    = data.archive_file.decrypt_deps.output_base64sha256
  compatible_runtimes = ["python3.12"]
}

resource "aws_lambda_function" "decrypt" {
  function_name = local.decrypt_lambda_function
  handler       = "decrypt.handler"
  runtime       = "python3.12"
  memory_size   = 256
  timeout       = 5
  role          = aws_iam_role.decrypt.arn

  filename         = data.archive_file.decrypt_code.output_path
  source_code_hash = data.archive_file.decrypt_code.output_base64sha256
  layers           = [aws_lambda_layer_version.decrypt_deps.arn]

  environment {
    variables = {
      RDS_ACTIVITY_STREAM_NAME = aws_rds_cluster_activity_stream.database.kinesis_stream_name
    }
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "decrypt" {
  name              = "/aws/lambda/${local.decrypt_lambda_function}"
  retention_in_days = "7"
  tags              = local.common_tags
}

#
# IAM role
#
resource "aws_iam_role" "decrypt" {
  name               = local.decrypt_lambda_function
  assume_role_policy = data.aws_iam_policy_document.decrypt_assume.json
}

resource "aws_iam_policy" "decrypt" {
  name   = local.decrypt_lambda_function
  path   = "/"
  policy = data.aws_iam_policy_document.decrypt.json
}

resource "aws_iam_role_policy_attachment" "decrypt" {
  role       = aws_iam_role.decrypt.name
  policy_arn = aws_iam_policy.decrypt.arn
}

data "aws_iam_policy_document" "decrypt_assume" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
    ]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "decrypt" {
  statement {
    sid    = "CloudWatchWriteLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "${aws_cloudwatch_log_group.decrypt.arn}:log-stream:*"
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
}

resource "aws_lambda_permission" "lambda_permission" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.decrypt.function_name
  principal     = "firehose.amazonaws.com"
  source_arn    = aws_kinesis_firehose_delivery_stream.activity_stream.arn
}

