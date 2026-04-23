def handler(event, context):
    """VerifyAuthChallengeResponse — checks the submitted OTP against the stored one."""
    expected = event.get("request", {}).get("privateChallengeParameters", {}).get("answer", "")
    provided = event.get("request", {}).get("challengeAnswer", "")
    event["response"]["answerCorrect"] = bool(expected) and (provided == expected)
    return event
