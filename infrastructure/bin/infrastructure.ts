#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { TrainFlowStack } from '../lib/trainflow-stack';

const app = new cdk.App();

new TrainFlowStack(app, 'TrainFlowStack', {
  env: { account: process.env.CDK_DEFAULT_ACCOUNT, region: 'ap-south-1' },
});
