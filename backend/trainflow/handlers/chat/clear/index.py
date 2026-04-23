"""
DELETE /chat

Deletes all chat messages and the rolling summary for the authenticated user.
Uses query + batch delete (no scan — always use the table's primary key).

Response: { "deleted": 47 }
"""

import sys
sys.path.insert(0, '/opt/python')

from trainflow.shared.auth import extract_user_id
from trainflow.shared.db import db
from trainflow.shared.response import ok, bad_request, error


def handler(event, context):
    try:
        user_id = extract_user_id(event)

        deleted_count = db.delete_all_chat(user_id)
        print(f'[chat/clear] Deleted {deleted_count} chat records for user {user_id}')

        return ok({
            'deleted': deleted_count,
            'message': 'Chat history cleared.',
        })

    except ValueError as e:
        return bad_request(str(e))
    except Exception as e:
        print(f'[chat/clear] error: {e}')
        return error('Failed to clear chat history')
