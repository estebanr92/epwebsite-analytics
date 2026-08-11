# epwebsite-analytics

Click and time-on-page analytics pipeline for [epwebsite](../epwebsite), a portfolio site. The site itself is plain HTML/jQuery with no build step, so the goal here was a pipeline that a static site can talk to with a plain `fetch()`/`sendBeacon()` call — no AWS SDK, no credentials, nothing on the client beyond a POST request.

Everything below is provisioned with Terraform. QuickSight is the one exception — see the note at the bottom.

## Architecture

```
epwebsite (browser)
   |  POST /track  (fetch / sendBeacon)
   v
API Gateway (HTTP API)
   |  Lambda proxy integration
   v
Lambda  ingest, python3.12
   |  validates payload, stamps server_timestamp, firehose:PutRecordBatch
   v
Kinesis Firehose  (DirectPut -> extended_s3)
   |  buffers ~1MB / 60s, gzip, partitions by year/month/day
   v
S3  events bucket
   |
   v
Glue Data Catalog  (table + 4 views, no crawler)
   |
   v
Athena  -->  QuickSight (not wired up yet)
```

Why it's shaped this way:

- **API Gateway + Lambda in front of Firehose, instead of the browser calling Kinesis directly.** Kinesis has a JS SDK and you can absolutely PutRecord from a browser using a Cognito unauthenticated identity pool, but that means shipping AWS credentials (even scoped-down ones) to anyone who opens dev tools. Going through API Gateway means the client only ever sees a plain HTTPS endpoint.
- **Lambda writes to Firehose, not straight to S3.** Firehose batches records into files instead of writing one S3 object per click. A portfolio site isn't exactly high-traffic, but "one file per event" is still a bad habit — Athena scans get slower and more expensive as the object count grows, regardless of total data size.
- **The Lambda is intentionally dumb.** It parses the JSON body, rejects anything malformed, adds a server-side timestamp (client clocks aren't trustworthy), and hands off to Firehose. No enrichment, no geo lookups, nothing fancy.
- **Glue table is hand-written, not crawler-discovered.** I control the event schema (it's produced by `analytics.js` in the sibling repo), so there's nothing for a crawler to discover that I don't already know. Skipping it also avoids the classic crawler headache where it infers `bigint` from one file and `string` from another and Athena starts throwing type mismatch errors.
- **Partitions use projection, not `MSCK REPAIR TABLE` or a crawler run.** The table's `year`/`month`/`day` partitions are computed by Athena on the fly from the S3 prefix pattern. New partitions just work as soon as Firehose writes to them — nothing to run, nothing to keep in sync.

## Services

| Service | What it's doing here |
|---|---|
| API Gateway (HTTP API) | Public `POST /track` endpoint, CORS enabled, Lambda proxy integration, throttled to 50 req/s (burst 100) since it's unauthenticated |
| Lambda | `epwebsite-analytics-ingest`, Python 3.12, `boto3` only (no packaging step — it's the whole reason the Lambda is Python and not Node) |
| Kinesis Firehose | `epwebsite-analytics-events`, DirectPut source, extended_s3 destination, gzip, buffers 1MB or 60s (whichever first) |
| S3 | one bucket for raw events (`events/year=YYYY/month=MM/day=DD/...`), one bucket for Athena query results, both private with default encryption |
| Glue Data Catalog | database `epwebsite_analytics`, table `events`, 3 partition keys via projection |
| Athena | dedicated workgroup, own results bucket, 1GB scanned-per-query cap so a bad query can't run up a bill |
| CloudWatch Logs | Firehose delivery logs, Lambda logs, API Gateway access logs — three separate log groups, useful when something silently stops flowing |

## Events

The frontend (`epwebsite/js/analytics.js`) batches events client-side and posts them to `/track`. Five event types:

- **`page_view`** — fired once per page load.
- **`view_image`** — fired whenever the visitor's action points at a specific artwork: clicking a thumbnail in the collections grid, clicking a link in the works.html sidebar, navigating Next/Previous inside the image viewer, or landing on a work detail page (the first image counts as a view too).
- **`duration`** — how long something was actually visible on screen. On most pages this is one timer per page load. On `works.html` it's reset every time the viewer navigates to a different image, so you get per-artwork viewing time instead of one blended number for the whole page.
- **`visit_social`** — the Instagram link click on the contact page.
- **`copy_email`** — the contact email click.

Every event carries a common envelope — `event_id`, `visitor_id` / `session_id` (both random, stored in local/session storage), `page`, `path`, `collection_id`, `client_timestamp` plus a `server_timestamp` added by the Lambda, `referrer`, viewport size, and `user_agent`. On top of that, depending on the event type: `target_type`, `target_label`, `target_href`, `image_index`, `duration_ms`.

## Data layer

`s3://<events-bucket>/events/year=.../month=.../day=.../*.gz` — newline-delimited JSON, gzip compressed. Each file can hold anywhere from one event to however many arrived in the same buffering window.

Glue table `epwebsite_analytics.events` sits directly on top of that with an OpenX JSON SerDe. 18 columns total: the full event envelope plus every type-specific field, all nullable since no single event populates all of them.

Four views live on top of the table (`sql/`, applied straight through Athena — `CREATE VIEW` doesn't need to go through Terraform to be reproducible, the SQL is the source of truth either way):

- `daily_page_popularity` — page views per day, with a proper `date` column so grouping by week/month/quarter in a BI tool just works
- `top_images` — view counts per artwork
- `avg_time_by_page` — average seconds spent per page (excludes work_detail's per-image segments)
- `avg_time_by_image` — average seconds spent per artwork inside the viewer

## Querying it

Console: Athena → Query editor → switch the workgroup dropdown to **`epwebsite-analytics`** (the default `primary` workgroup has no result location configured, so queries fail until you switch). Database is `epwebsite_analytics`.

```sql
select * from daily_page_popularity
order by visit_date desc, page_views desc;

select * from top_images;

select page, count(*) as views
from events
where event_type = 'page_view'
group by page
order by views desc;
```

CLI works too:

```bash
aws athena start-query-execution \
  --query-string "select * from top_images" \
  --work-group epwebsite-analytics \
  --query-execution-context Database=epwebsite_analytics
```

## Repo layout

```
infra/       Terraform — everything under Services above
src/         Lambda source (currently just ingest-lambda/handler.py)
sql/         Athena view definitions, applied manually (see above)
```

## Deploying

```bash
cd infra
terraform init
terraform plan
terraform apply
```

Needs an AWS profile with admin-ish access (S3, Lambda, IAM, API Gateway, Firehose, Glue, Athena, CloudWatch). Default profile/region live in `variables.tf` — override with `-var` or a `.tfvars` file if yours differ.

## What's not done

- **CORS is wide open** (`allow_origins = ["*"]`) because epwebsite doesn't have a fixed domain deployed yet. Tighten this in `infra/api_gateway.tf` once it does.
- **QuickSight isn't wired up.** Deliberately kept out of Terraform — `aws_quicksight_account_subscription` exists but is known to be messy to tear down cleanly, and the console signup wizard auto-configures the S3/Athena IAM permissions for you, which would otherwise have to be hand-rolled. The data side (table + views) is ready for it whenever the subscription exists; only the data source resource itself would need a few lines of Terraform after that.
