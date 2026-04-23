import { Construct } from 'constructs';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as cdk from 'aws-cdk-lib';

export interface TrainFlowAuthProps {
  postConfirmationLambda?: lambda.IFunction;
}

export class TrainFlowAuth extends Construct {
  public readonly userPool: cognito.UserPool;
  public readonly userPoolClient: cognito.UserPoolClient;

  constructor(scope: Construct, id: string, props?: TrainFlowAuthProps) {
    super(scope, id);

    // Cognito User Pool
    this.userPool = new cognito.UserPool(this, 'TrainFlowUsers', {
      userPoolName: 'TrainFlowUsers',
      selfSignUpEnabled: true,
      signInAliases: { email: true },
      autoVerify: { email: true },
      standardAttributes: {
        email: { required: true, mutable: true },
        fullname: { required: true, mutable: true },
      },
      passwordPolicy: {
        minLength: 8,
        requireUppercase: true,
        requireLowercase: true,
        requireDigits: true,
        requireSymbols: false,
      },
      mfa: cognito.Mfa.OPTIONAL,
      mfaSecondFactor: {
        sms: false,
        otp: true,
      },
      accountRecovery: cognito.AccountRecovery.EMAIL_ONLY,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      // Wire post-confirmation trigger if provided
      lambdaTriggers: props?.postConfirmationLambda
        ? { postConfirmation: props.postConfirmationLambda }
        : undefined,
    });

    // Allow Cognito to invoke the post-confirmation Lambda if provided
    if (props?.postConfirmationLambda) {
      props.postConfirmationLambda.addPermission('CognitoPostConfirmationInvoke', {
        principal: new iam.ServicePrincipal('cognito-idp.amazonaws.com'),
        sourceArn: this.userPool.userPoolArn,
      });
    }

    // App Client — iOS client, no secret
    this.userPoolClient = this.userPool.addClient('TrainFlowiOSClient', {
      userPoolClientName: 'TrainFlowiOSClient',
      authFlows: {
        userSrp: true,
        userPassword: true,
        custom: true,
      },
      generateSecret: false,
      supportedIdentityProviders: [
        cognito.UserPoolClientIdentityProvider.COGNITO,
      ],
      refreshTokenValidity: cdk.Duration.days(30),
      accessTokenValidity: cdk.Duration.hours(1),
      idTokenValidity: cdk.Duration.hours(1),
    });
  }
}
