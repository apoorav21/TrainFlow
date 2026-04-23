"""
GET /workouts

Returns the user's recent workout history.
Query param: ?days=30 (default 30, max 365)

Results are sorted newest-first (DynamoDB ScanIndexForward=False on timestamp SK).
"""

import sys
sys.path.insert(0, '/opt/python')

from datetime import datetime, timedelta, timezone

from trainflow.shared.auth import extract_user_id
from trainflow.shared.db import db
from trainflow.shared.response import ok, bad_request, error
from trainflow.shared.validators import get_query_param


def handler(event, context):
    try:
        user_id = extract_user_id(event)

        days_param = get_query_param(event, 'days', '30')
        try:
            days = min(max(int(days_param), 1), 365)
        except (ValueError, TypeError):
            return bad_request('days must be a positive integer (max 365)')

        # Fetch a generous batch and filter by date in Python.
        # For most users the limit of 100 will cover any 30-day window;
        # adjust if high-volume athletes log > 100 workouts per month.
        workouts = db.get_workouts(user_id, limit=200)

        cutoff = datetime.now(timezone.utc) - timedelta(days=days)

        def _within_window(w: dict) -> bool:
            # HealthKit workouts store startDate separately; TrainFlow logs use timestamp.
            # HealthKit SK format is "ISO_DATE#HK#uuid" — split to get the clean date.
            ts = w.get('startDate') or w.get('timestamp', '')
            if not ts:
                return False
            ts_clean = ts.split('#')[0]
            try:
                dt = datetime.fromisoformat(ts_clean.replace('Z', '+00:00'))
                return dt >= cutoff
            except ValueError:
                return False

        filtered = [w for w in workouts if _within_window(w)]

        return ok({
            'workouts': filtered,
            'count': len(filtered),
            'days': days,
        })

    except ValueError as e:
        return bad_request(str(e))
    except Exception as e:
        print(f'[workouts/get] error: {e}')
        return error('Failed to retrieve workouts')
