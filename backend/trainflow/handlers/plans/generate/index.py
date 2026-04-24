"""
Async plan generation Lambda — invoked by tf-chat-message with InvocationType=Event.

Uses gpt-5.4 (primary model, no output token cap) to generate the complete training
schedule in a single API call, then batch-writes all days to DynamoDB.
"""

import sys
sys.path.insert(0, '/opt/python')

import re
import json
from datetime import datetime, date, timedelta, timezone

from trainflow.shared.db import db
from trainflow.ai.openai_client import invoke_plan

_WEEKDAY_NAMES = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']


def _date_for_week_day(start_date_str: str, week_num: int, day_num: int) -> str:
    try:
        start = date.fromisoformat(start_date_str)
    except ValueError:
        start = date.today()
    delta = (week_num - 1) * 7 + (day_num - 1)
    return (start + timedelta(days=delta)).isoformat()


def _parse_rest_weekdays(user_context: str) -> set:
    """Return a set of weekday indices (0=Mon..6=Sun) that the user wants as rest days."""
    rest_days = set()
    ctx = user_context.lower()
    # Patterns: "rest on mondays", "no training on friday", "monday is rest", "off on sundays"
    for i, name in enumerate(_WEEKDAY_NAMES):
        plural = name + 's'
        if re.search(r'\b(rest|off|no.{0,10}train|recovery)\b.{0,20}\b' + name + r's?\b', ctx):
            rest_days.add(i)
        elif re.search(r'\b' + name + r's?\b.{0,20}\b(rest|off|no.{0,10}train|recovery)\b', ctx):
            rest_days.add(i)
    return rest_days


SYSTEM_PROMPT = (
    "You are an elite running and fitness coach generating a complete training schedule as JSON. "
    "Return ONLY a valid JSON array — no markdown fences, no explanation, no trailing text. "
    "Each element represents one day.\n\n"
    "ALL days must have: weekNumber (int), dayNumber (int 1–7, sequential within the week where D1 is "
    "the plan start date and D7 is 6 days later — the user prompt shows the exact day-of-week for each dayNumber), "
    "scheduledDate (YYYY-MM-DD), title (str), type (str), isRestDay (bool).\n\n"
    "REST DAY CONSTRAINTS: The user prompt lists a 'Day-of-week map' and any mandatory rest weekdays. "
    "You MUST mark every dayNumber that falls on a mandatory rest weekday as isRestDay=true across ALL weeks. "
    "This is non-negotiable — never schedule a training session on a mandatory rest day.\n\n"
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

    # Build day-of-week map: D1..D7 → actual weekday names for this start date
    try:
        start_dt = date.fromisoformat(start_date)
    except ValueError:
        start_dt = date.today()
    day_of_week_map = ', '.join([
        f'D{i + 1}={(start_dt + timedelta(days=i)).strftime("%A")}'
        for i in range(7)
    ])

    # Parse mandatory rest weekdays from userContext and build hard constraint string
    rest_weekday_indices = _parse_rest_weekdays(user_context)
    if rest_weekday_indices:
        rest_day_numbers = sorted(
            ((wd - start_dt.weekday()) % 7) + 1
            for wd in rest_weekday_indices
        )
        rest_weekday_names = [_WEEKDAY_NAMES[i].capitalize() for i in sorted(rest_weekday_indices)]
        rest_constraint = (
            f"\nMANDATORY REST DAYS: The athlete requires rest on {', '.join(rest_weekday_names)}. "
            f"Based on the day-of-week map above, these are dayNumber(s): {rest_day_numbers}. "
            f"Mark EVERY occurrence of these dayNumbers across ALL {total_weeks} weeks as isRestDay=true. "
            f"Do NOT place any training on these days under any circumstances."
        )
    else:
        rest_constraint = ''

    prompt = (
        f"Generate the complete {total_weeks}-week {goal_type} training plan.\n"
        f"Plan starts: {start_date}. Training days per week: {days_per_week}.\n"
        f"Day-of-week map: {day_of_week_map}.\n"
        f"User context: {user_context}{rest_constraint}\n\n"
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

            # Post-process: enforce mandatory rest weekdays regardless of model output
            if rest_weekday_indices:
                overridden = 0
                for day in all_days:
                    sdate = day.get('scheduledDate') or _date_for_week_day(
                        start_date,
                        int(day.get('weekNumber', 1)),
                        int(day.get('dayNumber', 1)),
                    )
                    try:
                        swd = date.fromisoformat(sdate).weekday()  # 0=Mon..6=Sun
                    except ValueError:
                        continue
                    if swd in rest_weekday_indices and not day.get('isRestDay'):
                        day['isRestDay'] = True
                        day['type'] = 'rest'
                        day['title'] = 'Rest Day'
                        day.pop('distance', None)
                        day.pop('duration', None)
                        day.pop('targetPace', None)
                        day.pop('targetHRZone', None)
                        day.pop('warmup', None)
                        day.pop('mainSet', None)
                        day.pop('cooldown', None)
                        day.pop('exercises', None)
                        if not day.get('coachMessage'):
                            day['coachMessage'] = 'Rest. Recover. Come back harder tomorrow.'
                        overridden += 1
                if overridden:
                    print(f'[plan/generate] Enforced rest on {overridden} day(s) matching mandatory weekday constraints')

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
