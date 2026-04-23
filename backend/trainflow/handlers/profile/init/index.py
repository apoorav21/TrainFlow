"""
Cognito Post-Confirmation Lambda trigger.

Fires automatically after a user successfully confirms their account
(email verification or admin confirmation). Creates a bare-bones profile
in tf-users if one does not already exist.

IMPORTANT: Must return the original `event` object — Cognito requires it.
"""

import sys
sys.path.insert(0, '/opt/python')

from datetime import datetime, timezone

from trainflow.shared.db import db


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def handler(event, context):
    """
    Cognito trigger payload shape:
    {
        "userName": "<cognito-sub>",
        "request": {
            "userAttributes": {
                "sub": "...",
                "email": "user@example.com",
                "name": "Jane Doe",
                ...
            }
        },
        ...
    }
    """
    try:
        user_id = event['userName']
        attrs = event.get('request', {}).get('userAttributes', {})
        email = attrs.get('email', '')
        name = attrs.get('name', '')

        # Idempotent — only create profile if it doesn't already exist
        existing = db.get_user(user_id)
        if not existing:
            now = _now_iso()
            db.put_user(user_id, {
                'userId': user_id,
                'email': email,
                'name': name,
                'onboardingComplete': False,
                'createdAt': now,
                'updatedAt': now,
            })
            print(f'[profile/init] Created profile for user {user_id}')
        else:
            print(f'[profile/init] Profile already exists for user {user_id}, skipping')

    except Exception as e:
        # Log but do NOT raise — a failed trigger would block the user from
        # completing sign-up, which is worse than a missing profile.
        print(f'[profile/init] ERROR: {e}')

    # Cognito requires the event to be returned unchanged
    return event
