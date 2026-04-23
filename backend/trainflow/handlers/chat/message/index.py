"""
POST /chat/message

Main AI chat endpoint. Persists the user's message, calls the agentic
AI handler, persists the assistant reply, and manages the sliding-window
summarisation so the context window stays bounded.

Body: { "message": "How is my training going this week?" }

Response:
{
    "reply": "...",
    "onboardingComplete": true|false,
    "metadata": { "toolsUsed": ["get_health_data", ...] }
}
"""

import sys
sys.path.insert(0, '/opt/python')

import uuid
from datetime import datetime, timezone

from trainflow.shared.auth import extract_user_id
from trainflow.shared.db import db
from trainflow.shared.response import ok, bad_request, error
from trainflow.shared.validators import parse_body, require_fields


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _make_msg_sk() -> str:
    """Generate a time-sortable SK: {timestamp}#{uuid4}."""
    return f'{_now_iso()}#{uuid.uuid4()}'


def handler(event, context):
    try:
        user_id = extract_user_id(event)
        body = parse_body(event)
        require_fields(body, ['message'])

        user_message = body['message'].strip()
        if not user_message:
            return bad_request('message must not be empty')

        now = _now_iso()

        # ----------------------------------------------------------------
        # 1. Persist the user's message
        # ----------------------------------------------------------------
        user_msg_sk = _make_msg_sk()
        db.put_chat_message({
            'userId': user_id,
            'msgId': user_msg_sk,
            'role': 'user',
            'content': user_message,
            'timestamp': now,
        })

        # ----------------------------------------------------------------
        # 2. Invoke the agentic AI handler
        # ----------------------------------------------------------------
        from trainflow.ai.chat_handler import handle_chat
        response = handle_chat(user_id, user_message)

        ai_reply = response.get('message', '')
        onboarding_complete = response.get('onboardingComplete', False)
        metadata = response.get('metadata', {})

        # ----------------------------------------------------------------
        # 3. Persist the assistant's reply
        # ----------------------------------------------------------------
        assistant_msg_sk = _make_msg_sk()
        db.put_chat_message({
            'userId': user_id,
            'msgId': assistant_msg_sk,
            'role': 'assistant',
            'content': ai_reply,
            'timestamp': _now_iso(),
            'metadata': metadata,
        })

        # ----------------------------------------------------------------
        # 4. Sliding-window summarisation
        #    Every 20th message: compress messages older than the last 20
        #    into a rolling summary using GPT-4o-mini, keep the tail intact.
        # ----------------------------------------------------------------
        try:
            total_count = db.count_chat_messages(user_id)
            if total_count > 20 and total_count % 20 == 0:
                _update_summary(user_id)
        except Exception as summary_err:
            # Non-critical — log and continue
            print(f'[chat/message] Summary update failed (non-fatal): {summary_err}')

        return ok({
            'reply': ai_reply,
            'onboardingComplete': onboarding_complete,
            'metadata': metadata,
        })

    except ValueError as e:
        return bad_request(str(e))
    except Exception as e:
        print(f'[chat/message] error: {e}')
        return error('Failed to process message')


def _update_summary(user_id: str) -> None:
    """
    Fetch all messages, take messages[:-20] (the older ones), compress into
    a new summary via Haiku, then store. The last 20 messages stay in the
    table as-is to give the LLM full detail for the most recent context.
    """
    all_messages = db.get_all_chat_messages(user_id)  # chronological order
    if len(all_messages) <= 20:
        return

    older = all_messages[:-20]  # everything except the last 20

    messages_for_summary = [
        {'role': m['role'], 'content': m['content']}
        for m in older
        if m.get('role') in ('user', 'assistant') and m.get('content')
    ]

    from trainflow.ai.chat_handler import summarize_conversation
    new_summary_text = summarize_conversation(user_id, messages_for_summary)

    if new_summary_text:
        db.put_chat_summary(user_id, new_summary_text)
        print(f'[chat/message] Summary updated covering {len(older)} messages for user {user_id}')
