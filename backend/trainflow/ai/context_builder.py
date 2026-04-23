"""
Context snapshot builder.

Every AI request is pre-loaded with a baseline snapshot of the user's
current state so the AI doesn't need to call tools for the most common
data. The snapshot is injected into the system prompt.

Pre-loaded data (fetched in parallel conceptually, sequentially in practice
since we're inside a Lambda):
  - User profile
  - Active training plan
  - Current week's workout days
  - Today's workout day (if any)
  - Last 7 days of HealthKit records
  - Last 3 completed workout logs
"""

from datetime import date, timedelta

from trainflow.shared.db import db


def build_context_snapshot(user_id: str) -> dict:
    """
    Fetch and assemble the baseline context for an AI request.

    Returns a dict with keys:
        profile             – user record from tf-users (or {})
        activePlan          – currently active plan (or None)
        currentWeekWorkouts – list of workout day dicts for the current week
        todayWorkout        – today's workout day dict (or None)
        recentHealth        – last 7 days of health records (newest last)
        recentWorkouts      – last 3 completed workout logs
    """
    context: dict = {}

    # ------------------------------------------------------------------
    # 1. User profile
    # ------------------------------------------------------------------
    profile = db.get_user(user_id)
    context['profile'] = profile or {}

    # ------------------------------------------------------------------
    # 2. Active plan + current week
    # ------------------------------------------------------------------
    active_plan = db.get_active_plan(user_id)
    if active_plan:
        context['activePlan'] = active_plan
        current_week = int(active_plan.get('currentWeek', 1))
        plan_id = active_plan['planId']

        week_days = db.get_workout_days_for_week(user_id, plan_id, current_week)
        context['currentWeekWorkouts'] = week_days

        today = date.today().isoformat()
        today_workout = next(
            (d for d in week_days if d.get('scheduledDate') == today),
            None,
        )
        context['todayWorkout'] = today_workout
    else:
        context['activePlan'] = None
        context['currentWeekWorkouts'] = []
        context['todayWorkout'] = None

    # ------------------------------------------------------------------
    # 3. Last 7 days of HealthKit data
    # ------------------------------------------------------------------
    today_str = date.today().isoformat()
    week_ago_str = (date.today() - timedelta(days=7)).isoformat()
    health_records = db.get_health_data_range(user_id, week_ago_str, today_str)
    context['recentHealth'] = health_records  # chronological, newest last

    # ------------------------------------------------------------------
    # 4. Last 7 workouts (TrainFlow logs + HealthKit synced workouts)
    # ------------------------------------------------------------------
    recent_workouts = db.get_workouts(user_id, limit=7)
    context['recentWorkouts'] = recent_workouts  # newest first

    return context
