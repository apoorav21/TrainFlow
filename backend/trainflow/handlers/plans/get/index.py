"""
GET /plans/{planId}

Returns the plan metadata plus all workout days stored for that plan.
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

        plan = db.get_plan(user_id, plan_id)
        if not plan:
            return not_found(f'Plan {plan_id} not found')

        workout_days = db.get_workout_days(user_id, plan_id)

        return ok({
            'plan': plan,
            'workoutDays': workout_days,
            'totalDays': len(workout_days),
        })

    except ValueError as e:
        return bad_request(str(e))
    except Exception as e:
        print(f'[plans/get] error: {e}')
        return error('Failed to retrieve plan')
