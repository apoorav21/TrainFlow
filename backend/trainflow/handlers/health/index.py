"""
POST /health/sync  — batch-ingest HealthKit records from the iOS app
GET  /health       — retrieve recent health data (query param: ?days=N)

Both routes are handled by this single Lambda, dispatched on httpMethod.
"""

import sys
sys.path.insert(0, '/opt/python')

from datetime import date, timedelta, datetime, timezone

from trainflow.shared.auth import extract_user_id
from trainflow.shared.db import db
from trainflow.shared.response import ok, bad_request, error
from trainflow.shared.validators import parse_body, get_query_param


def handler(event, context):
    method = event.get('httpMethod', 'GET').upper()

    if method == 'POST':
        return _sync_health(event)
    elif method == 'GET':
        return _get_health(event)
    else:
        return bad_request(f'Method {method} not supported')


# ---------------------------------------------------------------------------
# POST /health/sync
# ---------------------------------------------------------------------------

def _sync_health(event):
    """
    Accept a batch of HealthKit daily records and upsert each into tf-health-data.

    Expected body:
    {
        "records": [
            {
                "date": "YYYY-MM-DD",
                "restingHR": 58,
                "hrv": 45.2,
                "vo2max": 48.5,
                "weight": 72.5,
                "steps": 8500,
                "activeCalories": 450,
                "basalCalories": 1800,
                "exerciseMinutes": 35,
                "sleepData": {
                    "totalMinutes": 420,
                    "deepMinutes": 60,
                    "remMinutes": 80,
                    "coreMinutes": 280,
                    "awakeMinutes": 15,
                    "respiratoryRate": 14.2,
                    "bloodOxygen": 98.5
                },
                "walkingHR": 92,
                "flightsClimbed": 5,
                "distance": 6.2
            }
        ]
    }
    """
    try:
        user_id = extract_user_id(event)
        body = parse_body(event)

        records = body.get('records', [])
        if not records:
            return bad_request('records array is required and must not be empty')

        now = datetime.now(timezone.utc).isoformat()
        items = []

        for rec in records:
            record_date = rec.get('date')
            if not record_date:
                # Skip records without a date rather than failing the whole batch
                print(f'[health/sync] Skipping record with no date: {rec}')
                continue

            item = {
                'userId': user_id,
                'date': record_date,
                'syncedAt': now,
            }

            # Copy all known HealthKit fields, skipping None values
            for field in (
                'restingHR', 'hrv', 'vo2max', 'weight', 'steps',
                'activeCalories', 'basalCalories', 'exerciseMinutes',
                'walkingHR', 'flightsClimbed', 'distance', 'sleepData',
            ):
                if rec.get(field) is not None:
                    item[field] = rec[field]

            items.append(item)

        if not items:
            return bad_request('No valid records to sync (all were missing date)')

        db.batch_put_health_data(items)

        return ok({
            'synced': True,
            'recordsWritten': len(items),
            'dates': [i['date'] for i in items],
        })

    except ValueError as e:
        return bad_request(str(e))
    except Exception as e:
        print(f'[health/sync] error: {e}')
        return error('Failed to sync health data')


# ---------------------------------------------------------------------------
# GET /health
# ---------------------------------------------------------------------------

def _get_health(event):
    """
    Return the last N days of health records, sorted by date descending.
    Query param: ?days=7 (default 14, max 90)
    """
    try:
        user_id = extract_user_id(event)

        days_param = get_query_param(event, 'days', '14')
        try:
            days = min(max(int(days_param), 1), 90)
        except (ValueError, TypeError):
            return bad_request('days must be a positive integer (max 90)')

        end_date = date.today().isoformat()
        start_date = (date.today() - timedelta(days=days)).isoformat()

        records = db.get_health_data_range(user_id, start_date, end_date)
        # Return newest first for the iOS client
        records_desc = list(reversed(records))

        return ok({
            'records': records_desc,
            'count': len(records_desc),
            'from': start_date,
            'to': end_date,
        })

    except ValueError as e:
        return bad_request(str(e))
    except Exception as e:
        print(f'[health/GET] error: {e}')
        return error('Failed to retrieve health data')
