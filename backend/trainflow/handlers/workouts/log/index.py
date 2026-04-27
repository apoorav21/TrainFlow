"""
POST /workouts

Log a completed workout. This does two things atomically (best-effort):
  1. Writes a new record to tf-workouts (PK=userId, SK=ISO timestamp)
  2. Marks the corresponding workout day in tf-workout-days as completed

AI-generated feedback on the workout is NOT generated here — the coach
surfaces it naturally during the next chat interaction, keeping this
endpoint fast and simple.

Expected body:
{
    "workoutDayId": "planId#W01#D1",    <- daySK; optional
    "planId": "...",                    <- optional, used to verify day
    "workoutType": "Easy Run",
    "scheduledDate": "2025-11-03",      <- optional
    "actualDistance": 5.2,
    "actualDurationMin": 34,
    "avgHeartRate": 145,
    "effortRating": 5,
    "notes": "Felt good, hot outside",
    "hrvPost": 42                       <- optional post-workout HRV
}
"""

import sys
sys.path.insert(0, '/opt/python')

import uuid
from datetime import datetime, timezone

from trainflow.shared.auth import extract_user_id
from trainflow.shared.db import db
from trainflow.shared.response import created, bad_request, error
from trainflow.shared.validators import parse_body, require_fields


def handler(event, context):
    try:
        user_id = extract_user_id(event)
        body = parse_body(event)

        require_fields(body, ['workoutType'])

        now = datetime.now(timezone.utc).isoformat()
        workout_id = str(uuid.uuid4())

        # ----------------------------------------------------------------
        # 1. Build and store the workout log record
        # ----------------------------------------------------------------
        workout_item = {
            'userId': user_id,
            'timestamp': now,        # ISO8601 — used as SK for sort order
            'workoutId': workout_id,
            'workoutType': body['workoutType'],
            'createdAt': now,
        }

        # Copy optional fields if present (skip None to save storage)
        for field in (
            'workoutDayId', 'planId', 'scheduledDate',
            'actualDistance', 'actualDurationMin',
            'avgHeartRate', 'peakHeartRate', 'calories', 'avgPace',
            'effortRating', 'notes', 'hrvPost', 'sectionHeartRates',
        ):
            if body.get(field) is not None:
                workout_item[field] = body[field]

        db.put_workout(workout_item)

        # ----------------------------------------------------------------
        # 2. Mark the corresponding workout day as completed (best-effort)
        # ----------------------------------------------------------------
        day_sk = body.get('workoutDayId')
        if day_sk:
            try:
                day_updates = {
                    'isCompleted': True,
                    'completedAt': now,
                    'workoutLogId': workout_id,
                    'updatedAt': now,
                }
                if body.get('actualDistance') is not None:
                    day_updates['actualDistance'] = body['actualDistance']
                if body.get('actualDurationMin') is not None:
                    day_updates['actualDuration'] = f'{int(body["actualDurationMin"])}min'

                db.update_workout_day(user_id, day_sk, day_updates)
            except Exception as day_err:
                # Don't fail the whole request — the workout log is the source
                # of truth, the day update is a convenience flag.
                print(f'[workouts/log] Could not mark day {day_sk} complete: {day_err}')

        return created({
            'workoutId': workout_id,
            'timestamp': now,
            'message': 'Workout logged. Chat with your coach for personalised feedback.',
        })

    except ValueError as e:
        return bad_request(str(e))
    except Exception as e:
        print(f'[workouts/log] error: {e}')
        return error('Failed to log workout')
