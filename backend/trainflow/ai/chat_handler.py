"""
Agentic chat handler — the core of the TrainFlow AI system.

handle_chat() implements the full reasoning loop:
  1. Pre-load a context snapshot (profile, plan, health, workouts)
  2. Build a rich system prompt from that snapshot
  3. Load recent chat history + rolling summary from DynamoDB
  4. Call GPT-4o (OpenAI) with function/tool definitions
  5. If finish_reason == 'tool_calls': execute the tools, feed results back
  6. Repeat up to MAX_TOOL_ROUNDS times, then return the final text reply

summarize_conversation() compresses older messages using GPT-4o-mini and is
called by the chat/message handler to maintain the sliding window.
"""

import json
import traceback
from datetime import datetime, timezone

from trainflow.ai.openai_client import invoke, invoke_secondary
from trainflow.ai.context_builder import build_context_snapshot
from trainflow.ai.prompts import build_system_prompt
from trainflow.ai.tool_executor import execute_tool
from trainflow.ai.tools import TOOLS
from trainflow.shared.db import db

# Safety cap to prevent runaway agentic loops
MAX_TOOL_ROUNDS = 5


def handle_chat(user_id: str, user_message: str) -> dict:
    """
    Main entry point for a chat turn.

    Parameters
    ----------
    user_id     : Cognito sub of the authenticated user
    user_message: Raw message text from the iOS app

    Returns
    -------
    dict with keys:
        message            – str, the assistant's reply
        onboardingComplete – bool
        metadata           – dict (toolsUsed list, etc.)
    """
    try:
        # ----------------------------------------------------------------
        # 1. Build pre-loaded context snapshot + system prompt
        # ----------------------------------------------------------------
        context = build_context_snapshot(user_id)
        system_prompt = build_system_prompt(context)

        # ----------------------------------------------------------------
        # 2. Assemble message history (OpenAI format)
        #    Order: [summary injection] → [last 20 messages] → [new user msg]
        # ----------------------------------------------------------------
        recent_msgs = db.get_chat_messages(user_id, limit=20)  # newest-first
        summary_record = db.get_chat_summary(user_id)

        messages: list = []

        # Inject rolling summary as synthetic conversation turns so the model
        # understands prior context without consuming the full token budget.
        if summary_record and summary_record.get('summaryText'):
            messages.append({
                "role": "user",
                "content": (
                    f"[Context from previous conversations: "
                    f"{summary_record['summaryText']}]"
                ),
            })
            messages.append({
                "role": "assistant",
                "content": (
                    "I have context from our previous conversations. "
                    "How can I help you today?"
                ),
            })

        # Add recent messages in chronological order (db returns newest-first)
        for msg in reversed(recent_msgs):
            role = msg.get('role', 'user')
            content = msg.get('content', '')
            if role in ('user', 'assistant') and content:
                messages.append({"role": role, "content": content})

        # Append the current user message
        messages.append({"role": "user", "content": user_message})

        # ----------------------------------------------------------------
        # 3. Agentic loop
        # ----------------------------------------------------------------
        final_response: str | None = None
        tool_results_metadata: list = []

        for round_num in range(MAX_TOOL_ROUNDS):
            response = invoke(
                messages=messages,
                system=system_prompt,
                tools=TOOLS,
                max_tokens=2000,
            )

            choice = response.choices[0]
            finish_reason = choice.finish_reason
            message = choice.message

            if finish_reason == 'stop':
                # Model finished — extract the text reply
                final_response = message.content or ''
                break

            elif finish_reason == 'tool_calls':
                tool_calls = message.tool_calls or []

                if not tool_calls:
                    # Unexpected: tool_calls finish but no tool_calls present
                    final_response = message.content or ''
                    break

                # Append the assistant's message (with tool_calls) to history.
                # OpenAI requires this before appending tool result messages.
                messages.append({
                    "role": "assistant",
                    "content": message.content,  # may be None
                    "tool_calls": [
                        {
                            "id": tc.id,
                            "type": "function",
                            "function": {
                                "name": tc.function.name,
                                "arguments": tc.function.arguments,
                            },
                        }
                        for tc in tool_calls
                    ],
                })

                # Execute each tool and append individual tool-result messages.
                # OpenAI requires one {"role": "tool"} message per tool call.
                for tc in tool_calls:
                    tool_name = tc.function.name
                    try:
                        tool_input = json.loads(tc.function.arguments)
                    except json.JSONDecodeError:
                        tool_input = {}

                    print(f'[chat_handler] Round {round_num + 1}: executing tool {tool_name}')

                    result = execute_tool(tool_name, tool_input, user_id)
                    success = 'error' not in result
                    tool_results_metadata.append({'tool': tool_name, 'success': success})

                    messages.append({
                        "role": "tool",
                        "tool_call_id": tc.id,
                        "content": json.dumps(result, default=str),
                    })

            else:
                # Unexpected finish reason (e.g. length, content_filter)
                final_response = (
                    message.content
                    if message.content
                    else 'I encountered an issue. Please try again.'
                )
                break

        if final_response is None:
            final_response = (
                'I hit my reasoning limit on that one. '
                'Could you try rephrasing or breaking it into a simpler question?'
            )

        # ----------------------------------------------------------------
        # 4. Detect if onboarding was completed during this turn
        # ----------------------------------------------------------------
        onboarding_complete = bool(context['profile'].get('onboardingComplete', False))
        plan_created = any(
            t['tool'] == 'create_training_plan' and t['success']
            for t in tool_results_metadata
        )
        if plan_created:
            onboarding_complete = True

        return {
            'message': final_response,
            'onboardingComplete': onboarding_complete,
            'metadata': {
                'toolsUsed': [t['tool'] for t in tool_results_metadata],
                'toolRounds': len(tool_results_metadata),
            },
        }

    except Exception as e:
        print(f'[chat_handler] Unhandled error: {e}')
        traceback.print_exc()
        return {
            'message': 'I had trouble processing that. Please try again in a moment.',
            'onboardingComplete': False,
            'metadata': {},
        }


