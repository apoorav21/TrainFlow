"""
GET /plans/active

Returns the user's currently active training plan plus the computed
current week number based on the plan's startDate.
"""

import sys
sys.path.insert(0, '/opt/python')

from datetime import date

from trainflow.shared.auth import extract_user_id
from trainflow.shared.db import db
from trainflow.shared.response import ok, not_found, bad_request, error


def _compute_current_week(start_date_str: str) -> int:
    """
    Return the 1-indexed week number relative to the plan's start date.
    Week 1 = days 0-6, Week 2 = days 7-13, etc.
    Clamps to 1 if today is before the start date.
    """
    try:
        start = date.fromisoformat(start_date_str)
    except (ValueError, TypeError):
        return 1

    today = date.today()
    if today < start:
        return 1

    delta_days = (today - start).days
    return (delta_days // 7) + 1


def handler(event, context):
    try:
        user_id = extract_user_id(event)

        plan = db.get_active_plan(user_id)
        if not plan:
            return not_found('No active training plan found')

        current_week = _compute_current_week(plan.get('startDate', ''))

        # Keep currentWeek in the plan record in sync (best-effort, non-critical)
        stored_week = plan.get('currentWeek', 1)
        if current_week != stored_week:
            try:
                db.update_plan(user_id, plan['planId'], {'currentWeek': current_week})
                plan['currentWeek'] = current_week
            except Exception as update_err:
                # Don't fail the whole request if this update fails
                print(f'[plans/get_active] Could not update currentWeek: {update_err}')

        return ok({
            'plan': plan,
            'currentWeek': current_week,
        })

    except ValueError as e:
        return bad_request(str(e))
    except Exception as e:
        print(f'[plans/get_active] error: {e}')
        return error('Failed to retrieve active plan')
