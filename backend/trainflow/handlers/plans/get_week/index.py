"""
GET /plans/{planId}/weeks/{weekNum}

Returns all workout days for a specific week of a training plan.
Queries tf-workout-days where PK=userId and SK begins_with {planId}#W{weekNum:02}.
"""

import sys
sys.path.insert(0, '/opt/python')

from trainflow.shared.auth import extract_user_id
from trainflow.shared.db import db
from trainflow.shared.response import ok, not_found, bad_request, error
from trainflow.shared.validators import get_path_param


def handler(event, context):
    try:
        user_id = extract_user_id(event)
        plan_id = get_path_param(event, 'planId')
        week_num_str = get_path_param(event, 'weekNum')

        try:
            week_num = int(week_num_str)
            if week_num < 1:
                raise ValueError()
        except (ValueError, TypeError):
            return bad_request('weekNum must be a positive integer')

        # Verify the plan exists and belongs to this user
        plan = db.get_plan(user_id, plan_id)
        if not plan:
            return not_found(f'Plan {plan_id} not found')

        workout_days = db.get_workout_days_for_week(user_id, plan_id, week_num)

        return ok({
            'planId': plan_id,
            'weekNumber': week_num,
            'workoutDays': workout_days,
            'totalDays': len(workout_days),
        })

    except ValueError as e:
        return bad_request(str(e))
    except Exception as e:
        print(f'[plans/get_week] error: {e}')
        return error('Failed to retrieve week workouts')
