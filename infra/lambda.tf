data "archive_file" "ingest_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../src/ingest-lambda"
  output_path = "${path.module}/.build/ingest-lambda.zip"
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ingest_lambda" {
  name               = "${var.project_name}-ingest-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ingest_lambda_basic_execution" {
  role       = aws_iam_role.ingest_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "ingest_lambda_firehose" {
  statement {
    effect    = "Allow"
    actions   = ["firehose:PutRecord", "firehose:PutRecordBatch"]
    resources = [aws_kinesis_firehose_delivery_stream.events.arn]
  }
}

resource "aws_iam_role_policy" "ingest_lambda_firehose" {
  name   = "${var.project_name}-ingest-lambda-firehose"
  role   = aws_iam_role.ingest_lambda.id
  policy = data.aws_iam_policy_document.ingest_lambda_firehose.json
}

resource "aws_cloudwatch_log_group" "ingest_lambda" {
  name              = "/aws/lambda/${var.project_name}-ingest"
  retention_in_days = 30
}

resource "aws_lambda_function" "ingest" {
  function_name = "${var.project_name}-ingest"
  role          = aws_iam_role.ingest_lambda.arn

  filename         = data.archive_file.ingest_lambda.output_path
  source_code_hash = data.archive_file.ingest_lambda.output_base64sha256

  handler     = "handler.lambda_handler"
  runtime     = "python3.12"
  timeout     = 10
  memory_size = 128

  environment {
    variables = {
      FIREHOSE_STREAM_NAME = aws_kinesis_firehose_delivery_stream.events.name
    }
  }

  depends_on = [aws_cloudwatch_log_group.ingest_lambda]
}
