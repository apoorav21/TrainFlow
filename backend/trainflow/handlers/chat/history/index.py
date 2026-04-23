"""
GET /chat/history

Returns recent chat messages plus the rolling summary (if one exists).
Query param: ?limit=50 (default 50, max 200)

Messages are returned in chronological order (oldest-first) so the iOS
client can render them top-to-bottom without reversing.

Response:
{
    "messages": [
        { "msgId": "...", "role": "user"|"assistant", "content": "...", "timestamp": "..." },
        ...
    ],
    "summary": "Previous conversation summary..." | null,
    "count": 12
}
"""

import sys
sys.path.insert(0, '/opt/python')

from trainflow.shared.auth import extract_user_id
from trainflow.shared.db import db
from trainflow.shared.response import ok, bad_request, error
from trainflow.shared.validators import get_query_param


def handler(event, context):
    try:
        user_id = extract_user_id(event)

        limit_param = get_query_param(event, 'limit', '50')
        try:
            limit = min(max(int(limit_param), 1), 200)
        except (ValueError, TypeError):
            return bad_request('limit must be a positive integer (max 200)')

        # db returns newest-first; reverse for chronological display
        messages_newest_first = db.get_chat_messages(user_id, limit=limit)
        messages = list(reversed(messages_newest_first))

        # Strip internal metadata the iOS client doesn't need
        clean_messages = [
            {
                'msgId': m.get('msgId', ''),
                'role': m.get('role', ''),
                'content': m.get('content', ''),
                'timestamp': m.get('timestamp', ''),
            }
            for m in messages
        ]

        summary_record = db.get_chat_summary(user_id)
        summary_text = summary_record.get('summaryText') if summary_record else None

        return ok({
            'messages': clean_messages,
            'summary': summary_text,
            'count': len(clean_messages),
        })

    except ValueError as e:
        return bad_request(str(e))
    except Exception as e:
        print(f'[chat/history] error: {e}')
        return error('Failed to retrieve chat history')
