"""Publish simulated bed-census events to Amazon Data Firehose (stream <prefix>-census).

Each event is a ward-level bed-management update with no patient
identifiers: ward, admission wait for a bed (minutes), boarding time (hours) and status. Firehose batches
the records into S3 (census/); Snowpipe loads them into RAW.LIVE_CENSUS.
Ward IDs come from RAW.WARDS (WARD-0000..WARD-0039). Values are seeded random.
"""
import argparse
import json
import random
import time
from datetime import datetime, timezone


def make_event(rng):
    alert = rng.random() < 0.1
    return {'ward_id': f'WARD-{rng.randint(0, 39):04d}',
            'event_ts': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3],
            'wait_minutes': round((150 if alert else 25) * rng.lognormvariate(0, 0.5), 1),
            'boarding_hours': round(max(0.0, rng.gauss(8.5 if alert else 2.0, 1.0)), 2),
            'status': 'ALERT' if alert else 'OK',
            'sent_ms': int(time.time() * 1000)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--region', default='us-west-2')
    ap.add_argument('--prefix', default='th-healthcare-hospital-capacity')
    ap.add_argument('--count', type=int, default=40)
    ap.add_argument('--seed', type=int)
    args = ap.parse_args()
    import boto3
    firehose = boto3.client('firehose', region_name=args.region)
    stream = f'{args.prefix}-census'
    rng = random.Random(args.seed)
    records = [{'Data': (json.dumps(make_event(rng)) + '\n').encode()} for _ in range(args.count)]
    for start in range(0, len(records), 500):
        out = firehose.put_record_batch(DeliveryStreamName=stream, Records=records[start:start + 500])
        if out['FailedPutCount']:
            raise RuntimeError(f"{out['FailedPutCount']} records were rejected by Firehose")
    print(f'published {args.count} bed-census events to Firehose stream {stream}; S3 delivery buffers up to 60 s')


if __name__ == '__main__':
    main()
