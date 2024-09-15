provider "aws" {
  region = "eu-central-1"  # Set the region to Frankfurt
}

# S3 Bucket for storing files
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "lambda-s3-file-reader-bucket"  # Meaningful, globally unique bucket name
}

# IAM Role for Lambda execution
resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda-s3-file-reader-execution-role"  # Meaningful role name
  
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
  role   = aws_iam_role.lambda_execution_role.id
  policy = jsonencode({
    Version = "2012-10-17",  # Policy version, keeping it default
    Statement = [
      {
        Action = ["s3:GetObject"],  # Allow read access to S3 objects
        Effect = "Allow",
        Resource = "arn:aws:s3:::${aws_s3_bucket.lambda_bucket.bucket_name}/*"
      }
    ]
  })
}

# ECR Repository for Docker image
resource "aws_ecr_repository" "lambda_repository" {
  name = "lambda-s3-file-reader-repo"  # Unique ECR repository name
}

# Lambda Function using the Docker image from ECR
resource "aws_lambda_function" "lambda_function" {
  function_name = "lambda-s3-file-reader"  # Meaningful Lambda function name
  image_uri     = "${aws_ecr_repository.lambda_repository.repository_url}:latest"
  role          = aws_iam_role.lambda_execution_role.arn
}

# Lambda Function URL to access the Lambda via HTTP
resource "aws_lambda_function_url" "lambda_function_url" {
  function_name        = aws_lambda_function.lambda_function.function_name
  authorization_type   = "NONE"  # No authentication required for now
}
