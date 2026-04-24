import * as path from 'path';
import { Construct } from 'constructs';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as logs from 'aws-cdk-lib/aws-logs';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as cdk from 'aws-cdk-lib';

export interface TrainFlowLambdasProps {
  usersTable: dynamodb.Table;
  plansTable: dynamodb.Table;
  workoutDaysTable: dynamodb.Table;
  healthTable: dynamodb.Table;
  workoutsTable: dynamodb.Table;
  chatTable: dynamodb.Table;
  userPool: cognito.UserPool;
}

const TF_LAMBDA_NAMES = [
  // Profile (post-confirmation Cognito trigger)
  'tf-profile-init',
  'tf-profile-get',
  'tf-profile-update',
  // Health
  'tf-health-sync',
  'tf-health-get',
  'tf-health-ai-summary',
  // Plans
  'tf-plan-get-active',
  'tf-plan-get',
  'tf-plan-create',
  'tf-plan-get-week',
  'tf-plan-update-day',
  'tf-plan-generate',
  // Workouts
  'tf-workout-log',
  'tf-workout-get',
  'tf-workout-delete',
  'tf-workout-report',
  'tf-workout-healthkit-sync',
  // Chat (main agentic AI endpoint)
  'tf-chat-message',
  'tf-chat-history',
  'tf-chat-clear',
  // Account
  'tf-account-delete',
] as const;

// Auth challenge triggers (custom auth / passwordless — separate list so they
// get a minimal role with only SES access, not DynamoDB)
const TF_AUTH_TRIGGER_NAMES = [
  'tf-auth-define-challenge',
  'tf-auth-create-challenge',
  'tf-auth-verify-challenge',
] as const;

export class TrainFlowLambdas extends Construct {
  public readonly functions: Record<string, lambda.Function> = {};
  public readonly profileInitFn: lambda.Function;
  public readonly defineChallengeFn: lambda.Function;
  public readonly createChallengeFn: lambda.Function;
  public readonly verifyChallengeFn: lambda.Function;