def summarize_conversation(user_id: str, messages_to_summarize: list) -> str:
    """
    Compress a list of older messages into a concise summary using GPT-4o-mini.

    Parameters
    ----------
    user_id                 : Not used for the API call but kept for logging
    messages_to_summarize   : List of {"role": ..., "content": ...} dicts

    Returns
    -------
    str — the summary text, or '' on failure.
    """
    if not messages_to_summarize:
        return ''

    try:
        conversation_text = '\n'.join(
            f"{m['role'].upper()}: {m.get('content', '')}"
            for m in messages_to_summarize
            if m.get('role') in ('user', 'assistant') and m.get('content')
        )

        system = (
            "You are summarising a conversation between a user and their AI fitness coach (Alex). "
            "Create a concise summary (under 300 words) capturing:\n"
            "- Key user information revealed (goals, race details, fitness level, injuries)\n"
            "- Important decisions made (plan created, adaptations requested)\n"
            "- Training preferences and recurring concerns\n"
            "- Progress and milestones discussed\n\n"
            "Write in third person, past tense. Be specific about numbers and dates mentioned. "
            "Do not include generic filler — only information that would be useful context "
            "for a coach reading a new session with this athlete."
        )

        summary_messages = [{
            "role": "user",
            "content": f"Summarise this coaching conversation:\n\n{conversation_text}",
        }]

        response = invoke_secondary(
            messages=summary_messages,
            system=system,
            max_tokens=400,
        )

        summary = response.choices[0].message.content or ''
        print(f'[chat_handler] Generated summary ({len(summary)} chars) for user {user_id}')
        return summary

    except Exception as e:
        print(f'[chat_handler] summarize_conversation error: {e}')
        return ''
