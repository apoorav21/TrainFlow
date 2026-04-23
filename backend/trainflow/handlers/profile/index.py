"""
GET /profile  — return the authenticated user's profile
PUT /profile  — partially update the user's profile (deep-merge for nested objects)

Deployed as a single Lambda; routing is done by httpMethod.
The trainflow package is available on sys.path via the Lambda layer at /opt/python.
"""

import sys
sys.path.insert(0, '/opt/python')

from datetime import datetime, timezone

from trainflow.shared.auth import extract_user_id
from trainflow.shared.db import db
from trainflow.shared.response import ok, not_found, bad_request, error
from trainflow.shared.validators import parse_body


# Fields the client is allowed to set or update via PUT /profile
_ALLOWED_TOP_LEVEL = {
    'name', 'goals', 'fitnessLevel', 'daysPerWeek',
    'raceInfo', 'location', 'injuries', 'preferences',
    'onboardingComplete',
}

# Nested objects that are deep-merged rather than replaced wholesale
_DEEP_MERGE_KEYS = {'raceInfo', 'location', 'preferences'}


def _deep_merge(base: dict, updates: dict) -> dict:
    """
    Merge `updates` into `base`. For nested dicts listed in _DEEP_MERGE_KEYS
    a recursive merge is performed; all other values are overwritten.
    """
    result = {**base}
    for key, value in updates.items():
        if key in _DEEP_MERGE_KEYS and isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = {**result[key], **value}
        else:
            result[key] = value
    return result


def handler(event, context):
    method = event.get('httpMethod', 'GET').upper()

    if method == 'GET':
        return _get_profile(event)
    elif method == 'PUT':
        return _put_profile(event)
    else:
        return bad_request(f'Method {method} not supported')


# ---------------------------------------------------------------------------
# GET /profile
# ---------------------------------------------------------------------------

def _get_profile(event):
    try:
        user_id = extract_user_id(event)
        profile = db.get_user(user_id)

        if not profile:
            return not_found('Profile not found')

        return ok({'profile': profile})

    except ValueError as e:
        return bad_request(str(e))
    except Exception as e:
        print(f'[profile/GET] error: {e}')
        return error('Failed to get profile')


# ---------------------------------------------------------------------------
# PUT /profile
# ---------------------------------------------------------------------------

def _put_profile(event):
    try:
        user_id = extract_user_id(event)
        body = parse_body(event)

        # Strip keys the client is not allowed to set directly
        filtered = {k: v for k, v in body.items() if k in _ALLOWED_TOP_LEVEL}
        if not filtered:
            return bad_request('No valid fields provided')

        now = datetime.now(timezone.utc).isoformat()

        existing = db.get_user(user_id)
        if existing:
            # Deep-merge the incoming changes onto the existing profile
            merged = _deep_merge(existing, filtered)
            merged['updatedAt'] = now
            db.put_user(user_id, merged)
            return ok({'profile': merged})
        else:
            # User doesn't exist yet — create a minimal record
            new_profile = {
                'userId': user_id,
                'onboardingComplete': False,
                'createdAt': now,
                'updatedAt': now,
                **filtered,
            }
            db.put_user(user_id, new_profile)
            return ok({'profile': new_profile})

    except ValueError as e:
        return bad_request(str(e))
    except Exception as e:
        print(f'[profile/PUT] error: {e}')
        return error('Failed to update profile')
