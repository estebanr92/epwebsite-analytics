output "aws_account_id" {
  description = "AWS account Terraform is currently authenticated against."
  value       = data.aws_caller_identity.current.account_id
}

output "aws_caller_arn" {
  description = "IAM identity Terraform is currently authenticated as."
  value       = data.aws_caller_identity.current.arn
}

output "events_bucket_name" {
  description = "S3 bucket where Firehose delivers raw click analytics events."
  value       = aws_s3_bucket.events.bucket
}

output "events_bucket_arn" {
  description = "ARN of the S3 bucket where Firehose delivers raw click analytics events."
  value       = aws_s3_bucket.events.arn
}

output "firehose_delivery_stream_name" {
  description = "Kinesis Firehose delivery stream that the ingest Lambda writes events to."
  value       = aws_kinesis_firehose_delivery_stream.events.name
}

output "firehose_delivery_stream_arn" {
  description = "ARN of the Kinesis Firehose delivery stream."
  value       = aws_kinesis_firehose_delivery_stream.events.arn
}

output "ingest_lambda_function_name" {
  description = "Name of the ingest Lambda function (target for the API Gateway integration)."
  value       = aws_lambda_function.ingest.function_name
}

output "ingest_lambda_arn" {
  description = "ARN of the ingest Lambda function."
  value       = aws_lambda_function.ingest.arn
}

output "ingest_lambda_invoke_arn" {
  description = "Invoke ARN of the ingest Lambda function, used by the API Gateway Lambda integration."
  value       = aws_lambda_function.ingest.invoke_arn
}

output "api_endpoint" {
  description = "Base invoke URL for the HTTP API. Frontend should POST events to <this>/track."
  value       = aws_apigatewayv2_api.http_api.api_endpoint
}

output "glue_database_name" {
  description = "Glue Data Catalog database name, queryable from Athena/QuickSight."
  value       = aws_glue_catalog_database.analytics.name
}

output "glue_table_name" {
  description = "Glue Data Catalog table name for the events, queryable from Athena/QuickSight."
  value       = aws_glue_catalog_table.events.name
}

output "athena_results_bucket_name" {
  description = "S3 bucket where Athena query results are stored."
  value       = aws_s3_bucket.athena_results.bucket
}

output "athena_workgroup_name" {
  description = "Athena workgroup configured for querying the analytics events table."
  value       = aws_athena_workgroup.analytics.name
}
