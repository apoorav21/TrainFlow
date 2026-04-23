# Health Buddy Infrastructure

AWS CDK infrastructure for the Health & Workout Buddy iOS app.

## Prerequisites

- Node.js 18+
- AWS CDK CLI: `npm install -g aws-cdk`
- AWS credentials configured

## Setup

```bash
npm install
npm run build
```

## Deploy

```bash
# Production
cdk deploy

# Development (resources use DESTROY removal policy)
cdk deploy -c isDev=true
```

## Stack Outputs

After deployment, the stack exports:

- `ApiGatewayUrl` - REST API base URL
- `UserPoolId` - Cognito User Pool ID
- `UserPoolClientId` - Cognito App Client ID
- `IdentityPoolId` - Cognito Identity Pool ID
- `DynamoDBTableName` - DynamoDB table name
- `S3BucketName` - S3 data bucket name
- `TimestreamDatabaseName` - Timestream database name
- `TimestreamTableName` - Timestream table name
- `EventBusName` - EventBridge custom bus name
- `SnsTopicArn` - SNS notifications topic ARN
