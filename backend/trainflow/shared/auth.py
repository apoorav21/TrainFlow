"""
TrainFlow authentication helpers.

User identity comes from the Cognito JWT that API Gateway's authorizer
verifies. The user's Cognito sub is used as the canonical userId everywhere.
"""


def extract_user_id(event: dict) -> str:
    """
    Extract the Cognito userId (sub) from the API Gateway authorizer claims.

    Raises ValueError if the claims are missing — the Lambda should catch
    this and return a 401 response.
    """
    try:
        return event['requestContext']['authorizer']['claims']['sub']
    except (KeyError, TypeError):
        raise ValueError('Unauthorized')


def extract_claims(event: dict) -> dict:
    """
    Return all Cognito claims from the API Gateway authorizer context.
    Useful when you need email, username, or other attributes.

    Raises ValueError if the claims are missing.
    """
    try:
        return event['requestContext']['authorizer']['claims']
    except (KeyError, TypeError):
        raise ValueError('Unauthorized')
