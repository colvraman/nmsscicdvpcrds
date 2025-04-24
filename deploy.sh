#!/bin/bash

set -e

# ---------------------------
# Deploy VPC
# ---------------------------
echo "Deploying VPC..."
aws cloudformation deploy \
  --template-file cft/vpc.yml \
  --stack-name vpc-stack \
  --capabilities CAPABILITY_NAMED_IAM

VPC_ID=$(aws cloudformation describe-stacks \
  --stack-name vpc-stack \
  --query "Stacks[0].Outputs[?OutputKey=='VPCId'].OutputValue" \
  --output text)

# ---------------------------
# Deploy Subnet
# ---------------------------
echo "Deploying Subnet..."
aws cloudformation deploy \
  --template-file cft/subnets.yml \
  --stack-name subnet-stack \
  --parameter-overrides VPCId=$VPC_ID

SUBNET_ID=$(aws cloudformation describe-stacks \
  --stack-name subnet-stack \
  --query "Stacks[0].Outputs[?OutputKey=='PublicSubnet1Id'].OutputValue" \
  --output text)

# ---------------------------
# Deploy Security Group
# ---------------------------
echo "Deploying Security Group..."
aws cloudformation deploy \
  --template-file cft/security-groups.yml \
  --stack-name sg-stack \
  --parameter-overrides VPCId=$VPC_ID

SG_ID=$(aws cloudformation describe-stacks \
  --stack-name sg-stack \
  --query "Stacks[0].Outputs[?OutputKey=='RDSSecurityGroupId'].OutputValue" \
  --output text)

# ---------------------------
# Deploy RDS PostgreSQL
# ---------------------------
echo "Deploying RDS..."
aws cloudformation deploy \
  --template-file cft/rds.yml \
  --stack-name rds-stack \
  --parameter-overrides VPCId=$VPC_ID SubnetId=$SUBNET_ID SGId=$SG_ID

# ---------------------------
# Deploy S3 Bucket
# ---------------------------
echo "Deploying S3..."
aws cloudformation deploy \
  --template-file cft/s3.yml \
  --stack-name s3-stack

BUCKET_NAME=$(aws cloudformation describe-stacks \
  --stack-name s3-stack \
  --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue" \
  --output text)

# ---------------------------
# Deploy CodeBuild Project
# ---------------------------
echo "Deploying CodeBuild..."
aws cloudformation deploy \
  --template-file cicd/codebuild.yml \
  --stack-name codebuild-stack \
  --parameter-overrides BucketName=$BUCKET_NAME \
  --capabilities CAPABILITY_NAMED_IAM

# ---------------------------
# Deploy CodePipeline
# ---------------------------
echo "Deploying CodePipeline..."

# Prompt for GitHub Token securely
read -sp "Enter your GitHub OAuth Token: " GITHUB_TOKEN
echo

aws cloudformation deploy \
  --template-file cicd/codepipeline.yml \
  --stack-name codepipeline-stack \
  --parameter-overrides BucketName=$BUCKET_NAME GitHubToken=$GITHUB_TOKEN \
  --capabilities CAPABILITY_NAMED_IAM

echo "✅ All resources deployed successfully."
