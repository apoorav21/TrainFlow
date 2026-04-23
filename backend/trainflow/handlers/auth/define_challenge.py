def handler(event, context):
    """DefineAuthChallenge — orchestrates the custom (email-OTP) sign-in flow."""
    session = event.get("request", {}).get("session", [])

    if not session:
        event["response"]["challengeName"] = "CUSTOM_CHALLENGE"
        event["response"]["issueTokens"] = False
        event["response"]["failAuthentication"] = False
    elif session[-1].get("challengeResult") is True:
        event["response"]["issueTokens"] = True
        event["response"]["failAuthentication"] = False
    else:
        event["response"]["issueTokens"] = False
        event["response"]["failAuthentication"] = True

    return event
