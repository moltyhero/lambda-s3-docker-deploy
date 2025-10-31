# Lambda S3 File Reader with Docker

This repository contains infrastructure-as-code and GitHub Actions workflows to create an AWS Lambda function using a Docker image. The function reads a file from an S3 bucket and returns its contents in the HTTP response via a Lambda Function URL. The Docker image is stored in AWS Elastic Container Registry (ECR), and the deployment is managed using Terraform.

## Features

- **Lambda Function**: Reads the contents of an S3 file and responds with it.
- **Docker Image**: The Lambda function runs using a Docker image stored in ECR.
- **Infrastructure as Code**: Terraform is used to provision all AWS resources (S3 bucket, Lambda function, IAM roles, and ECR repository).
- **GitHub Actions**:
  - **Docker Build and Push**: Builds and pushes the Docker image to ECR when a PR is merged to `main`.
  - **Lambda Deployment**: Manually deploy the Lambda function via GitHub Actions workflow.

## Project Structure

- `Dockerfile`: Defines the Docker image for the Lambda function.
- `main.tf`: Terraform configuration to provision AWS resources.
- `.github/workflows`: Contains the GitHub Actions workflows for building the Docker image and deploying the Lambda function.

## Prerequisites

1. **GitHub Account** with access to GitHub Actions.
2. **AWS Account** with administrative access.
3. **AWS IAM OIDC Provider** configured for GitHub Actions (see setup below).

## Authentication Options

This repository supports two authentication methods:

- **`main` branch (recommended)**: Uses AWS OIDC for secure, temporary credentials - no long-lived access keys needed!
- **`secrets-auth` branch**: Uses traditional AWS access keys (legacy approach)

The instructions below are for the OIDC approach on `main` branch.

## Setup Instructions

### 1. Configure AWS OIDC (One-Time Setup)

Follow the complete step-by-step guide in **[SETUP_OIDC.md](SETUP_OIDC.md)** to:

1. Create IAM OIDC provider in AWS
2. Create IAM role with necessary permissions
3. Configure trust policy for your GitHub repository
4. Add `AWS_ROLE_ARN` secret to GitHub

**Prefer using access keys?** Switch to the `secrets-auth` branch for the traditional approach.

### 2. Create Terraform State Bucket (One-Time Setup)

Terraform needs an S3 bucket to store its state between workflow runs.

Follow the quick setup guide in **[TERRAFORM_STATE.md](TERRAFORM_STATE.md)** to:

1. Create an S3 bucket named `terraform-state-lambda-s3-docker`
2. Enable versioning (recommended)

**This is required** - without it, you'll get "already exists" errors on subsequent deployments.

### 3. Initial Infrastructure Deployment

1. **Manually trigger** the Deploy Lambda workflow from GitHub Actions
2. **Enter version**: `latest` (for initial deployment)
3. The workflow will:
   - Create S3 bucket: `lambda-s3-docker-demo-storage`
   - Create ECR repository: `lambda-s3-docker-demo-ecr`
   - Create Lambda function: `lambda-s3-docker-demo`
   - Create IAM roles and policies

**Note**: The first deployment may fail because the ECR repository will be empty. This is expected.

### 3. Build and Push Docker Image

1. **Create a Pull Request** with any change (or an empty commit)
2. **Merge the PR** to `main`
3. The Build workflow automatically runs and pushes the Docker image to ECR

### 4. Deploy Lambda with Docker Image

1. **Manually trigger** the Deploy Lambda workflow again
2. **Enter version**: `latest`
3. Lambda function is now fully deployed and functional! 🚀

### 5. GitHub Actions Workflows

#### Workflow 1: Build and Push Docker Image
- **Trigger**: Automatically runs when a PR is merged to `main` branch
- **What it does**: 
  - Builds the Docker image
  - Pushes to ECR with `latest` tag
- **File**: `.github/workflows/docker-build.yml`

#### Workflow 2: Deploy Lambda Function
- **Trigger**: Manually triggered via GitHub Actions UI
- **What it does**: 
  - Runs Terraform to update Lambda function with specified version
  - Outputs the Lambda Function URL
- **File**: `.github/workflows/lambda-deploy.yml`
- **Input**: `version` - The Lambda version to deploy (default: `latest`)
  - Can use semantic versioning: `v1.0.0`, `v2.1.3`
  - Or use `latest` to deploy the most recent build

#### Workflow 3: Cleanup Resources
- **Trigger**: Manually triggered via GitHub Actions UI
- **What it does**: 
  - Empties the S3 bucket
  - Deletes ECR images
  - Destroys all Terraform-managed infrastructure
- **File**: `.github/workflows/cleanup.yml`
- **Input**: `confirm` - Type `destroy` to confirm deletion (safety measure)

## Deployment Flow

1. **Make code changes** in a feature branch
2. **Create a Pull Request** to `main`
3. **Merge the PR** - Build workflow automatically runs and pushes Docker image
4. **Manually trigger** the deploy workflow
5. **Enter a version** (e.g., `v1.0.0`) or use `latest`
6. **Lambda is updated** with the new version

## Usage

### Upload a Test File to S3

You can upload a test file using AWS CLI (if you have it installed locally) or through the AWS Console:

**Using AWS CLI**:
```bash
echo "Hello from S3!" > test.txt
aws s3 cp test.txt s3://lambda-s3-docker-demo-storage/test.txt
```

**Using AWS Console**:
1. Go to S3 in AWS Console
2. Navigate to bucket `lambda-s3-docker-demo-storage`
3. Upload a file (e.g., `test.txt`)

### Trigger the Lambda Function

Get the Lambda Function URL from the Deploy workflow output, then send a GET request:
```bash
curl "https://<lambda-function-url>?bucket=lambda-s3-docker-demo-storage&file_key=test.txt"
```

Expected response:
```json
"Hello from S3!"
```

## Cleanup

To remove all resources and avoid charges:

### Using GitHub Actions (Recommended)

1. Go to **Actions** tab in GitHub
2. Select **Cleanup Resources** workflow
3. Click **Run workflow**
4. Type `destroy` in the confirmation field
5. Click **Run workflow**

The workflow will:
- Empty the S3 bucket
- Delete all ECR images
- Destroy all Terraform-managed resources (Lambda, IAM roles, etc.)

### Manual Cleanup (Alternative)

**Using AWS CLI**:
```bash
# Empty the S3 bucket first
aws s3 rm s3://lambda-s3-docker-demo-storage --recursive

# Then manually delete resources through AWS Console or run terraform destroy locally
```

**Using AWS Console**:
1. Empty and delete the S3 bucket
2. Delete the Lambda function
3. Delete the ECR repository
4. Delete the IAM role

**Note**: ECR images and CloudWatch logs may incur small charges (~$0.06-0.10/month).
