# Lambda S3 File Reader with Docker

This repository contains infrastructure-as-code and GitHub Actions workflows to create an AWS Lambda function using a Docker image. The function reads a file from an S3 bucket and returns its contents in the HTTP response via a Lambda Function URL. The Docker image is stored in AWS Elastic Container Registry (ECR), and the deployment is managed using Terraform.

## Features

- **Lambda Function**: Reads the contents of an S3 file and responds with it.
- **Docker Image**: The Lambda function runs using a Docker image stored in ECR.
- **Infrastructure as Code**: Terraform is used to provision all AWS resources (S3 bucket, Lambda function, IAM roles, and ECR repository).
- **GitHub Actions**:
  - **Docker Build and Push**: Builds and pushes the Docker image to ECR upon merge to `master`.
  - **Lambda Deployment**: Manually deploy a new version of the Lambda function with a specified Docker image tag (or defaults to `latest`).

## Project Structure

- `Dockerfile`: Defines the Docker image for the Lambda function.
- `main.tf`: Terraform configuration to provision AWS resources.
- `.github/workflows`: Contains the GitHub Actions workflows for building the Docker image and deploying the Lambda function.

## Prerequisites

1. **AWS CLI** configured with access to your AWS account.
2. **Terraform** installed on your local machine.
3. **Docker** installed and running locally.
4. **GitHub Actions Secrets**:
   - `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`: Your AWS credentials for deploying resources.
   - `AWS_ACCOUNT_ID`: Your AWS account ID.
   - `AWS_REGION`: Set to `eu-central-1` (Frankfurt) as per the project configuration.

## Setup Instructions

### 1. Clone the Repository
```bash
git clone https://github.com/your-repo/lambda-s3-file-reader.git
cd lambda-s3-file-reader
```

### 2. Docker Image Creation and ECR Push

Run the following commands to authenticate with ECR, build the Docker image, and push it to the ECR repository:

```bash
# Authenticate Docker to ECR
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin <your-aws-account-id>.dkr.ecr.eu-central-1.amazonaws.com

# Build Docker Image
docker build -t lambda-s3-file-reader .

# Tag Docker Image
docker tag lambda-s3-file-reader:latest <your-aws-account-id>.dkr.ecr.eu-central-1.amazonaws.com/lambda-s3-file-reader-repo:latest

# Push to ECR
docker push <your-aws-account-id>.dkr.ecr.eu-central-1.amazonaws.com/lambda-s3-file-reader-repo:latest
```

### 3. Deploy the Infrastructure with Terraform

```bash
terraform init
terraform apply
```

This will create:
- The S3 bucket.
- The Lambda function using the Docker image.
- The IAM roles and policies.
- The Lambda Function URL.

### 4. GitHub Actions Workflows

#### Workflow 1: Build Docker Image on Merge to Master
Upon merging a PR into the `master` branch, the Docker image is automatically built and pushed to ECR.

#### Workflow 2: Manual Lambda Deployment
You can manually deploy a new version of the Lambda function by triggering the `deploy-lambda` workflow in GitHub Actions. You can specify a Docker image version (tag) or default to `latest`.

## Usage

### Trigger the Lambda Function
Once the Terraform deployment is complete, you can find the Lambda Function URL in the AWS Console or the Terraform output. Send an HTTP GET request to the function URL to retrieve the contents of the file from the S3 bucket.

Example:
```bash
curl https://<lambda-function-url>
```

## GitHub Actions Setup

Ensure the following secrets are set up in your GitHub repository:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_ACCOUNT_ID`
- `AWS_REGION`

## Cleanup

To destroy the created AWS resources, run:
```bash
terraform destroy
```
