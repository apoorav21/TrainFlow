"""
GET /health/ai-summary

Returns AI-generated health summaries (overall, vitals, sleep, activity) and an overall health score.
Results are cached in DynamoDB for 24 hours to avoid repeated OpenAI calls.
"""

import sys
sys.path.insert(0, '/opt/python')

import json
import os
from datetime import datetime, timezone, timedelta

from trainflow.shared.auth import extract_user_id
from trainflow.shared.db import db, HEALTH_TABLE, to_decimal, from_decimal
from trainflow.shared.response import ok, error as server_error
from trainflow.ai.openai_client import get_client

import boto3


def handler(event, context):
    try:
        user_id = extract_user_id(event)
        today = datetime.now(timezone.utc).strftime('%Y-%m-%d')
        cache_sk = f'AI_SUMMARY#{today}'

        # Check cache
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table(HEALTH_TABLE)
        cached_resp = table.get_item(Key={'userId': user_id, 'date': cache_sk})
        cached = cached_resp.get('Item')
        if cached and cached.get('summary'):
            return ok({'summary': from_decimal(cached['summary'])})

        # Build context
        health_records = db.get_health_data_range(
            user_id,
            (datetime.now(timezone.utc) - timedelta(days=7)).strftime('%Y-%m-%d'),
            today
        )
        profile = db.get_user(user_id) or {}
        active_plan = db.get_active_plan(user_id)

        health_text = _format_health(health_records)
        plan_text = _format_plan(active_plan)
        name = profile.get('name', 'Athlete')

        prompt = f"""You are analyzing {name}'s health data. Return ONLY a valid JSON object with these exact keys:
{{
  "overallScore": <integer 0-100>,
  "overallSummary": "<2-3 sentence overall health narrative>",
  "vitals": "<1-2 sentence summary of heart rate, HRV, VO2max trends>",
  "sleep": "<1-2 sentence summary of sleep quality and duration trends>",
  "activity": "<1-2 sentence summary of steps, calories, exercise trends>",
  "keyRecommendation": "<single most impactful recommendation based on weakest metric>"
}}

Health data (last 7 days):
{health_text}

Training plan context:
{plan_text}

Score rubric: 100 = elite athlete metrics, 70 = healthy active adult, 50 = average, below 40 = needs improvement.
Be direct and data-driven. Reference specific numbers. Keep each field concise."""

        client = get_client()
        model = os.environ.get('OPENAI_SECONDARY_MODEL', 'gpt-4o-mini')
        resp = client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": prompt}],
            temperature=0.3,
            max_completion_tokens=600,
            response_format={"type": "json_object"}
        )

        raw = resp.choices[0].message.content
        summary = json.loads(raw)
        summary['generatedAt'] = today

        table.put_item(Item={
            'userId': user_id,
            'date': cache_sk,
            'summary': to_decimal(summary)
        })

        return ok({'summary': summary})

    except Exception as e:
        print(f'[health/ai-summary] error: {e}')
        return server_error('Failed to generate health summary')


def _format_health(records: list) -> str:
    if not records:
        return "No recent health data available."
    lines = []
    for r in sorted(records, key=lambda x: x.get('date', ''))[-7:]:
        parts = [r.get('date', '')]
        if r.get('restingHR'): parts.append(f"RHR={r['restingHR']:.0f}bpm")
        if r.get('hrv'): parts.append(f"HRV={r['hrv']:.1f}ms")
        if r.get('steps'): parts.append(f"steps={r['steps']:.0f}")
        if r.get('activeCalories'): parts.append(f"activeCal={r['activeCalories']:.0f}kcal")
        if r.get('exerciseMinutes'): parts.append(f"exercise={r['exerciseMinutes']:.0f}min")
        sleep = r.get('sleepData') or {}
        if sleep.get('totalMinutes'): parts.append(f"sleep={float(sleep['totalMinutes'])/60:.1f}h")
        if sleep.get('deepMinutes'): parts.append(f"deep={float(sleep['deepMinutes']):.0f}min")
        if sleep.get('remMinutes'): parts.append(f"rem={float(sleep['remMinutes']):.0f}min")
        lines.append(' | '.join(parts))
    return '\n'.join(lines)


def _format_plan(plan: dict) -> str:
    if not plan:
        return "No active training plan."
    return f"Plan: {plan.get('planName', 'Active Plan')} | Goal: {plan.get('goal', 'N/A')} | Level: {plan.get('fitnessLevel', 'N/A')}"
