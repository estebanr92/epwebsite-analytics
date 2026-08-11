data "aws_iam_policy_document" "firehose_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "firehose" {
  name               = "${var.project_name}-firehose"
  assume_role_policy = data.aws_iam_policy_document.firehose_assume_role.json
}

resource "aws_cloudwatch_log_group" "firehose" {
  name              = "/aws/kinesisfirehose/${var.project_name}-events"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_stream" "firehose_s3_delivery" {
  name           = "S3Delivery"
  log_group_name = aws_cloudwatch_log_group.firehose.name
}

data "aws_iam_policy_document" "firehose_permissions" {
  statement {
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject",
    ]
    resources = [
      aws_s3_bucket.events.arn,
      "${aws_s3_bucket.events.arn}/*",
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.firehose.arn}:*"]
  }
}

resource "aws_iam_role_policy" "firehose" {
  name   = "${var.project_name}-firehose-permissions"
  role   = aws_iam_role.firehose.id
  policy = data.aws_iam_policy_document.firehose_permissions.json
}

resource "aws_kinesis_firehose_delivery_stream" "events" {
  name        = "${var.project_name}-events"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose.arn
    bucket_arn = aws_s3_bucket.events.arn

    # Hive-style partitioning (year=/month=/day=) so Glue/Athena can prune
    # partitions instead of scanning the whole bucket on every query.
    prefix              = "events/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    error_output_prefix = "errors/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"

    buffering_size     = 1
    buffering_interval = 60
    compression_format = "GZIP"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose.name
      log_stream_name = aws_cloudwatch_log_stream.firehose_s3_delivery.name
    }
  }
}
