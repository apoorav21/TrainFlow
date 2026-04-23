import { Construct } from 'constructs';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as cdk from 'aws-cdk-lib';

export class TrainFlowDatabase extends Construct {
  public readonly usersTable: dynamodb.Table;
  public readonly plansTable: dynamodb.Table;
  public readonly workoutDaysTable: dynamodb.Table;
  public readonly healthTable: dynamodb.Table;
  public readonly workoutsTable: dynamodb.Table;
  public readonly chatTable: dynamodb.Table;

  constructor(scope: Construct, id: string) {
    super(scope, id);

    // Table 1: tf-users
    // Single record per user — no SK needed
    this.usersTable = new dynamodb.Table(this, 'TfUsersTable', {
      tableName: 'tf-users',
      partitionKey: { name: 'userId', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    // Table 2: tf-training-plans
    // GSI: ActivePlanIndex (userId, isActive) — quickly get the active plan
    this.plansTable = new dynamodb.Table(this, 'TfPlansTable', {
      tableName: 'tf-training-plans',
      partitionKey: { name: 'userId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'planId', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    this.plansTable.addGlobalSecondaryIndex({
      indexName: 'ActivePlanIndex',
      partitionKey: { name: 'userId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'isActive', type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.ALL,
    });

    // Table 3: tf-workout-days
    // SK format: plan123#W01#D1
    // GSI: DateIndex (userId, scheduledDate) — get today's workout
    this.workoutDaysTable = new dynamodb.Table(this, 'TfWorkoutDaysTable', {
      tableName: 'tf-workout-days',
      partitionKey: { name: 'userId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'planWeekDay', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    this.workoutDaysTable.addGlobalSecondaryIndex({
      indexName: 'DateIndex',
      partitionKey: { name: 'userId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'scheduledDate', type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.ALL,
    });

    // Table 4: tf-health-data
    // SK: date (YYYY-MM-DD)
    this.healthTable = new dynamodb.Table(this, 'TfHealthTable', {
      tableName: 'tf-health-data',
      partitionKey: { name: 'userId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'date', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    // Table 5: tf-workouts
    // SK: timestamp (ISO8601)
    // GSI: DateIndex (userId, scheduledDate)
    // TTL: ttl (expire after 1 year)
    this.workoutsTable = new dynamodb.Table(this, 'TfWorkoutsTable', {
      tableName: 'tf-workouts',
      partitionKey: { name: 'userId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'timestamp', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      timeToLiveAttribute: 'ttl',
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    this.workoutsTable.addGlobalSecondaryIndex({
      indexName: 'DateIndex',
      partitionKey: { name: 'userId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'scheduledDate', type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.ALL,
    });

    // Table 6: tf-chat-messages
    // SK: {timestamp}#{uuid} for messages, SUMMARY for rolling summary
    // TTL: ttl (expire after 90 days)
    this.chatTable = new dynamodb.Table(this, 'TfChatTable', {
      tableName: 'tf-chat-messages',
      partitionKey: { name: 'userId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'msgId', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      timeToLiveAttribute: 'ttl',
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });
  }
}
