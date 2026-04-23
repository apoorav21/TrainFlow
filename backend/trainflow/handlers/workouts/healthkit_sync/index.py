"""
POST /workouts/healthkit-sync

Batch-ingest HealthKit workout sessions synced from the iOS app.
Each workout is keyed by its HealthKit UUID so re-syncs are idempotent
(DynamoDB put_item overwrites the same key with fresh data).

Expected body:
{
    "workouts": [
        {
            "hkWorkoutId": "uuid",
            "workoutType": "Running",
            "startDate": "2025-01-15T08:30:00.000Z",
            "endDate":   "2025-01-15T09:15:00.000Z",
            "durationMin": 45.0,
            "distanceKm": 7.5,
            "calories": 420.0,
            "sourceName": "Workout"
        }
    ]
}
"""

import sys
sys.path.insert(0, '/opt/python')

from datetime import datetime, timezone

from trainflow.shared.auth import extract_user_id
from trainflow.shared.db import db
from trainflow.shared.response import ok, bad_request, error
from trainflow.shared.validators import parse_body


def handler(event, context):
    try:
        user_id = extract_user_id(event)
        body = parse_body(event)

        workouts = body.get('workouts', [])
        if not workouts:
            return bad_request('workouts array is required and must not be empty')

        now = datetime.now(timezone.utc).isoformat()
        items = []

        for w in workouts:
            hk_id = w.get('hkWorkoutId')
            start_date = w.get('startDate')
            if not hk_id or not start_date:
                continue

            # SK: startDate#HK#uuid — sorts chronologically, unique per HK workout
            sk = f"{start_date}#HK#{hk_id}"

            item = {
                'userId': user_id,
                'timestamp': sk,
                'source': 'healthkit',
                'hkWorkoutId': hk_id,
                'syncedAt': now,
            }

            for field in ('workoutType', 'startDate', 'endDate', 'durationMin',
                          'distanceKm', 'calories', 'sourceName',
                          'avgHeartRate', 'peakHeartRate'):
                if w.get(field) is not None:
                    item[field] = w[field]

            items.append(item)

        if not items:
            return bad_request('No valid workouts to sync (all were missing hkWorkoutId or startDate)')

        db.batch_put_workouts(items)
        print(f'[workouts/healthkit-sync] Stored {len(items)} workouts for user {user_id}')

        return ok({
            'synced': True,
            'recordsWritten': len(items),
        })

    except ValueError as e:
        return bad_request(str(e))
    except Exception as e:
        print(f'[workouts/healthkit-sync] error: {e}')
        return error('Failed to sync HealthKit workouts')
