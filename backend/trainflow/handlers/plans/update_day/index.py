"""
PUT /plans/{planId}/days/{dayId}

Partially update a workout day in tf-workout-days.
`dayId` is the full daySK (URL-encoded), e.g. planId%23W01%23D1 → planId#W01#D1.

Common use-cases:
  - Mark a workout as completed: { "isCompleted": true, "completedAt": "..." }
  - AI plan adaptation: update title, mainWorkout, coachMessage, etc.
  - Log actuals: { "actualDistance": 5.2, "actualDuration": "34:00" }

Fields the caller should NOT set via this endpoint (ignored silently):
  userId, planId, daySK, createdAt
"""

import sys
sys.path.insert(0, '/opt/python')

from datetime import datetime, timezone
from urllib.parse import unquote

from trainflow.shared.auth import extract_user_id
from trainflow.shared.db import db
from trainflow.shared.response import ok, not_found, bad_request, error
from trainflow.shared.validators import parse_body, get_path_param


# Keys that must not be overwritten by caller
_IMMUTABLE = {'userId', 'planId', 'planWeekDay', 'createdAt'}


def handler(event, context):
    try:
        user_id = extract_user_id(event)
        plan_id = get_path_param(event, 'planId')
        day_id_raw = get_path_param(event, 'dayId')

        # URL-decode in case the iOS client percent-encoded the '#' characters
        day_sk = unquote(day_id_raw)

        body = parse_body(event)
        updates = {k: v for k, v in body.items() if k not in _IMMUTABLE}

        if not updates:
            return bad_request('No valid fields to update')

        # Verify the day exists and belongs to this user's plan
        existing = db.get_workout_day(user_id, day_sk)
        if not existing:
            return not_found(f'Workout day {day_sk} not found')

        if existing.get('planId') != plan_id:
            return bad_request('dayId does not belong to the specified planId')

        updates['updatedAt'] = datetime.now(timezone.utc).isoformat()

        updated = db.update_workout_day(user_id, day_sk, updates)

        return ok({'workoutDay': updated})

    except ValueError as e:
        return bad_request(str(e))
    except Exception as e:
        print(f'[plans/update_day] error: {e}')
        return error('Failed to update workout day')
