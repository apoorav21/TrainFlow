"""
TrainFlow DynamoDB client — multi-table architecture.

Six separate DynamoDB tables:

  tf-users          PK=userId (simple primary key)
  tf-training-plans PK=userId, SK=planId
  tf-workout-days   PK=userId, SK={planId}#W{weekNum:02}#D{dayNum}
  tf-health-data    PK=userId, SK=date (YYYY-MM-DD)
  tf-workouts       PK=userId, SK=timestamp (ISO8601)
  tf-chat-messages  PK=userId, SK={timestamp}#{uuid} | 'SUMMARY'

Table names are read from environment variables so they can differ between
environments (dev / staging / prod) without code changes.
"""

import os
from decimal import Decimal
from typing import Any, Optional

import boto3
from boto3.dynamodb.conditions import Key, Attr

# ---------------------------------------------------------------------------
# Table name constants (from environment, with sensible defaults)
# ---------------------------------------------------------------------------
USERS_TABLE = os.environ.get('TF_USERS_TABLE', 'tf-users')
PLANS_TABLE = os.environ.get('TF_PLANS_TABLE', 'tf-training-plans')
WORKOUT_DAYS_TABLE = os.environ.get('TF_WORKOUT_DAYS_TABLE', 'tf-workout-days')
HEALTH_TABLE = os.environ.get('TF_HEALTH_TABLE', 'tf-health-data')
WORKOUTS_TABLE = os.environ.get('TF_WORKOUTS_TABLE', 'tf-workouts')
CHAT_TABLE = os.environ.get('TF_CHAT_TABLE', 'tf-chat-messages')


# ---------------------------------------------------------------------------
# Decimal helpers (DynamoDB stores numbers as Decimal; JSON needs int/float)
# ---------------------------------------------------------------------------

