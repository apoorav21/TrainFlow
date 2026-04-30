"""
System prompt builder for the TrainFlow AI coach.

The prompt is rebuilt on every request using the latest context snapshot
so the AI always has up-to-date information without tool calls for basic
facts (today's date, current plan, recent health metrics, etc.).
"""

from datetime import date


def build_system_prompt(context: dict) -> str:
    """
    Compose the full system prompt for an OpenAI chat completion.

    Parameters
    ----------
    context : Output of context_builder.build_context_snapshot()

    Returns
    -------
    str – Multi-line system prompt ready to pass as the `system` field.
    """
    profile = context.get('profile', {})
    _today = date.today()
    today = _today.isoformat()
    today_full = _today.strftime('%A, %d %B %Y')  # e.g. "Monday, 27 April 2026"

    # ------------------------------------------------------------------
    # Race info line
    # ------------------------------------------------------------------
    race_info = profile.get('raceInfo', {})
    race_str = ''
    if race_info and race_info.get('name'):
        race_str = (
            f"Target race: {race_info['name']} ({race_info.get('distance', '')}) "
            f"on {race_info.get('date', '')} in {race_info.get('location', '')}."
        )
        if race_info.get('previousTime'):
            race_str += f" Previous best: {race_info['previousTime']}."

    # ------------------------------------------------------------------
    # Location / climate line
    # ------------------------------------------------------------------
    location = profile.get('location', {})
    climate_str = ''
    if location.get('city'):
        climate_str = (
            f"Location: {location['city']}, {location.get('country', '')}. "
            f"Climate: {location.get('climateZone', 'temperate')}."
        )

    # ------------------------------------------------------------------
    # Health summary line (7-day averages from pre-loaded snapshot)
    # ------------------------------------------------------------------
    health_records = context.get('recentHealth', [])
    health_str = ''
    if health_records:
        hrv_values  = [r['hrv']        for r in health_records if r.get('hrv')]
        rhr_values  = [r['restingHR']  for r in health_records if r.get('restingHR')]
        steps_values = [r['steps']     for r in health_records if r.get('steps')]
        vo2_values  = [r['vo2max']     for r in health_records if r.get('vo2max')]
        ex_values   = [r['exerciseMinutes'] for r in health_records if r.get('exerciseMinutes')]

        avg_hrv   = sum(hrv_values)  / len(hrv_values)  if hrv_values  else None
        avg_rhr   = sum(rhr_values)  / len(rhr_values)  if rhr_values  else None
        avg_steps = sum(steps_values)/ len(steps_values)if steps_values else None
        latest_vo2 = vo2_values[-1]  if vo2_values  else None
        avg_ex    = sum(ex_values)   / len(ex_values)   if ex_values   else None

        parts = []
        if avg_rhr is not None:
            parts.append(f'avg resting HR {avg_rhr:.0f} bpm')
        if avg_hrv is not None:
            parts.append(f'avg HRV {avg_hrv:.1f} ms')
        if avg_steps is not None:
            parts.append(f'avg {avg_steps:,.0f} steps/day')
        if avg_ex is not None:
            parts.append(f'avg {avg_ex:.0f} min exercise/day')
        if latest_vo2 is not None:
            parts.append(f'VO₂ max {latest_vo2:.1f} ml/kg/min')

        if parts:
            health_str = f"Last 7 days health: {', '.join(parts)}."

        # Last night's sleep — full stage breakdown
        latest = health_records[-1] if health_records else {}
        sleep_data = latest.get('sleepData') or {}
        if sleep_data.get('totalMinutes'):
            total_hrs  = sleep_data['totalMinutes'] / 60
            deep_mins  = sleep_data.get('deepMinutes')
            rem_mins   = sleep_data.get('remMinutes')
            core_mins  = sleep_data.get('coreMinutes')
            awake_mins = sleep_data.get('awakeMinutes')
            rr         = sleep_data.get('respiratoryRate')
            spo2       = sleep_data.get('bloodOxygen')

            sleep_parts = [f'{total_hrs:.1f} hrs total']
            if deep_mins is not None:
                sleep_parts.append(f'{deep_mins:.0f} min deep')
            if rem_mins is not None:
                sleep_parts.append(f'{rem_mins:.0f} min REM')
            if core_mins is not None:
                sleep_parts.append(f'{core_mins:.0f} min core')
            if awake_mins is not None:
                sleep_parts.append(f'{awake_mins:.0f} min awake')
            if rr is not None:
                sleep_parts.append(f'resp rate {rr:.1f}/min')
            if spo2 is not None:
                sleep_parts.append(f'SpO₂ {spo2:.0f}%')

            health_str += f" Last night sleep: {', '.join(sleep_parts)}."

    # ------------------------------------------------------------------
    # Recent workouts summary (TrainFlow logs + HealthKit synced workouts)
    # ------------------------------------------------------------------
    recent_workouts = context.get('recentWorkouts', [])
    workouts_str = ''
    if recent_workouts:
        parts = []
        for w in recent_workouts[:5]:
            wtype = w.get('workoutType', 'Workout')
            source = w.get('source', 'trainflow')
            dist = w.get('distanceKm') or w.get('actualDistance')
            dur = w.get('durationMin') or w.get('actualDurationMin')
            effort = w.get('effortRating')
            date_raw = w.get('startDate') or w.get('scheduledDate') or w.get('timestamp', '')
            date_short = date_raw[:10] if date_raw else '?'
            label = f"{date_short} {wtype}"
            if dist:
                label += f" {float(dist):.1f}km"
            if dur:
                label += f" {int(float(dur))}min"
            if effort is not None:
                effort_int = int(float(effort))
                effort_words = (
                    "very easy" if effort_int <= 2 else
                    "easy" if effort_int <= 3 else
                    "moderate" if effort_int <= 5 else
                    "hard" if effort_int <= 7 else
                    "very hard" if effort_int <= 9 else
                    "max effort"
                )
                label += f" RPE {effort_int}/10 ({effort_words})"
            if source == 'healthkit':
                src_name = w.get('sourceName', '')
                label += f" (via {src_name})" if src_name else " (HealthKit)"
            parts.append(label)
        if parts:
            workouts_str = "Recent activity: " + "; ".join(parts) + "."

    # ------------------------------------------------------------------
    # Plan summary line
    # ------------------------------------------------------------------
    plan = context.get('activePlan')
    plan_str = ''
    if plan:
        plan_str = (
            f"Active plan: {plan.get('planName', 'Training Plan')}, "
            f"Week {plan.get('currentWeek', 1)} of {plan.get('totalWeeks', 12)}."
        )

    # ------------------------------------------------------------------
    # Today's workout line
    # ------------------------------------------------------------------
    today_workout = context.get('todayWorkout')
    today_str = ''
    if today_workout:
        if today_workout.get('isRestDay'):
            today_str = 'Today is a rest day.'
        else:
            main = today_workout.get('mainWorkout', {})
            title = today_workout.get('title', '')
            dist = main.get('distance', '')
            pace = main.get('targetPace', '')
            today_str = f"Today's workout: {title}"
            if dist:
                today_str += f' — {dist}'
            if pace:
                today_str += f' at {pace}'
            today_str += '.'

    # ------------------------------------------------------------------
    # Onboarding instructions (shown only when onboarding is incomplete)
    # ------------------------------------------------------------------
    onboarding_complete = profile.get('onboardingComplete', False)
    onboarding_instructions = ''
    if not onboarding_complete:
        onboarding_instructions = """
ONBOARDING MODE: This user has not yet been set up. Your primary goal is to gather
all necessary information and create their first training plan.

Guide them through these topics naturally in conversation (not as a numbered list):
1. What are they training for? (specific race, general fitness, weight loss, etc.)
2. If racing: race name, date, location, distance, elevation, previous best time
3. Current fitness level and typical weekly training volume
4. How many days per week can they train
5. Any injuries or physical limitations
6. Specific goals (finish, hit a time target, set a PR, etc.)

As they share information, save it progressively with update_user_profile.
Once you have everything, call create_training_plan with the COMPLETE plan object.

When calling create_training_plan, provide:
  - plan: { planName, goalType, startDate (MUST be {today} — today is {today_full}; do NOT round up to the nearest Monday or start of week), endDate, totalWeeks, daysPerWeek, fitnessLevel (e.g. 'beginner', 'intermediate', 'advanced', 'elite') }
  - userContext: a concise summary of everything about the user (fitness level, goal,
    target race/time, injuries, weekly volume, preferences)

HARD LIMIT: totalWeeks MUST be 8 or less. If the user asks for a longer plan, tell them
straight — no coddling: "Plans are capped at 8 weeks. We're going to hammer these first
8 weeks, build the foundation, and then build the next block from there. That's how
champions are made." Then set totalWeeks to 8 and endDate to startDate + 56 days.

Do NOT generate workoutDays yourself — the schedule is generated automatically.
Just pass the plan metadata and user context. Be thorough in userContext so the
schedule reflects the user's specific situation.

After creating the plan, give the user a brief overview of their plan structure.
"""

    # ------------------------------------------------------------------
    # Assemble the full prompt (strip empty lines from optional sections)
    # ------------------------------------------------------------------
    lines = [
        "You are David Goggins — the world's toughest endurance athlete, former Navy SEAL, "
        "ultra-marathon runner, and the hardest man alive. You are now coaching athletes "
        "through the TrainFlow app. You have elite expertise in periodization, HealthKit "
        "metrics, and personalised training — but you deliver it with zero tolerance for "
        "excuses, weakness, or mediocrity.",
        "",
        "Your coaching philosophy:",
        "- Callous the mind. Comfort is the enemy of growth.",
        "- You don't coddle. You tell the truth, even when it hurts.",
        "- 'Who's gonna carry the boats?' The answer is them. Always them.",
        "- You celebrate real effort and call out laziness without hesitation.",
        "- Stay hard. Every single day.",
        "- You back up intensity with precise science — data doesn't lie, and neither do you.",
        "",
        f"Today: {today} ({today_full})",
        f"Athlete: {profile.get('name', 'Athlete')}",
    ]

    if profile.get('fitnessLevel'):
        lines.append(f"Current fitness level: {profile['fitnessLevel']}")
    if race_str:
        lines.append(race_str)
    if climate_str:
        lines.append(climate_str)
    if profile.get('injuries'):
        lines.append(f"Physical limitations: {profile['injuries']}")
    if plan_str:
        lines.append(plan_str)
    if health_str:
        lines.append(health_str)
    if workouts_str:
        lines.append(workouts_str)
    if today_str:
        lines.append(today_str)
    if onboarding_instructions:
        lines.append(onboarding_instructions)

    lines += [
        "",
        "You have access to tools to fetch data, update profiles, and manage "
        "training plans. Use them ONLY when you need specific information NOT "
        "already in this prompt. This prompt pre-loads your recent health data, "
        "last 7 workouts, and today's workout — do NOT call get_health_data or "
        "get_workout_history for analyses of recent activity. Only call tools "
        "for data older than 7 days, plan creation, or plan adaptation.",
        "",
        "When giving training advice:",
        "- Factor in climate — heat and humidity are no excuse to quit, but they are "
        "  real variables that change the training load. Acknowledge them and adapt.",
        "- Cite their actual HealthKit numbers. If their HRV crashed, call it out. "
        '  "Your HRV dropped 15% — your body is telling you something. Listen or break."',
        "- Be brutally specific. Generic advice is cowardice. Give exact paces, zones, "
        "  distances. No vague 'run a little easy today' nonsense.",
        "- For plan adaptations, always call adapt_training_plan to make the changes real. "
        "  NEVER include already-completed days (isCompleted=true) in the changes array. "
        "  Only modify future uncompleted days. "
        "  When MOVING a workout (e.g. 'swap day A and B', 'move yesterday\\'s long run to today'): "
        "  include ALL fields of the source workout in the target day\\'s updates — title, type, "
        "  isRestDay, distance, duration, targetPace, targetHRZone, warmup, mainSet, cooldown, coachMessage. "
        "  When CONVERTING a day to rest: set isRestDay=true, type=\\'rest\\', title=\\'Rest Day\\'. "
        "  When CONVERTING rest to workout: set isRestDay=false plus all workout fields. "
        "  Partial changes (adjust pace, update note) only need the changed fields.",
        "- When they complete a hard session, acknowledge it — but remind them the real "
        "  work is showing up tomorrow.",
        "- When they make excuses, call it out directly but constructively. "
        "  Redirect them back to the mission.",
        "",
        "Tone: Direct, intense, no fluff. Short sentences hit harder. "
        "No bullet-point walls of text — this is a mobile chat. "
        "Sign off with 'Stay hard.' when it feels right, but don't force it every message.",
    ]

    return '\n'.join(lines)
