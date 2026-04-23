"""
DELETE /account

Deletes all DynamoDB data for the authenticated user across all six tables.
The Cognito user record is deleted client-side via Amplify.Auth.deleteUser().
"""

import sys
sys.path.insert(0, '/opt/python')

import boto3
from boto3.dynamodb.conditions import Key

from trainflow.shared.auth import extract_user_id
from trainflow.shared.db import (
    USERS_TABLE, PLANS_TABLE, WORKOUT_DAYS_TABLE,
    HEALTH_TABLE, WORKOUTS_TABLE, CHAT_TABLE
)
from trainflow.shared.response import ok, bad_request, error


dynamodb = boto3.resource('dynamodb')

# Each table's (table_name, sort_key_attr) — None means PK-only table
TABLE_SK_MAP = [
    (USERS_TABLE,        None),
    (PLANS_TABLE,        'planId'),
    (WORKOUT_DAYS_TABLE, 'planWeekDay'),
    (HEALTH_TABLE,       'date'),
    (WORKOUTS_TABLE,     'timestamp'),
    (CHAT_TABLE,         'msgId'),
]


def _delete_all_items(table_name: str, sk_attr: str | None, user_id: str) -> int:
    table = dynamodb.Table(table_name)

    if sk_attr is None:
        # PK-only table (tf-users)
        table.delete_item(Key={'userId': user_id})
        return 1

    # Query all items for this user then batch-delete
    items = []
    kwargs = {
        'KeyConditionExpression': Key('userId').eq(user_id),
        'ProjectionExpression': f'userId, #{sk_attr}',
        'ExpressionAttributeNames': {f'#{sk_attr}': sk_attr},
    }
    response = table.query(**kwargs)
    items.extend(response.get('Items', []))
    while 'LastEvaluatedKey' in response:
        response = table.query(**kwargs, ExclusiveStartKey=response['LastEvaluatedKey'])
        items.extend(response.get('Items', []))

    with table.batch_writer() as batch:
        for item in items:
            batch.delete_item(Key={'userId': item['userId'], sk_attr: item[sk_attr]})

    return len(items)


def handler(event, context):
    try:
        user_id = extract_user_id(event)

        total = 0
        for table_name, sk_attr in TABLE_SK_MAP:
            try:
                count = _delete_all_items(table_name, sk_attr, user_id)
                total += count
                print(f'[account/delete] Deleted {count} items from {table_name}')
            except Exception as te:
                print(f'[account/delete] Warning: could not delete from {table_name}: {te}')

        print(f'[account/delete] Account deletion complete for {user_id}, {total} items removed')
        return ok({'deleted': True, 'itemsRemoved': total})

    except ValueError as e:
        return bad_request(str(e))
    except Exception as e:
        print(f'[account/delete] error: {e}')
        return error('Failed to delete account')
