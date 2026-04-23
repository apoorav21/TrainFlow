"""
POST /plans

Creates a new training plan for the user.

This endpoint is called internally by the AI tool executor (create_training_plan
tool) but is also exposed as a direct HTTP endpoint so the iOS app can invoke it
from the plan-generation flow if needed.

Steps:
  1. Deactivate any currently active plan (set isActive='false')
  2. Persist the new plan record to tf-training-plans
  3. Batch-write all workout day records to tf-workout-days
  4. Mark the user's onboardingComplete flag as True
  5. Return the created plan metadata

Plan body format (from AI tool):
{
    "planName": "Mumbai Marathon 16-Week Plan",
    "goalType": "Marathon",
    "startDate": "2025-11-01",
    "endDate": "2026-02-15",
    "totalWeeks": 16,
    "workoutDays": [ ... ]   <- array of day objects (see schema in prompt)
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

        require_fields(body, ['planName', 'goalType', 'startDate', 'endDate', 'totalWeeks'])

        plan_id = str(uuid.uuid4())
        now = datetime.now(timezone.utc).isoformat()

        # ----------------------------------------------------------------
        # 1. Deactivate any existing active plan
        # ----------------------------------------------------------------
        existing_active = db.get_active_plan(user_id)
        if existing_active:
            db.update_plan(user_id, existing_active['planId'], {
                'isActive': 'false',
                'updatedAt': now,
            })
            print(f'[plans/create] Deactivated plan {existing_active["planId"]} for user {user_id}')

        # ----------------------------------------------------------------
        # 2. Build and persist the new plan record
        # ----------------------------------------------------------------
        plan_item = {
            'userId': user_id,
            'planId': plan_id,
            'planName': body['planName'],
            'goalType': body['goalType'],
            'startDate': body['startDate'],
            'endDate': body['endDate'],
            'totalWeeks': int(body['totalWeeks']),
            'currentWeek': 1,
            'isActive': 'true',
            'createdAt': now,
            'updatedAt': now,
        }
        db.put_plan(plan_item)

        # ----------------------------------------------------------------
        # 3. Batch-write workout days
        # ----------------------------------------------------------------
        workout_days = body.get('workoutDays', [])
        day_items = []

        for day in workout_days:
            week_num = int(day.get('weekNumber', 1))
            day_num = int(day.get('dayNumber', 1))
            day_sk = f'{plan_id}#W{week_num:02d}#D{day_num}'

            day_item = {
                # Spread all AI-provided fields first, then override key fields
                **day,
                'userId': user_id,
                'planId': plan_id,
                'planWeekDay': day_sk,
                'weekNumber': week_num,
                'dayNumber': day_num,
                'isCompleted': False,
                'completedAt': None,
                'createdAt': now,
                'updatedAt': now,
            }
            # Remove any stale 'id' field the AI might have included
            day_item.pop('id', None)
            day_items.append(day_item)

        if day_items:
            db.batch_put_workout_days(day_items)

        # ----------------------------------------------------------------
        # 4. Mark onboarding complete
        # ----------------------------------------------------------------
        db.update_user(user_id, {
            'onboardingComplete': True,
            'activePlanId': plan_id,
            'updatedAt': now,
        })

        return created({
            'plan': plan_item,
            'totalDays': len(day_items),
            'message': f'Plan "{plan_item["planName"]}" created with {len(day_items)} workout days.',
        })

    except ValueError as e:
        return bad_request(str(e))
    except Exception as e:
        print(f'[plans/create] error: {e}')
        return error('Failed to create training plan')
