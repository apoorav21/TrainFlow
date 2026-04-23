import json
import re
from datetime import datetime


def parse_body(event: dict) -> dict:
    """Parse and return the JSON body from an API Gateway event."""
    body = event.get('body')
    if not body:
        raise ValueError('Request body is required')
    if isinstance(body, str):
        return json.loads(body)
    return body


def require_fields(data: dict, fields: list) -> None:
    """Raise ValueError if any required fields are missing."""
    missing = [f for f in fields if f not in data or data[f] is None]
    if missing:
        raise ValueError(f"Missing required fields: {', '.join(missing)}")


def get_query_param(event: dict, name: str, default=None) -> str:
    """Get a query string parameter."""
    params = event.get('queryStringParameters') or {}
    return params.get(name, default)


def get_path_param(event: dict, name: str) -> str:
    """Get a path parameter."""
    params = event.get('pathParameters') or {}
    value = params.get(name)
    if not value:
        raise ValueError(f'Missing path parameter: {name}')
    return value


def validate_date(date_str: str) -> str:
    """Validate and return an ISO date string (YYYY-MM-DD)."""
    try:
        datetime.strptime(date_str, '%Y-%m-%d')
        return date_str
    except ValueError:
        raise ValueError(f'Invalid date format: {date_str}. Expected YYYY-MM-DD')


def validate_email(email: str) -> str:
    """Validate email format."""
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    if not re.match(pattern, email):
        raise ValueError(f'Invalid email: {email}')
    return email


def validate_positive_int(value, name: str) -> int:
    """Validate that value is a positive integer."""
    try:
        v = int(value)
        if v <= 0:
            raise ValueError()
        return v
    except (ValueError, TypeError):
        raise ValueError(f'{name} must be a positive integer')
