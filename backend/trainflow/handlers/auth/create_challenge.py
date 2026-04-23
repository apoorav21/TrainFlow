import os
import random
import boto3

def handler(event, context):
    """CreateAuthChallenge — generates a 6-digit OTP and emails it via SES."""
    otp = str(random.randint(100000, 999999))
    event["response"]["privateChallengeParameters"] = {"answer": otp}
    event["response"]["publicChallengeParameters"] = {"purpose": "email_otp"}
    event["response"]["challengeMetadata"] = "EMAIL_OTP"

    email = event.get("request", {}).get("userAttributes", {}).get("email", "")
    from_email = os.environ.get("FROM_EMAIL", "")

    if email and from_email:
        try:
            boto3.client("ses", region_name=os.environ.get("AWS_REGION", "ap-south-1")).send_email(
                Source=from_email,
                Destination={"ToAddresses": [email]},
                Message={
                    "Subject": {"Data": "Your TrainFlow sign-in code"},
                    "Body": {"Text": {"Data": f"Your sign-in code is: {otp}\n\nValid for 5 minutes. Stay hard.\n\n— TrainFlow"}},
                },
            )
        except Exception as exc:
            print(f"[create_challenge] SES error: {exc}")

    return event
