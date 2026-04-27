"""
Tool definitions for the TrainFlow AI coach (OpenAI function-calling format).

These are passed directly to the `tools` parameter of every OpenAI invocation.
The AI uses them to fetch data, update the user's profile, and manage training plans.
"""

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "get_user_profile",
            "description": (
                "Get the user's complete profile including name, goals, race information, "
                "location/climate zone, fitness level, injuries, and whether onboarding is complete. "
                "Call this when you need to understand who the user is."
            ),
            "parameters": {
                "type": "object",
                "properties": {},
                "required": [],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_active_plan",
            "description": (
                "Get the user's currently active training plan metadata including plan name, "
                "goal, start/end dates, and current week number."
            ),
            "parameters": {
                "type": "object",
                "properties": {},
                "required": [],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_week_workouts",
            "description": (
                "Get all workout days for a specific week of the training plan. "
                "Returns full workout details including warmup, main workout, cooldown, "
                "and coach message."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "week_number": {
                        "type": "integer",
                        "description": "The week number to fetch (1-indexed).",
                    },
                    "plan_id": {
                        "type": "string",
                        "description": "The plan ID. If not provided, uses the active plan.",
                    },
                },
                "required": ["week_number"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_health_data",
            "description": (
                "Get HealthKit health metrics for the last N days. "
                "Returns resting heart rate, HRV, VO2 max, sleep quality, steps, weight, "
                "and other metrics."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "days": {
                        "type": "integer",
                        "description": "Number of days to look back (default 7, max 90).",
                    },
                },
                "required": [],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_workout_history",
            "description": (
                "Get the user's workout history for the last N days. "
                "Includes both TrainFlow-logged workouts (with effort rating and notes) "
                "and workouts synced from HealthKit / Apple Workout app (source='healthkit'). "
                "HealthKit workouts have workoutType, distanceKm, durationMin, calories, sourceName fields."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "days": {
                        "type": "integer",
                        "description": "Number of days to look back (default 14, max 90).",
                    },
                },
                "required": [],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "update_user_profile",
            "description": (
                "Update the user's profile with new information. Use this during onboarding "
                "to save answers as the user provides them. Can update any profile fields "
                "including raceInfo, goals, fitnessLevel, daysPerWeek, injuries, preferences, "
                "onboardingComplete."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "updates": {
                        "type": "object",
                        "description": (
                            "Key-value pairs to update. For nested objects like raceInfo, "
                            "provide the full nested object."
                        ),
                    },
                },
                "required": ["updates"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "create_training_plan",
            "description": (
                "Generate and store a complete training plan for the user. "
                "Call this only after you have gathered all necessary information. "
                "Provide plan metadata and user context — the workout schedule will "
                "be generated automatically. Do NOT include workoutDays."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "plan": {
                        "type": "object",
                        "description": "Plan metadata.",
                        "properties": {
                            "planName": {
                                "type": "string",
                                "description": "Descriptive plan name, e.g. '12-Week Half Marathon Plan'.",
                            },
                            "goalType": {
                                "type": "string",
                                "description": "e.g. 'half_marathon', 'marathon', '5k', 'general_fitness'.",
                            },
                            "startDate": {
                                "type": "string",
                                "description": "ISO date YYYY-MM-DD when the plan begins (today).",
                            },
                            "endDate": {
                                "type": "string",
                                "description": "ISO date YYYY-MM-DD when the plan ends.",
                            },
                            "totalWeeks": {
                                "type": "integer",
                                "description": "Total number of weeks in the plan.",
                            },
                            "daysPerWeek": {
                                "type": "integer",
                                "description": "Number of training days per week (rest days fill the remainder).",
                            },
                            "fitnessLevel": {
                                "type": "string",
                                "description": "User's current fitness level, e.g. 'beginner', 'intermediate', 'advanced', 'elite'.",
                            },
                        },
                        "required": ["planName", "goalType", "startDate", "endDate", "totalWeeks", "daysPerWeek"],
                    },
                    "userContext": {
                        "type": "string",
                        "description": (
                            "Free-text summary of everything relevant about the user: "
                            "fitness level, race goal, target time, injuries, preferences, "
                            "weekly volume. This is used to personalise the workout schedule."
                        ),
                    },
                },
                "required": ["plan", "userContext"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "adapt_training_plan",
            "description": (
                "Modify specific workout days in the current training plan. "
                "Use this when the user asks to change, swap, reduce, or adjust specific workouts. "
                "To convert a rest day to a workout, you MUST set isRestDay=false AND type to the "
                "workout type AND provide warmup/mainSet/cooldown. "
                "Already-completed days are skipped automatically."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "plan_id": {
                        "type": "string",
                        "description": "The plan ID to adapt.",
                    },
                    "changes": {
                        "type": "array",
                        "description": "Array of workout day updates.",
                        "items": {
                            "type": "object",
                            "properties": {
                                "planWeekDay": {
                                    "type": "string",
                                    "description": "The planWeekDay sort key, e.g. '{planId}#W01#D3'.",
                                },
                                "updates": {
                                    "type": "object",
                                    "description": (
                                        "Fields to update. Use EXACT field names from the workout day schema:\n"
                                        "  title (str) — short display name\n"
                                        "  type (str) — 'run'|'long_run'|'tempo'|'interval'|'easy'|'recovery'|'strength'|'cross_training'|'rest'\n"
                                        "  isRestDay (bool) — MUST be false for any workout day, true only for rest\n"
                                        "  coachMessage (str) — 1-2 sentence coaching cue\n"
                                        "  warmup (object) — {durationMin: int, description: str, targetPace: str, hrZone: int}\n"
                                        "  mainSet (object) — {description: str, hrZone: int, intervals: [{type: str, durationMin: float, distanceKm: float, targetPace: str, hrZone: int, notes: str}]}\n"
                                        "  cooldown (object) — {durationMin: int, description: str, targetPace: str, hrZone: int}\n"
                                        "  targetDistanceKm (float) — total target distance\n"
                                        "  estimatedDurationMin (int) — expected session length\n"
                                        "To turn a rest day into a workout you MUST include: isRestDay=false, type, title, warmup, mainSet, cooldown, coachMessage."
                                    ),
                                },
                            },
                            "required": ["planWeekDay", "updates"],
                        },
                    },
                },
                "required": ["plan_id", "changes"],
            },
        },
    },
]
