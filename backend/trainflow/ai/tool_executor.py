"""
Tool executor for the TrainFlow AI coach.

Each tool name defined in tools.py has a corresponding branch here.
Results are returned as plain Python dicts; the caller serialises them to
JSON before passing them back to the model as tool result messages.
"""

import json
from datetime import date, datetime, timedelta, timezone

from trainflow.shared.db import db


def _invoke_plan_generate_async(plan_id: str, user_id: str, plan_meta: dict, user_context: str) -> None:
    """Fire-and-forget: invoke tf-plan-generate Lambda asynchronously (InvocationType=Event)."""
    import boto3 as _boto3
    import os as _os

    payload = json.dumps({
        'planId': plan_id,
        'userId': user_id,
        'planMeta': plan_meta,
        'userContext': user_context,
    }).encode()

    region = _os.environ.get('AWS_REGION', 'ap-south-1')
    client = _boto3.client('lambda', region_name=region)
    client.invoke(
        FunctionName='tf-plan-generate',
        InvocationType='Event',  # async — returns 202 immediately
        Payload=payload,
    )
    print(f'[tool_executor] tf-plan-generate invoked async for plan {plan_id}')


def execute_tool(tool_name: str, tool_input: dict, user_id: str) -> dict:
    """
    Dispatch a tool call and return the result as a plain dict.

    Parameters
    ----------
    tool_name   : Name of the tool (matches TOOLS list in tools.py)
    tool_input  : Parsed JSON input from the tool call arguments
    user_id     : Cognito sub of the authenticated user

    Returns a dict. On success this is the data; on failure it contains
    an 'error' key with a message. The caller should not raise — returning
    an error dict lets the AI handle it gracefully.
    """

    # ------------------------------------------------------------------
    # get_user_profile
    # ------------------------------------------------------------------
    if tool_name == 'get_user_profile':
        profile = db.get_user(user_id)
        return profile or {'error': 'Profile not found'}

    # ------------------------------------------------------------------
    # get_active_plan
    # ------------------------------------------------------------------
    elif tool_name == 'get_active_plan':
        plan = db.get_active_plan(user_id)
        if not plan:
            return {'message': 'No active training plan found'}
        return plan

    # ------------------------------------------------------------------
    # get_week_workouts
    # ------------------------------------------------------------------
    elif tool_name == 'get_week_workouts':
        week_num = int(tool_input.get('week_number', 1))
        plan_id = tool_input.get('plan_id')

        if not plan_id:
            active = db.get_active_plan(user_id)
            if not active:
                return {'error': 'No active plan found'}
            plan_id = active['planId']

        days = db.get_workout_days_for_week(user_id, plan_id, week_num)
        return {'workoutDays': days, 'weekNumber': week_num, 'planId': plan_id}

    # ------------------------------------------------------------------
    # get_health_data
    # ------------------------------------------------------------------
    elif tool_name == 'get_health_data':
        days = min(int(tool_input.get('days', 7)), 90)
        end_date = date.today().isoformat()
        start_date = (date.today() - timedelta(days=days)).isoformat()
        records = db.get_health_data_range(user_id, start_date, end_date)
        return {
            'records': records,
            'days': days,
            'from': start_date,
            'to': end_date,
        }

    # ------------------------------------------------------------------
    # get_workout_history
    # ------------------------------------------------------------------
    elif tool_name == 'get_workout_history':
        days = min(int(tool_input.get('days', 14)), 90)
        workouts = db.get_workouts(user_id, limit=50)
        cutoff = datetime.now(timezone.utc) - timedelta(days=days)

        def _after_cutoff(w: dict) -> bool:
            ts = w.get('timestamp', '')
            if not ts:
                return False
            try:
                return datetime.fromisoformat(ts.replace('Z', '+00:00')) > cutoff
            except ValueError:
                return False

        filtered = [w for w in workouts if _after_cutoff(w)]
        return {'workouts': filtered, 'days': days}

    # ------------------------------------------------------------------
    # update_user_profile
    # ------------------------------------------------------------------
    elif tool_name == 'update_user_profile':
        updates = tool_input.get('updates', {})
        if not updates:
            return {'error': 'No updates provided'}

        updates['updatedAt'] = datetime.now(timezone.utc).isoformat()
        db.update_user(user_id, updates)
        return {'success': True, 'updated': list(updates.keys())}

    # ------------------------------------------------------------------
    # create_training_plan
    # ------------------------------------------------------------------
    elif tool_name == 'create_training_plan':
        import uuid as _uuid

        plan_data = tool_input.get('plan', {})
        user_context = tool_input.get('userContext', '')
        if not plan_data:
            return {'error': 'plan object is required'}

        required = ['planName', 'goalType', 'startDate', 'endDate', 'totalWeeks', 'daysPerWeek']
        missing = [f for f in required if not plan_data.get(f)]
        if missing:
            return {'error': f'Missing required plan fields: {missing}'}

        plan_id = str(_uuid.uuid4())
        now = datetime.now(timezone.utc).isoformat()
        total_weeks = min(int(plan_data['totalWeeks']), 8)  # hard cap — generator limit
        days_per_week = int(plan_data['daysPerWeek'])

        # fitnessLevel: prefer value passed in plan_data (from AI conversation),
        # fall back to whatever is already stored on the user profile
        user_profile = db.get_user(user_id) or {}
        fitness_level = (
            plan_data.get('fitnessLevel', '').strip()
            or user_profile.get('fitnessLevel', '').strip()
        )

        plan_item = {
            'userId': user_id,
            'planId': plan_id,
            'planName': plan_data['planName'],
            'goalType': plan_data['goalType'],
            'startDate': plan_data['startDate'],
            'endDate': plan_data['endDate'],
            'totalWeeks': total_weeks,
            'daysPerWeek': days_per_week,
            'currentWeek': 1,
            'isActive': 'true',
            'fitnessLevel': fitness_level,
            'createdAt': now,
            'updatedAt': now,
        }

        # Deactivate any existing active plan first
        existing_active = db.get_active_plan(user_id)
        if existing_active:
            db.update_plan(user_id, existing_active['planId'], {
                'isActive': 'false',
                'updatedAt': now,
            })

        db.put_plan(plan_item)
        print(f'[tool_executor] plan {plan_id} written for user {user_id}')

        # Invoke tf-plan-generate async — returns immediately, schedule is built in background
        _invoke_plan_generate_async(plan_id, user_id, plan_data, user_context)

        # Mark onboarding complete and persist fitnessLevel back to profile
        profile_updates: dict = {
            'onboardingComplete': True,
            'activePlanId': plan_id,
            'updatedAt': now,
        }
        if fitness_level:
            profile_updates['fitnessLevel'] = fitness_level
        db.update_user(user_id, profile_updates)

        return {
            'success': True,
            'planId': plan_id,
            'generating': True,
            'onboardingComplete': True,
            'message': 'Plan created! Your full workout schedule is being built and will be ready in about 30 seconds.',
        }

    # ------------------------------------------------------------------
    # adapt_training_plan
    # ------------------------------------------------------------------
    elif tool_name == 'adapt_training_plan':
        plan_id = tool_input.get('plan_id')
        changes = tool_input.get('changes', [])

        if not plan_id:
            return {'error': 'plan_id is required'}
        if not changes:
            return {'error': 'changes array must not be empty'}

        now = datetime.now(timezone.utc).isoformat()
        applied = 0

        skipped = 0
        for change in changes:
            day_sk = change.get('planWeekDay')
            updates = change.get('updates', {})
            if not day_sk:
                continue
            # Never modify already-completed workout days
            try:
                existing = db.get_workout_day(user_id, day_sk)
                if existing and existing.get('isCompleted'):
                    print(f'[tool_executor] skipping completed day {day_sk}')
                    skipped += 1
                    continue
            except Exception:
                pass
            updates['updatedAt'] = now
            try:
                db.update_workout_day(user_id, day_sk, updates)
                applied += 1
            except Exception as e:
                print(f'[tool_executor] adapt_training_plan failed for {day_sk}: {e}')

        return {
            'success': True,
            'changesApplied': applied,
            'skippedCompleted': skipped,
            'totalRequested': len(changes),
        }

    # ------------------------------------------------------------------
    # Unknown tool
    # ------------------------------------------------------------------
    return {'error': f'Unknown tool: {tool_name}'}
