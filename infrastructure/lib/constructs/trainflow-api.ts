import { Construct } from 'constructs';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as lambda from 'aws-cdk-lib/aws-lambda';

export interface TrainFlowApiProps {
  userPool: cognito.UserPool;
  lambdaFunctions: Record<string, lambda.Function>;
}

export class TrainFlowApi extends Construct {
  public readonly api: apigateway.RestApi;

  constructor(scope: Construct, id: string, props: TrainFlowApiProps) {
    super(scope, id);

    // REST API
    this.api = new apigateway.RestApi(this, 'TrainFlowAPI', {
      restApiName: 'TrainFlowAPI',
      deployOptions: {
        stageName: 'prod',
        throttlingBurstLimit: 500,
        throttlingRateLimit: 200,
      },
      defaultCorsPreflightOptions: {
        allowOrigins: apigateway.Cors.ALL_ORIGINS,
        allowMethods: apigateway.Cors.ALL_METHODS,
      },
    });

    // Cognito authorizer
    const authorizer = new apigateway.CognitoUserPoolsAuthorizer(this, 'TrainFlowCognitoAuthorizer', {
      cognitoUserPools: [props.userPool],
      authorizerName: 'TrainFlowCognitoAuthorizer',
    });

    const authOptions: apigateway.MethodOptions = {
      authorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    };

    const integration = (name: string): apigateway.LambdaIntegration => {
      return new apigateway.LambdaIntegration(props.lambdaFunctions[name]);
    };

    // --- /profile ---
    // POST /profile (init) is NOT exposed — triggered by Cognito post-confirmation
    const profile = this.api.root.addResource('profile');
    profile.addMethod('GET', integration('tf-profile-get'), authOptions);
    profile.addMethod('PUT', integration('tf-profile-update'), authOptions);

    // --- /health ---
    const health = this.api.root.addResource('health');
    health.addResource('sync').addMethod('POST', integration('tf-health-sync'), authOptions);
    health.addMethod('GET', integration('tf-health-get'), authOptions);
    health.addResource('ai-summary').addMethod('GET', integration('tf-health-ai-summary'), authOptions);

    // --- /plans ---
    const plans = this.api.root.addResource('plans');
    plans.addResource('active').addMethod('GET', integration('tf-plan-get-active'), authOptions);
    plans.addMethod('POST', integration('tf-plan-create'), authOptions);

    const planId = plans.addResource('{planId}');
    planId.addMethod('GET', integration('tf-plan-get'), authOptions);

    const weeks = planId.addResource('weeks');
    weeks.addResource('{weekNum}').addMethod('GET', integration('tf-plan-get-week'), authOptions);

    const days = planId.addResource('days');
    days.addResource('{dayId}').addMethod('PUT', integration('tf-plan-update-day'), authOptions);

    // --- /workouts ---
    const workouts = this.api.root.addResource('workouts');
    workouts.addMethod('POST', integration('tf-workout-log'), authOptions);
    workouts.addMethod('GET', integration('tf-workout-get'), authOptions);
    workouts.addResource('report').addMethod('POST', integration('tf-workout-report'), authOptions);
    workouts.addResource('healthkit-sync').addMethod('POST', integration('tf-workout-healthkit-sync'), authOptions);
    workouts.addResource('{sk}').addMethod('DELETE', integration('tf-workout-delete'), authOptions);

    // --- /chat ---
    const chat = this.api.root.addResource('chat');
    chat.addResource('message').addMethod('POST', integration('tf-chat-message'), authOptions);
    chat.addResource('history').addMethod('GET', integration('tf-chat-history'), authOptions);
    chat.addMethod('DELETE', integration('tf-chat-clear'), authOptions);

    // --- /account ---
    const account = this.api.root.addResource('account');
    account.addMethod('DELETE', integration('tf-account-delete'), authOptions);
  }
}
