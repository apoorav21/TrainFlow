import * as cdk from 'aws-cdk-lib';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';
import { TrainFlowDatabase } from './constructs/trainflow-database';
import { TrainFlowLambdas } from './constructs/trainflow-lambdas';
import { TrainFlowAuth } from './constructs/trainflow-auth';
import { TrainFlowApi } from './constructs/trainflow-api';

export class TrainFlowStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // --- Database (DynamoDB — 6 separate tables) ---
    const database = new TrainFlowDatabase(this, 'Database');

    // --- Auth (first pass — no trigger yet; we need userPool before Lambdas) ---
    // TrainFlowAuth accepts an optional postConfirmationLambda. We create Auth
    // without it here so we have a userPool to pass to Lambdas, then wire the
    // trigger below via the CfnUserPool escape hatch after Lambdas are created.
    const auth = new TrainFlowAuth(this, 'Auth');

    // --- Lambdas (need userPool for USER_POOL_ID env var) ---
    const lambdas = new TrainFlowLambdas(this, 'Lambdas', {
      usersTable: database.usersTable,
      plansTable: database.plansTable,
      workoutDaysTable: database.workoutDaysTable,
      healthTable: database.healthTable,
      workoutsTable: database.workoutsTable,
      chatTable: database.chatTable,
      userPool: auth.userPool,
    });

    // --- Wire post-confirmation trigger via escape hatch ---
    // Cognito UserPool CDK construct doesn't support adding triggers after creation,
    // so we use the underlying CfnUserPool L1 construct to set the Lambda config.
    const cfnUserPool = auth.userPool.node.defaultChild as cognito.CfnUserPool;
    cfnUserPool.lambdaConfig = {
      postConfirmation: lambdas.profileInitFn.functionArn,
      defineAuthChallenge: lambdas.defineChallengeFn.functionArn,
      createAuthChallenge: lambdas.createChallengeFn.functionArn,
      verifyAuthChallengeResponse: lambdas.verifyChallengeFn.functionArn,
    };

    // Grant Cognito permission to invoke all trigger Lambdas
    lambdas.profileInitFn.addPermission('CognitoPostConfirmationInvoke', {
      principal: new iam.ServicePrincipal('cognito-idp.amazonaws.com'),
      sourceArn: auth.userPool.userPoolArn,
    });
    lambdas.defineChallengeFn.addPermission('CognitoDefineChallengeInvoke', {
      principal: new iam.ServicePrincipal('cognito-idp.amazonaws.com'),
      sourceArn: auth.userPool.userPoolArn,
    });
    lambdas.createChallengeFn.addPermission('CognitoCreateChallengeInvoke', {
      principal: new iam.ServicePrincipal('cognito-idp.amazonaws.com'),
      sourceArn: auth.userPool.userPoolArn,
    });
    lambdas.verifyChallengeFn.addPermission('CognitoVerifyChallengeInvoke', {
      principal: new iam.ServicePrincipal('cognito-idp.amazonaws.com'),
      sourceArn: auth.userPool.userPoolArn,
    });

    // --- API Gateway ---
    const api = new TrainFlowApi(this, 'Api', {
      userPool: auth.userPool,
      lambdaFunctions: lambdas.functions,
    });

    // --- Stack Outputs ---
    new cdk.CfnOutput(this, 'TrainFlowApiGatewayUrl', {
      value: api.api.url,
      exportName: 'TrainFlow-ApiGatewayUrl',
    });

    new cdk.CfnOutput(this, 'TrainFlowUserPoolId', {
      value: auth.userPool.userPoolId,
      exportName: 'TrainFlow-UserPoolId',
    });

    new cdk.CfnOutput(this, 'TrainFlowUserPoolClientId', {
      value: auth.userPoolClient.userPoolClientId,
      exportName: 'TrainFlow-UserPoolClientId',
    });

    new cdk.CfnOutput(this, 'TrainFlowRegion', {
      value: 'ap-south-1',
      exportName: 'TrainFlow-Region',
    });
  }
}
