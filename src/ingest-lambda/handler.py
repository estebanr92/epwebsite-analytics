import base64
import json
import os
import time

import boto3

firehose = boto3.client("firehose")
STREAM_NAME = os.environ["FIREHOSE_STREAM_NAME"]
MAX_EVENTS_PER_REQUEST = 25


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def lambda_handler(event, context):
    raw_body = event.get("body") or ""
    if event.get("isBase64Encoded"):
        raw_body = base64.b64decode(raw_body).decode("utf-8")

    try:
        payload = json.loads(raw_body) if raw_body else {}
    except json.JSONDecodeError:
        return _response(400, {"message": "invalid JSON"})

    events = payload.get("events")
    if not isinstance(events, list) or not events:
        return _response(400, {"message": "events must be a non-empty array"})

    server_timestamp = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    records = []
    for raw_event in events[:MAX_EVENTS_PER_REQUEST]:
        if not isinstance(raw_event, dict):
            continue
        enriched = dict(raw_event)
        enriched["server_timestamp"] = server_timestamp
        records.append({"Data": (json.dumps(enriched) + "\n").encode("utf-8")})

    if not records:
        return _response(400, {"message": "no valid events in batch"})

    result = firehose.put_record_batch(DeliveryStreamName=STREAM_NAME, Records=records)
    failed = result.get("FailedPutCount", 0)
    if failed:
        print(f"firehose put_record_batch: {failed} of {len(records)} records failed")

    return _response(202, {"accepted": len(records) - failed, "failed": failed})