def to_decimal(obj: Any) -> Any:
    """Recursively convert floats and ints to Decimal for DynamoDB storage."""
    if isinstance(obj, float):
        return Decimal(str(obj))
    if isinstance(obj, int) and not isinstance(obj, bool):
        return Decimal(str(obj))
    if isinstance(obj, dict):
        return {k: to_decimal(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [to_decimal(i) for i in obj]
    return obj


def from_decimal(obj: Any) -> Any:
    """Recursively convert Decimal back to native int/float for JSON serialisation."""
    if isinstance(obj, Decimal):
        return int(obj) if obj % 1 == 0 else float(obj)
    if isinstance(obj, dict):
        return {k: from_decimal(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [from_decimal(i) for i in obj]
    return obj


# ---------------------------------------------------------------------------
# TFDatabase
# ---------------------------------------------------------------------------

class TFDatabase:
    """
    Thin wrapper around six DynamoDB tables used by TrainFlow.
    A module-level singleton (`db`) is exported at the bottom of this file.
    """

    def __init__(self):
        resource = boto3.resource('dynamodb')
        self._users = resource.Table(USERS_TABLE)
        self._plans = resource.Table(PLANS_TABLE)
        self._workout_days = resource.Table(WORKOUT_DAYS_TABLE)
        self._health = resource.Table(HEALTH_TABLE)
        self._workouts = resource.Table(WORKOUTS_TABLE)
        self._chat = resource.Table(CHAT_TABLE)

    # ------------------------------------------------------------------ #
    # Internal helpers                                                     #
    # ------------------------------------------------------------------ #

    @staticmethod
    def _build_update_expression(updates: dict):
        """
        Build the UpdateExpression, ExpressionAttributeNames, and
        ExpressionAttributeValues dicts required by DynamoDB update_item.
        """
        expr_names: dict = {}
        expr_values: dict = {}
        set_parts: list = []

        for i, (key, value) in enumerate(updates.items()):
            name_alias = f'#attr{i}'
            value_alias = f':val{i}'
            expr_names[name_alias] = key
            expr_values[value_alias] = to_decimal(value)
            set_parts.append(f'{name_alias} = {value_alias}')

        update_expression = 'SET ' + ', '.join(set_parts)
        return update_expression, expr_names, expr_values

    # ------------------------------------------------------------------ #
    # tf-users                                                             #
    # ------------------------------------------------------------------ #

    def get_user(self, user_id: str) -> Optional[dict]:
        """Fetch a user profile by userId. Returns None if not found."""
        resp = self._users.get_item(Key={'userId': user_id})
        item = resp.get('Item')
        return from_decimal(item) if item else None

    def put_user(self, user_id: str, data: dict) -> dict:
        """Create or fully replace a user record."""
        item = {**data, 'userId': user_id}
        self._users.put_item(Item=to_decimal(item))
        return item

    def update_user(self, user_id: str, updates: dict) -> dict:
        """Partial update — only the keys present in `updates` are changed."""
        expr, names, values = self._build_update_expression(updates)
        resp = self._users.update_item(
            Key={'userId': user_id},
            UpdateExpression=expr,
            ExpressionAttributeNames=names,
            ExpressionAttributeValues=values,
            ReturnValues='ALL_NEW',
        )
        return from_decimal(resp.get('Attributes', {}))

    # ------------------------------------------------------------------ #
    # tf-training-plans                                                    #
    # ------------------------------------------------------------------ #

    def get_active_plan(self, user_id: str) -> Optional[dict]:
        """
        Query the ActivePlanIndex GSI for the user's currently active plan.
        GSI PK=userId, SK=isActive — query directly on isActive='true'.
        Returns the first (should be only) active plan, or None.
        """
        resp = self._plans.query(
            IndexName='ActivePlanIndex',
            KeyConditionExpression=Key('userId').eq(user_id) & Key('isActive').eq('true'),
            Limit=1,
        )
        items = resp.get('Items', [])
        return from_decimal(items[0]) if items else None

    def get_plan(self, user_id: str, plan_id: str) -> Optional[dict]:
        """Fetch a specific plan by its composite key."""
        resp = self._plans.get_item(Key={'userId': user_id, 'planId': plan_id})
        item = resp.get('Item')
        return from_decimal(item) if item else None

    def put_plan(self, plan: dict) -> dict:
        """Create or replace a plan record."""
        self._plans.put_item(Item=to_decimal(plan))
        return plan

    def update_plan(self, user_id: str, plan_id: str, updates: dict) -> dict:
        """Partial update for a plan."""
        expr, names, values = self._build_update_expression(updates)
        resp = self._plans.update_item(
            Key={'userId': user_id, 'planId': plan_id},
            UpdateExpression=expr,
            ExpressionAttributeNames=names,
            ExpressionAttributeValues=values,
            ReturnValues='ALL_NEW',
        )
        return from_decimal(resp.get('Attributes', {}))

    # ------------------------------------------------------------------ #
    # tf-workout-days                                                      #
    # ------------------------------------------------------------------ #

    def get_workout_days(self, user_id: str, plan_id: str) -> list:
        """Return all workout days for a plan, sorted by SK (week/day order)."""
        items = []
        kwargs = dict(
            KeyConditionExpression=(
                Key('userId').eq(user_id) & Key('planWeekDay').begins_with(plan_id)
            ),
            ScanIndexForward=True,
        )
        while True:
            resp = self._workout_days.query(**kwargs)
            items.extend(resp.get('Items', []))
            if 'LastEvaluatedKey' not in resp:
                break
            kwargs['ExclusiveStartKey'] = resp['LastEvaluatedKey']
        return [from_decimal(i) for i in items]

    def get_workout_days_for_week(self, user_id: str, plan_id: str, week_num: int) -> list:
        """Return workout days for a specific week, e.g. SK begins_with planId#W03."""
        prefix = f'{plan_id}#W{week_num:02d}'
        resp = self._workout_days.query(
            KeyConditionExpression=(
                Key('userId').eq(user_id) & Key('planWeekDay').begins_with(prefix)
            ),
            ScanIndexForward=True,
        )
        return [from_decimal(i) for i in resp.get('Items', [])]

    def get_workout_day(self, user_id: str, day_sk: str) -> Optional[dict]:
        """Fetch a single workout day by its full SK."""
        resp = self._workout_days.get_item(Key={'userId': user_id, 'planWeekDay': day_sk})
        item = resp.get('Item')
        return from_decimal(item) if item else None

    def put_workout_day(self, item: dict) -> dict:
        """Create or replace a workout day record."""
        self._workout_days.put_item(Item=to_decimal(item))
        return item

    def batch_put_workout_days(self, items: list) -> None:
        """Batch write a list of workout day records (handles chunking automatically)."""
        with self._workout_days.batch_writer() as batch:
            for item in items:
                batch.put_item(Item=to_decimal(item))

    def get_workout_day_by_date(self, user_id: str, date: str) -> Optional[dict]:
        """
        Look up today's workout day via the DateIndex GSI.
        GSI: PK=userId, SK=scheduledDate.
        Returns the first matching day, or None.
        """
        resp = self._workout_days.query(
            IndexName='DateIndex',
            KeyConditionExpression=(
                Key('userId').eq(user_id) & Key('scheduledDate').eq(date)
            ),
            Limit=1,
        )
        items = resp.get('Items', [])
        return from_decimal(items[0]) if items else None

    def update_workout_day(self, user_id: str, day_sk: str, updates: dict) -> dict:
        """Partial update for a workout day (used by plan adaptations and completion logging)."""
        expr, names, values = self._build_update_expression(updates)
        resp = self._workout_days.update_item(
            Key={'userId': user_id, 'planWeekDay': day_sk},
            UpdateExpression=expr,
            ExpressionAttributeNames=names,
            ExpressionAttributeValues=values,
            ReturnValues='ALL_NEW',
        )
        return from_decimal(resp.get('Attributes', {}))

    # ------------------------------------------------------------------ #
    # tf-health-data                                                       #
    # ------------------------------------------------------------------ #

    def get_health_data(self, user_id: str, date: str) -> Optional[dict]:
        """Fetch a single day's health record."""
        resp = self._health.get_item(Key={'userId': user_id, 'date': date})
        item = resp.get('Item')
        return from_decimal(item) if item else None

    def get_health_data_range(self, user_id: str, start_date: str, end_date: str) -> list:
        """
        Return health records for a date range (inclusive), sorted by date ascending.
        Uses a BETWEEN condition on the sort key.
        """
        resp = self._health.query(
            KeyConditionExpression=(
                Key('userId').eq(user_id)
                & Key('date').between(start_date, end_date)
            ),
            ScanIndexForward=True,
        )
        return [from_decimal(i) for i in resp.get('Items', [])]

    def put_health_data(self, item: dict) -> dict:
        """Create or replace a health record."""
        self._health.put_item(Item=to_decimal(item))
        return item

    def batch_put_health_data(self, items: list) -> None:
        """Batch write multiple health records."""
        with self._health.batch_writer() as batch:
            for item in items:
                batch.put_item(Item=to_decimal(item))

    # ------------------------------------------------------------------ #
    # tf-workouts                                                          #
    # ------------------------------------------------------------------ #

    def get_workouts(self, user_id: str, limit: int = 20) -> list:
        """
        Return recent workout logs, newest first (ScanIndexForward=False).
        The sort key is an ISO8601 timestamp so lexicographic order == chronological.
        """
        resp = self._workouts.query(
            KeyConditionExpression=Key('userId').eq(user_id),
            ScanIndexForward=False,
            Limit=limit,
        )
        return [from_decimal(i) for i in resp.get('Items', [])]

    def put_workout(self, item: dict) -> dict:
        """Store a completed workout log."""
        self._workouts.put_item(Item=to_decimal(item))
        return item

    def batch_put_workouts(self, items: list) -> None:
        """Batch write multiple workout records (handles chunking automatically)."""
        with self._workouts.batch_writer() as batch:
            for item in items:
                batch.put_item(Item=to_decimal(item))

    def delete_workout(self, user_id: str, timestamp: str) -> None:
        """Delete a workout record by its composite key (userId + timestamp SK)."""
        self._workouts.delete_item(
            Key={'userId': user_id, 'timestamp': timestamp}
        )

    # ------------------------------------------------------------------ #
    # tf-chat-messages                                                     #
    # ------------------------------------------------------------------ #

    def get_chat_messages(self, user_id: str, limit: int = 20) -> list:
        """
        Return the most recent `limit` non-SUMMARY chat messages, newest first.
        Fetches extra items to account for the SUMMARY record, then filters in Python.
        """
        resp = self._chat.query(
            KeyConditionExpression=Key('userId').eq(user_id),
            ScanIndexForward=False,
            Limit=limit + 1,  # +1 in case SUMMARY is in the window
        )
        items = [i for i in resp.get('Items', []) if i.get('msgId') != 'SUMMARY']
        return [from_decimal(i) for i in items[:limit]]

    def get_chat_summary(self, user_id: str) -> Optional[dict]:
        """Fetch the rolling conversation summary (SK='SUMMARY'), or None."""
        resp = self._chat.get_item(Key={'userId': user_id, 'msgId': 'SUMMARY'})
        item = resp.get('Item')
        return from_decimal(item) if item else None

    def put_chat_message(self, item: dict) -> dict:
        """Store a chat message (user or assistant turn)."""
        self._chat.put_item(Item=to_decimal(item))
        return item

    def put_chat_summary(self, user_id: str, summary_text: str) -> dict:
        """Upsert the rolling conversation summary record."""
        from datetime import datetime, timezone
        item = {
            'userId': user_id,
            'msgId': 'SUMMARY',
            'summaryText': summary_text,
            'updatedAt': datetime.now(timezone.utc).isoformat(),
        }
        self._chat.put_item(Item=to_decimal(item))
        return item

    def count_chat_messages(self, user_id: str) -> int:
        """
        Count all non-SUMMARY chat messages for a user.
        Fetches all keys and counts in Python (msgId is a sort key so FilterExpression cannot exclude it).
        """
        count = 0
        params = {
            'KeyConditionExpression': Key('userId').eq(user_id),
            'ProjectionExpression': 'msgId',
        }
        while True:
            resp = self._chat.query(**params)
            count += sum(1 for i in resp.get('Items', []) if i.get('msgId') != 'SUMMARY')
            if 'LastEvaluatedKey' not in resp:
                break
            params['ExclusiveStartKey'] = resp['LastEvaluatedKey']
        return count

    def get_all_chat_messages(self, user_id: str) -> list:
        """
        Return ALL non-SUMMARY chat messages for a user in chronological order.
        Used when building a summary from older messages. Paginates automatically.
        """
        items = []
        params = {
            'KeyConditionExpression': Key('userId').eq(user_id),
            'ScanIndexForward': True,
        }
        while True:
            resp = self._chat.query(**params)
            items.extend(i for i in resp.get('Items', []) if i.get('msgId') != 'SUMMARY')
            if 'LastEvaluatedKey' not in resp:
                break
            params['ExclusiveStartKey'] = resp['LastEvaluatedKey']
        return [from_decimal(i) for i in items]

    def delete_all_chat(self, user_id: str) -> int:
        """
        Delete every chat record (messages + summary) for a user.
        Queries first to collect all keys, then batch-deletes.
        Returns the number of items deleted.
        """
        # Collect all item keys (including SUMMARY)
        keys = []
        params = {
            'KeyConditionExpression': Key('userId').eq(user_id),
            'ProjectionExpression': 'userId, msgId',
        }
        while True:
            resp = self._chat.query(**params)
            keys.extend(resp.get('Items', []))
            if 'LastEvaluatedKey' not in resp:
                break
            params['ExclusiveStartKey'] = resp['LastEvaluatedKey']

        # Batch delete
        with self._chat.batch_writer() as batch:
            for key in keys:
                batch.delete_item(Key={'userId': key['userId'], 'msgId': key['msgId']})

        return len(keys)


# ---------------------------------------------------------------------------
# Module-level singleton — import and use directly: from trainflow.shared.db import db
# ---------------------------------------------------------------------------
db = TFDatabase()
