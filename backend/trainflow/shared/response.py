import json
from decimal import Decimal

CORS_HEADERS = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
    'Content-Type': 'application/json',
}


class _DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            if obj % 1 == 0:
                return int(obj)
            return float(obj)
        return super().default(obj)


def _response(status_code: int, body: dict) -> dict:
    return {
        'statusCode': status_code,
        'headers': CORS_HEADERS,
        'body': json.dumps(body, cls=_DecimalEncoder),
    }


def ok(body: dict) -> dict:
    return _response(200, body)


def created(body: dict) -> dict:
    return _response(201, body)


def bad_request(message: str) -> dict:
    return _response(400, {'error': message})


def unauthorized(message: str = 'Unauthorized') -> dict:
    return _response(401, {'error': message})


def not_found(message: str = 'Not found') -> dict:
    return _response(404, {'error': message})


def error(message: str = 'Internal server error', status_code: int = 500) -> dict:
    return _response(status_code, {'error': message})
