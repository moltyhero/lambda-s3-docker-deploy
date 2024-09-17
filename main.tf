provider "aws" {
  region = "eu-central-1"  # Set the region to Frankfurt
}

variable "image_version" {
  description = "The version tag for the Docker image in ECR"
  default     = "latest"
}

# Data sources to check for existing resources
data "aws_s3_bucket" "existing_bucket" {
  bucket = "lambda-s3-file-reader-bucket"
}

data "aws_iam_role" "existing_role" {
  name = "lambda-s3-file-reader-execution-role"
}

data "aws_ecr_repository" "existing_repository" {
  name = "lambda-s3-file-reader-repo"
}

# S3 Bucket for storing files
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "lambda-s3-file-reader-bucket"  # Meaningful, globally unique bucket name
  count  = length(data.aws_s3_bucket.existing_bucket.id) == 0 ? 1 : 0

  lifecycle {
    prevent_destroy = true
  }
}

# IAM Role for Lambda execution
resource "aws_iam_role" "lambda_execution_role" {
  name  = "lambda-s3-file-reader-execution-role"  # Meaningful role name
  count = length(data.aws_iam_role.existing_role.id) == 0 ? 1 : 0

  assume_role_policy = jsonencode({
    Version = "2012-10-17",  # Policy version, keeping it default
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# IAM Policy granting Lambda access to S3 bucket
resource "aws_iam_role_policy" "s3_policy" {
  name   = "lambda-s3-read-access-policy"  # Descriptive policy name
  role   = aws_iam_role.lambda_execution_role[count.index].id
  policy = jsonencode({
    Version = "2012-10-17",  # Policy version, keeping it default
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::lambda-s3-file-reader-bucket",
          "arn:aws:s3:::lambda-s3-file-reader-bucket/*"
        ]
      }
    ]
  })
}

# ECR Repository for Docker image
resource "aws_ecr_repository" "lambda_repository" {
  name  = "lambda-s3-file-reader-repo"
  count = length(data.aws_ecr_repository.existing_repository.id) == 0 ? 1 : 0
}

# Lambda Function using the Docker image from ECR
resource "aws_lambda_function" "lambda_function" {
  function_name = "lambda-s3-file-reader"
  role          = aws_iam_role.lambda_execution_role[count.index].arn
  package_type  = "Image"

  # Reference the ECR image URI
  image_uri = "${aws_ecr_repository.lambda_repository[count.index].repository_url}:${var.image_version}"

  environment {
    variables = {
      S3_BUCKET = aws_s3_bucket.lambda_bucket[count.index].bucket
    }
  }
}

# Lambda Function URL to access the Lambda via HTTP
resource "aws_lambda_function_url" "lambda_function_url" {
  function_name        = aws_lambda_function.lambda_function.function_name
  authorization_type   = "NONE"  # No authentication required for now
}
