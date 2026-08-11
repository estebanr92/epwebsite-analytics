locals {
  glue_database_name = replace(var.project_name, "-", "_")

  # Flat schema matching the events emitted by epwebsite/js/analytics.js
  # (see the header comment there) plus server_timestamp added by the ingest
  # Lambda. Kept in sync by hand since we control the producer directly.
  events_columns = {
    event_id         = "string"
    event_type       = "string"
    visitor_id       = "string"
    session_id       = "string"
    page             = "string"
    path             = "string"
    collection_id    = "string"
    client_timestamp = "string"
    server_timestamp = "string"
    referrer         = "string"
    viewport_width   = "int"
    viewport_height  = "int"
    user_agent       = "string"
    target_type      = "string"
    target_label     = "string"
    target_href      = "string"
    image_index      = "int"
    duration_ms      = "int"
  }
}

resource "aws_glue_catalog_database" "analytics" {
  name = local.glue_database_name
}

resource "aws_glue_catalog_table" "events" {
  name          = "events"
  database_name = aws_glue_catalog_database.analytics.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    classification = "json"

    # Partition projection: Athena computes year=/month=/day= partition
    # locations from the range below instead of needing a crawler run or
    # MSCK REPAIR TABLE every time Firehose writes a new date partition.
    "projection.enabled"        = "true"
    "projection.year.type"      = "integer"
    "projection.year.range"     = "2025,2035"
    "projection.month.type"     = "integer"
    "projection.month.range"    = "1,12"
    "projection.month.digits"   = "2"
    "projection.day.type"       = "integer"
    "projection.day.range"      = "1,31"
    "projection.day.digits"     = "2"
    "storage.location.template" = "s3://${aws_s3_bucket.events.bucket}/events/year=$${year}/month=$${month}/day=$${day}/"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.events.bucket}/events/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "json"
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
    }

    dynamic "columns" {
      for_each = local.events_columns
      content {
        name = columns.key
        type = columns.value
      }
    }
  }

  partition_keys {
    name = "year"
    type = "string"
  }
  partition_keys {
    name = "month"
    type = "string"
  }
  partition_keys {
    name = "day"
    type = "string"
  }
}
