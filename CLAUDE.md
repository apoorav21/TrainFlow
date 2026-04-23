# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TrainFlow — an iOS fitness coaching app backed by AWS serverless infrastructure:
- **TrainFlow/**: SwiftUI iOS app using HealthKit and AWS Amplify (Cognito auth)
- **backend/trainflow/**: Python AWS Lambda handlers (REST API)
- **infrastructure/**: TypeScript AWS CDK (single stack: `TrainFlowStack`)

## Build & Development Commands

### Infrastructure (CDK)
```bash
cd infrastructure
npm install
npm run build          # Compile TypeScript
npm run synth          # Generate CloudFormation templates
npm run deploy         # Deploy TrainFlowStack to ap-south-1
npm run deploy:trainflow  # Deploy only TrainFlowStack
npm run diff           # Preview infrastructure changes
```

**Before deploying after backend changes:**
```bash
pip3 install -r backend/requirements.txt -t backend/
```

### Backend (Python Lambda — no test runner)
```python
event = {
    "requestContext": {"authorizer": {"claims": {"sub": "user-id"}}},
    "body": json.dumps({"field": "value"}),
    "pathParameters": {...}
}
handler(event, None)
```

## Architecture

### Request Flow
iOS (Amplify) → API Gateway → Lambda (`backend/trainflow/handlers/`) → DynamoDB

### AI Chat Flow
`tf-chat-message` Lambda → `trainflow.ai.chat_handler.handle_chat()` → OpenAI GPT-4o (function calling) → tool execution via `tool_executor.py` → DynamoDB

### DynamoDB Multi-Table Design
Six separate tables (all prefixed `tf-`):
- `tf-users` — PK: `userId`
- `tf-training-plans` — PK: `userId`, SK: `planId`
- `tf-workout-days` — PK: `userId`, SK: `{planId}#W{week:02}#D{day}`
- `tf-health` — PK: `userId`, SK: `HEALTH#{date}`
- `tf-workouts` — PK: `userId`, SK: `{timestamp}#{uuid}`
- `tf-chat` — PK: `userId`, SK: `{timestamp}#{uuid}`

### AI Module (`backend/trainflow/ai/`)
- `openai_client.py`: OpenAI GPT-4o (primary) and GPT-4o-mini (summarisation). API key fetched from AWS Secrets Manager (`trainflow/openai-api-key`) at cold start, falls back to `OPENAI_API_KEY` env var.
- `chat_handler.py`: Agentic loop — up to 5 tool-call rounds, then returns final text reply. Every 20 messages triggers rolling summarisation via GPT-4o-mini.
- `context_builder.py`: Pre-loads user profile, active plan, health, and workout data before each chat turn.
- `tools.py`: 8 function-calling tool definitions (OpenAI format).
- `tool_executor.py`: Dispatches tool calls to DynamoDB operations.
- `prompts.py`: Builds system prompt from context snapshot.

### Key Implementation Details
- **Auth**: Always use `trainflow.shared.auth.extract_user_id(event)` to extract user ID from Cognito authorizer claims.
- **DynamoDB numbers**: Stored as `Decimal`; `trainflow/shared/db.py` handles conversion.
- **OpenAI package**: Vendored into `backend/` via `pip3 install -r requirements.txt -t backend/`. The `backend/.gitignore` excludes these from git.
- **Conversation memory**: Auto-summarised every 20 messages (GPT-4o-mini) to stay within context limits.
- **iOS Amplify config**: `TrainFlow/amplifyconfiguration.json` — fill in Cognito pool values after CDK deploy.

### Required Environment Variables (set via CDK)
`TF_USERS_TABLE`, `TF_PLANS_TABLE`, `TF_WORKOUT_DAYS_TABLE`, `TF_HEALTH_TABLE`, `TF_WORKOUTS_TABLE`, `TF_CHAT_TABLE`, `OPENAI_MODEL` (default: `gpt-4o`), `OPENAI_SECONDARY_MODEL` (default: `gpt-4o-mini`)

### CDK Stack Outputs
`ApiGatewayUrl`, `UserPoolId`, `UserPoolClientId`