  constructor(scope: Construct, id: string, props: TrainFlowLambdasProps) {
    super(scope, id);

    const environment: Record<string, string> = {
      TF_USERS_TABLE: props.usersTable.tableName,
      TF_PLANS_TABLE: props.plansTable.tableName,
      TF_WORKOUT_DAYS_TABLE: props.workoutDaysTable.tableName,
      TF_HEALTH_TABLE: props.healthTable.tableName,
      TF_WORKOUTS_TABLE: props.workoutsTable.tableName,
      TF_CHAT_TABLE: props.chatTable.tableName,
      // OpenAI model IDs — override via env to switch model without redeploying
      OPENAI_MODEL: 'gpt-5.4',
      OPENAI_SECONDARY_MODEL: 'gpt-5.4-mini',
      OPENAI_PLAN_MODEL: 'gpt-5.4-nano',
      // OPENAI_API_KEY must be set manually on the tf-chat-message Lambda
      // after deployment: aws lambda update-function-configuration \
      //   --function-name tf-chat-message \
      //   --environment "Variables={...,OPENAI_API_KEY=sk-...}"
      // Or use Secrets Manager (see README) for production.
    };

    // DynamoDB policy — all 6 tables and their indexes
    const dynamoDbPolicy = new iam.PolicyStatement({
      actions: [
        'dynamodb:GetItem',
        'dynamodb:PutItem',
        'dynamodb:UpdateItem',
        'dynamodb:DeleteItem',
        'dynamodb:Query',
        'dynamodb:BatchWriteItem',
      ],
      resources: [
        props.usersTable.tableArn,
        `${props.usersTable.tableArn}/index/*`,
        props.plansTable.tableArn,
        `${props.plansTable.tableArn}/index/*`,
        props.workoutDaysTable.tableArn,
        `${props.workoutDaysTable.tableArn}/index/*`,
        props.healthTable.tableArn,
        `${props.healthTable.tableArn}/index/*`,
        props.workoutsTable.tableArn,
        `${props.workoutsTable.tableArn}/index/*`,
        props.chatTable.tableArn,
        `${props.chatTable.tableArn}/index/*`,
      ],
    });

    // Secrets Manager policy — allows the chat Lambda to retrieve the OpenAI
    // API key from a secret named "trainflow/openai-api-key".
    // To create the secret: aws secretsmanager create-secret \
    //   --name trainflow/openai-api-key --secret-string '{"OPENAI_API_KEY":"sk-..."}'
    const secretsPolicy = new iam.PolicyStatement({
      actions: ['secretsmanager:GetSecretValue'],
      resources: ['arn:aws:secretsmanager:*:*:secret:trainflow/openai-api-key*'],
    });

    // Code asset: backend/ directory (zipped as-is).
    // The openai package must be installed into the backend directory before deploy:
    //   pip install -r backend/requirements.txt -t backend/
    // Handler paths use Python module notation (e.g. trainflow.handlers.profile.index.handler).
    const backendAsset = lambda.Code.fromAsset(
      path.join(__dirname, '../../../backend'),
    );

    // Map each logical Lambda name to its Python module handler path
    const handlerMap: Record<string, string> = {
      'tf-profile-init':    'trainflow.handlers.profile.init.index.handler',
      'tf-profile-get':     'trainflow.handlers.profile.index.handler',
      'tf-profile-update':  'trainflow.handlers.profile.index.handler',
      'tf-health-sync':          'trainflow.handlers.health.index.handler',
      'tf-health-get':           'trainflow.handlers.health.index.handler',
      'tf-health-ai-summary':    'trainflow.handlers.health.ai_summary.index.handler',
      'tf-plan-get-active': 'trainflow.handlers.plans.get_active.index.handler',
      'tf-plan-get':        'trainflow.handlers.plans.get.index.handler',
      'tf-plan-create':     'trainflow.handlers.plans.create.index.handler',
      'tf-plan-get-week':   'trainflow.handlers.plans.get_week.index.handler',
      'tf-plan-update-day': 'trainflow.handlers.plans.update_day.index.handler',
      'tf-workout-log':              'trainflow.handlers.workouts.log.index.handler',
      'tf-workout-get':              'trainflow.handlers.workouts.get.index.handler',
      'tf-workout-delete':           'trainflow.handlers.workouts.delete.index.handler',
      'tf-workout-report':           'trainflow.handlers.workouts.report.index.handler',
      'tf-workout-healthkit-sync':   'trainflow.handlers.workouts.healthkit_sync.index.handler',
      'tf-plan-generate':   'trainflow.handlers.plans.generate.index.handler',
      'tf-chat-message':    'trainflow.handlers.chat.message.index.handler',
      'tf-chat-history':    'trainflow.handlers.chat.history.index.handler',
      'tf-chat-clear':      'trainflow.handlers.chat.clear.index.handler',
      'tf-account-delete':  'trainflow.handlers.account.delete.index.handler',
    };

    // Create all Lambda functions
    for (const name of TF_LAMBDA_NAMES) {
      // Convert kebab-case to PascalCase for CDK construct ID
      const constructId = name
        .split('-')
        .map((s) => s.charAt(0).toUpperCase() + s.slice(1))
        .join('');

      const isChatMessage = name === 'tf-chat-message';
      const isPlanGenerate = name === 'tf-plan-generate';
      const isWorkoutReport = name === 'tf-workout-report';
      const isHealthAISummary = name === 'tf-health-ai-summary';

      const timeout = isChatMessage ? 60 : isPlanGenerate ? 900 : 30;
      const memorySize = (isChatMessage || isPlanGenerate) ? 512 : 256;

      const fn = new lambda.Function(this, `${constructId}Fn`, {
        functionName: name,
        runtime: lambda.Runtime.PYTHON_3_12,
        handler: handlerMap[name],
        code: backendAsset,
        environment,
        timeout: cdk.Duration.seconds(timeout),
        memorySize,
      });

      fn.addToRolePolicy(dynamoDbPolicy);
      // Lambdas that call OpenAI need Secrets Manager access
      if (isChatMessage || isPlanGenerate || isWorkoutReport || isHealthAISummary) {
        fn.addToRolePolicy(secretsPolicy);
      }

      // Log group — 7 day retention, DESTROY for easy cleanup
      new logs.LogGroup(this, `${constructId}LogGroup`, {
        logGroupName: `/aws/lambda/${name}`,
        retention: logs.RetentionDays.ONE_WEEK,
        removalPolicy: cdk.RemovalPolicy.DESTROY,
      });

      this.functions[name] = fn;
    }

    // Allow tf-chat-message to invoke tf-plan-generate asynchronously
    this.functions['tf-plan-generate'].grantInvoke(
      this.functions['tf-chat-message'],
    );

    // Expose the post-confirmation trigger Lambda directly
    this.profileInitFn = this.functions['tf-profile-init'];

    // --- Custom auth challenge Lambdas (passwordless / email-OTP) ---
    const sesPolicy = new iam.PolicyStatement({
      actions: ['ses:SendEmail', 'ses:SendRawEmail'],
      resources: ['*'],
    });

    const authTriggerHandlers: Record<string, string> = {
      'tf-auth-define-challenge': 'trainflow.handlers.auth.define_challenge.handler',
      'tf-auth-create-challenge': 'trainflow.handlers.auth.create_challenge.handler',
      'tf-auth-verify-challenge': 'trainflow.handlers.auth.verify_challenge.handler',
    };

    for (const name of TF_AUTH_TRIGGER_NAMES) {
      const constructId = name
        .split('-')
        .map((s) => s.charAt(0).toUpperCase() + s.slice(1))
        .join('');

      const fn = new lambda.Function(this, `${constructId}Fn`, {
        functionName: name,
        runtime: lambda.Runtime.PYTHON_3_12,
        handler: authTriggerHandlers[name],
        code: backendAsset,
        timeout: cdk.Duration.seconds(15),
        memorySize: 128,
        environment: {
          FROM_EMAIL: 'raoapoorav@gmail.com',
        },
      });

      if (name === 'tf-auth-create-challenge') {
        fn.addToRolePolicy(sesPolicy);
      }

      new logs.LogGroup(this, `${constructId}LogGroup`, {
        logGroupName: `/aws/lambda/${name}`,
        retention: logs.RetentionDays.ONE_WEEK,
        removalPolicy: cdk.RemovalPolicy.DESTROY,
      });

      this.functions[name] = fn;
    }

    this.defineChallengeFn = this.functions['tf-auth-define-challenge'];
    this.createChallengeFn = this.functions['tf-auth-create-challenge'];
    this.verifyChallengeFn = this.functions['tf-auth-verify-challenge'];
  }
}
