"""
OpenAI client for TrainFlow.

Three models are used:
  - gpt-4o       (primary)   — agentic chat with function calling
  - gpt-4o-mini  (secondary) — fast/cheap conversation summarisation
  - gpt-5.4      (plan)      — one-shot full training plan generation (128k output)

API key resolution order (first match wins):
  1. AWS Secrets Manager  — secret name: trainflow/openai-api-key
     (used in production Lambda; key is cached per cold start)
  2. OPENAI_API_KEY env var — for local development / testing

Model IDs can be overridden via OPENAI_MODEL / OPENAI_SECONDARY_MODEL / OPENAI_PLAN_MODEL env vars.
"""

import json
import os

import boto3
from openai import OpenAI

PRIMARY_MODEL = os.environ.get('OPENAI_MODEL', 'gpt-4o')
SECONDARY_MODEL = os.environ.get('OPENAI_SECONDARY_MODEL', 'gpt-4o-mini')
PLAN_MODEL = os.environ.get('OPENAI_PLAN_MODEL', 'gpt-5.4')

SECRET_NAME = 'trainflow/openai-api-key'

# Module-level cache — populated once per Lambda cold start
_api_key: str | None = None
_openai_client: OpenAI | None = None


def _resolve_api_key() -> str:
    """
    Fetch the OpenAI API key, trying Secrets Manager first then env var.
    Result is cached so Secrets Manager is called at most once per cold start.
    """
    global _api_key
    if _api_key:
        return _api_key

    # 1. Try Secrets Manager
    try:
        sm = boto3.client('secretsmanager', region_name=os.environ.get('AWS_REGION', 'ap-south-1'))
        secret = sm.get_secret_value(SecretId=SECRET_NAME)
        # Secret can be {"OPENAI_API_KEY": "sk-..."} JSON or a bare key string
        raw = secret.get('SecretString', '').strip()
        try:
            parsed = json.loads(raw)
            if isinstance(parsed, dict):
                _api_key = (parsed.get('OPENAI_API_KEY') or parsed.get('openai_api_key', '')).strip()
            else:
                # Valid JSON but not a dict (e.g. a quoted string "sk-...") — use raw
                _api_key = raw
        except json.JSONDecodeError:
            _api_key = raw
        if _api_key:
            print('[openai_client] API key loaded from Secrets Manager')
            return _api_key
    except Exception as e:
        print(f'[openai_client] Secrets Manager unavailable, falling back to env var: {e}')

    # 2. Fall back to environment variable (local dev / CI)
    _api_key = os.environ.get('OPENAI_API_KEY', '')
    if not _api_key:
        raise RuntimeError(
            'OpenAI API key not found. Set secret trainflow/openai-api-key in '
            'Secrets Manager or set the OPENAI_API_KEY environment variable.'
        )
    print('[openai_client] API key loaded from environment variable')
    return _api_key


def get_client() -> OpenAI:
    """Return a cached OpenAI client (avoids re-creating per invocation)."""
    global _openai_client
    if _openai_client is None:
        _openai_client = OpenAI(api_key=_resolve_api_key())
    return _openai_client


def invoke(
    messages: list,
    system: str,
    tools: list = None,
    max_tokens: int = 2000,
):
    """
    Invoke the primary model with optional function calling.
    Uses max_completion_tokens (required by gpt-5.x models).
    """
    client = get_client()

    full_messages = [{"role": "system", "content": system}] + messages

    kwargs: dict = {
        "model": PRIMARY_MODEL,
        "messages": full_messages,
        "max_completion_tokens": max_tokens,
    }
    if tools:
        kwargs["tools"] = tools

    return client.chat.completions.create(**kwargs)


def invoke_secondary(
    messages: list,
    system: str,
    max_tokens: int = 1000,
):
    """Invoke the secondary model for summarisation (text-only)."""
    client = get_client()

    full_messages = [{"role": "system", "content": system}] + messages

    return client.chat.completions.create(
        model=SECONDARY_MODEL,
        messages=full_messages,
        max_completion_tokens=max_tokens,
    )


def invoke_plan(
    messages: list,
    system: str,
    max_tokens: int = 60000,
):
    """
    Invoke gpt-5.4 for one-shot full training plan generation.
    Supports 128k output tokens — enough for any plan length.
    """
    client = get_client()

    full_messages = [{"role": "system", "content": system}] + messages

    return client.chat.completions.create(
        model=PLAN_MODEL,
        messages=full_messages,
        max_completion_tokens=max_tokens,
    )
