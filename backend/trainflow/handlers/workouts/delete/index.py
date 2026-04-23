"""
DELETE /workouts/{sk}

Delete a workout record (TrainFlow log or HealthKit-synced workout).
The path parameter `sk` is the URL-encoded DynamoDB sort key (timestamp field).
API Gateway automatically URL-decodes path parameters.
"""

import sys
sys.path.insert(0, '/opt/python')

from trainflow.shared.auth import extract_user_id
from trainflow.shared.db import db
from trainflow.shared.response import ok, bad_request, error


def handler(event, context):
    try:
        user_id = extract_user_id(event)

        path_params = event.get('pathParameters') or {}
        sk = path_params.get('sk')
        if not sk:
            return bad_request('sk path parameter is required')

        db.delete_workout(user_id, sk)
        print(f'[workouts/delete] Deleted workout {sk[:40]}... for user {user_id}')

        return ok({'deleted': True})

    except ValueError as e:
        return bad_request(str(e))
    except Exception as e:
        print(f'[workouts/delete] error: {e}')
        return error('Failed to delete workout')
