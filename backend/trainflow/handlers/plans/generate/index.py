"""
Async plan generation Lambda — invoked by tf-chat-message with InvocationType=Event.

Uses gpt-5.4 (primary model, no output token cap) to generate the complete training
schedule in a single API call, then batch-writes all days to DynamoDB.
"""

import sys
sys.path.insert(0, '/opt/python')

import json
from datetime import datetime, date, timedelta, timezone

from trainflow.shared.db import db
from trainflow.ai.openai_client import invoke_plan


def _date_for_week_day(start_date_str: str, week_num: int, day_num: int) -> str:
    try:
        start = date.fromisoformat(start_date_str)
    except ValueError:
        start = date.today()
    delta = (week_num - 1) * 7 + (day_num - 1)
    return (start + timedelta(days=delta)).isoformat()


SYSTEM_PROMPT = (
    "You are an elite running and fitness coach generating a complete training schedule as JSON. "
    "Return ONLY a valid JSON array — no markdown fences, no explanation, no trailing text. "
    "Each element represents one day.\n\n"
    "ALL days must have: weekNumber (int), dayNumber (int 1=Mon..7=Sun), "
    "scheduledDate (YYYY-MM-DD), title (str), type (str), isRestDay (bool).\n\n"
    "REST days: type='rest', isRestDay=true, coachMessage (1 motivating sentence).\n\n"
    "HR ZONE REFERENCE: Z1=recovery(<60%), Z2=aerobic(60-70%), Z3=tempo(70-80%), Z4=threshold(80-90%), Z5=max(>90%).\n"
    "EVERY section (warmup, mainSet, cooldown) and EVERY interval MUST include hrZone (int 1-5). No exceptions.\n\n"
    "RUN days: type='run'|'long_run'|'tempo'|'interval'|'easy'|'recovery', isRestDay=false. Also include:\n"
    "  distance (str e.g. '10 km'), duration (str e.g. '55 min'),\n"
    "  targetPace (str e.g. '5:30/km'), targetHRZone (int 1-5),\n"
    "  warmup: {durationMin: int, description: str, targetPace: str, hrZone: int [REQUIRED]},\n"
    "  mainSet: {description: str, hrZone: int [REQUIRED], intervals: [{type: 'work'|'rest'|'recovery', "
    "durationMin: float, distanceKm: float (optional), "
    "targetPace: str, hrZone: int [REQUIRED], notes: str}]},\n"
    "  cooldown: {durationMin: int, description: str, targetPace: str, hrZone: int [REQUIRED]},\n"
    "  coachMessage (str — specific coaching cue for THIS session, 1-2 sentences).\n\n"
    "STRENGTH days: type='strength', isRestDay=false. Also include:\n"
    "  duration (str), targetHRZone (int, use 2),\n"
    "  warmup: {durationMin: int, description: str, hrZone: 2},\n"
    "  exercises: [{name: str, sets: int, reps: str, restSec: int, notes: str (optional)}],\n"
    "  cooldown: {durationMin: int, description: str, hrZone: 1},\n"
    "  coachMessage (str).\n\n"
    "CROSS_TRAINING days: type='cross_training', isRestDay=false. Also include:\n"
    "  duration (str), targetHRZone (int 1-3),\n"
    "  warmup: {durationMin: int, description: str, hrZone: int [REQUIRED]},\n"
    "  mainSet: {description: str, hrZone: int [REQUIRED], intervals: [{type: str, durationMin: float, hrZone: int [REQUIRED], notes: str}]},\n"
    "  cooldown: {durationMin: int, description: str, hrZone: int [REQUIRED]},\n"
    "  coachMessage (str).\n\n"
    "intervals arrays must be complete and specific — include exact reps, distances, paces, rest durations. "
    "Produce every single day — do NOT truncate, summarise, or use '...'."
)


def handler(event, context):
    plan_id = event.get('planId')
    user_id = event.get('userId')
    plan_meta = event.get('planMeta', {})
    user_context = event.get('userContext', '')

    if not plan_id or not user_id:
        print('[plan/generate] Missing planId or userId')
        return

    total_weeks = int(plan_meta.get('totalWeeks', 12))
    days_per_week = int(plan_meta.get('daysPerWeek', 4))
    start_date = plan_meta.get('startDate', date.today().isoformat())
    goal_type = plan_meta.get('goalType', 'running')
    total_days = total_weeks * 7

    print(f'[plan/generate] Generating {total_weeks}-week plan {plan_id} ({total_days} days)')

    prompt = (
        f"Generate the complete {total_weeks}-week {goal_type} training plan.\n"
        f"Plan starts: {start_date}. Training days per week: {days_per_week}.\n"
        f"User context: {user_context}\n\n"
        f"Return exactly {total_days} day objects (ALL weeks 1–{total_weeks}, ALL days 1–7 each week). "
        f"Apply progressive overload, include deload/taper weeks, vary workout types. "
        f"Make warmup/cooldown and intervals SPECIFIC to each session — not generic filler."
    )

    for attempt in range(3):
        try:
            print(f'[plan/generate] Attempt {attempt + 1}: calling gpt-5.4')
            response = invoke_plan(
                messages=[{"role": "user", "content": prompt}],
                system=SYSTEM_PROMPT,
            )
            raw = (response.choices[0].message.content or '').strip()
            if raw.startswith('```'):
                raw = raw.split('\n', 1)[1] if '\n' in raw else raw[3:]
                raw = raw.rsplit('```', 1)[0].strip()

            all_days = json.loads(raw)
            if not isinstance(all_days, list) or not all_days:
                raise ValueError(f'Expected list, got {type(all_days)}')

            print(f'[plan/generate] Received {len(all_days)} days from model')
            break
        except Exception as e:
            print(f'[plan/generate] Attempt {attempt + 1} failed: {e}')
            if attempt == 2:
                print('[plan/generate] All attempts failed — aborting')
                return
            all_days = []

    now = datetime.now(timezone.utc).isoformat()
    day_items = []
    for day in all_days:
        try:
            week_num = int(day.get('weekNumber', 1))
            day_num = int(day.get('dayNumber', 1))
            if not day.get('scheduledDate'):
                day['scheduledDate'] = _date_for_week_day(start_date, week_num, day_num)
            day_sk = f'{plan_id}#W{week_num:02d}#D{day_num}'
            item = {
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
            item.pop('id', None)
            day_items.append(item)
        except Exception as e:
            print(f'[plan/generate] Skipping malformed day: {e}')

    if not day_items:
        print('[plan/generate] No valid days to write — aborting')
        return

    db.batch_put_workout_days(day_items)

    try:
        db.update_plan(user_id, plan_id, {
            'totalDays': len(day_items),
            'scheduleReady': True,
            'updatedAt': now,
        })
    except Exception as e:
        print(f'[plan/generate] Could not update plan metadata: {e}')

    print(f'[plan/generate] Done — {len(day_items)} days stored for plan {plan_id}')
