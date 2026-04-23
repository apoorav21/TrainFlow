"""
POST /workouts/report

Generates an AI post-workout report for a completed workout session.

Expected body:
{
    "planId": "...",
    "workoutDayId": "planId#W01#D3",
    "elapsedSeconds": 3420,
    "avgHeartRate": 152.0,
    "peakHeartRate": 178.0,
    "calories": 380.0,
    "distance": 8.5,
    "avgPace": 6.7          <- min/km, optional
}

Returns:
{
    "planWeekDay": "...",
    "aiReport": "...",
    "generatedAt": "..."
}
"""

import sys
sys.path.insert(0, '/opt/python')

from datetime import datetime, timezone

from trainflow.shared.auth import extract_user_id
from trainflow.shared.db import db
from trainflow.shared.response import ok, bad_request, error
from trainflow.shared.validators import parse_body, require_fields
from trainflow.ai.openai_client import invoke_secondary


def _fmt_duration(seconds: int) -> str:
    h, rem = divmod(int(seconds), 3600)
    m, s = divmod(rem, 60)
    if h:
        return f'{h}h {m}m {s}s'
    return f'{m}m {s}s'


def _fmt_pace(min_per_km: float) -> str:
    if not min_per_km or min_per_km <= 0:
        return 'N/A'
    minutes = int(min_per_km)
    seconds = int((min_per_km - minutes) * 60)
    return f'{minutes}:{seconds:02d}/km'


def handler(event, context):
    try:
        user_id = extract_user_id(event)
        body = parse_body(event)
        require_fields(body, ['workoutDayId'])

        day_sk = body['workoutDayId']
        plan_id = body.get('planId', '')

        # Fetch the planned workout day for context
        day = None
        if plan_id:
            try:
                day = db.get_workout_day(user_id, day_sk)
            except Exception as e:
                print(f'[workout/report] Could not fetch day {day_sk}: {e}')

        elapsed_sec = int(body.get('elapsedSeconds', 0))
        avg_hr = float(body.get('avgHeartRate', 0))
        peak_hr = float(body.get('peakHeartRate', 0))
        calories = float(body.get('calories', 0))
        distance_km = float(body.get('distance', 0))
        avg_pace = float(body.get('avgPace', 0))

        # Build context strings
        actual_parts = [
            f'Duration: {_fmt_duration(elapsed_sec)}',
        ]
        if distance_km > 0:
            actual_parts.append(f'Distance: {distance_km:.2f} km')
        if avg_hr > 0:
            actual_parts.append(f'Avg HR: {int(avg_hr)} bpm')
        if peak_hr > 0:
            actual_parts.append(f'Peak HR: {int(peak_hr)} bpm')
        if calories > 0:
            actual_parts.append(f'Calories: {int(calories)} kcal')
        if avg_pace > 0:
            actual_parts.append(f'Avg Pace: {_fmt_pace(avg_pace)}')

        planned_parts = []
        if day:
            if day.get('title'):
                planned_parts.append(f'Session: {day["title"]}')
            if day.get('targetPace'):
                planned_parts.append(f'Target Pace: {day["targetPace"]}')
            if day.get('targetHRZone'):
                planned_parts.append(f'Target HR Zone: {day["targetHRZone"]}')
            if day.get('distance'):
                planned_parts.append(f'Target Distance: {day["distance"]}')
            if day.get('duration'):
                planned_parts.append(f'Target Duration: {day["duration"]}')
            if day.get('coachMessage'):
                planned_parts.append(f'Coach pre-session note: {day["coachMessage"]}')

        system = (
            "You are an elite running and fitness coach providing a post-workout analysis. "
            "Write in a warm, encouraging but honest coaching voice. Be specific — reference actual numbers. "
            "Keep the report under 300 words. Do not use markdown headers or bullet points — write in flowing paragraphs.\n\n"
            "After the report, on a NEW LINE write exactly: NEXT_WORKOUT_SUGGESTION: followed by a single actionable "
            "sentence suggesting a specific change to the NEXT workout if needed (e.g. 'Reduce the main set by one "
            "interval and extend the cooldown by 5 minutes to allow better recovery.' or 'No changes needed — "
            "proceed as planned.'). This line is parsed programmatically so keep it on one line."
        )

        prompt = (
            "Generate a post-workout report for this athlete.\n\n"
            f"ACTUAL PERFORMANCE:\n{chr(10).join(actual_parts)}\n\n"
        )
        if planned_parts:
            prompt += f"PLANNED SESSION:\n{chr(10).join(planned_parts)}\n\n"

        prompt += (
            "Report sections: (1) overall performance vs targets, "
            "(2) heart rate zone analysis, "
            "(3) one thing done well, "
            "(4) one focus area for next session, "
            "(5) 24-hour recovery recommendation. "
            "Then add the NEXT_WORKOUT_SUGGESTION line."
        )

        response = invoke_secondary(
            messages=[{"role": "user", "content": prompt}],
            system=system,
            max_tokens=700,
        )
        full_text = (response.choices[0].message.content or '').strip()

        # Split report from next-workout suggestion
        next_suggestion = None
        ai_report = full_text
        marker = 'NEXT_WORKOUT_SUGGESTION:'
        if marker in full_text:
            parts = full_text.split(marker, 1)
            ai_report = parts[0].strip()
            next_suggestion = parts[1].strip()

        now = datetime.now(timezone.utc).isoformat()

        updates = {
            'aiReport': ai_report,
            'aiReportGeneratedAt': now,
            'updatedAt': now,
        }
        if next_suggestion:
            updates['nextWorkoutSuggestion'] = next_suggestion

        try:
            db.update_workout_day(user_id, day_sk, updates)
        except Exception as e:
            print(f'[workout/report] Could not store report: {e}')

        result = {
            'planWeekDay': day_sk,
            'aiReport': ai_report,
            'generatedAt': now,
        }
        if next_suggestion:
            result['nextWorkoutSuggestion'] = next_suggestion

        return ok(result)

    except ValueError as e:
        return bad_request(str(e))
    except Exception as e:
        print(f'[workout/report] error: {e}')
        return error('Failed to generate workout report')
