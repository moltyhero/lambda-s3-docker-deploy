terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}

# Variables
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-central-1"  # Set the region to Frankfurt

}

variable "project_name" {
  description = "Project name to use in resource names"
  type        = string
  default     = "lambda-s3-docker-demo"
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

# S3 Bucket
resource "aws_s3_bucket" "file_storage" {
  bucket = "${var.project_name}-storage"
}

# ECR Repository
resource "aws_ecr_repository" "lambda_image" {
  name = "${var.project_name}-ecr"
  image_scanning_configuration {
    scan_on_push = true
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Lambda to access S3
resource "aws_iam_role_policy" "lambda_s3_policy" {
  name = "${var.project_name}-s3-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.file_storage.arn,
          "${aws_s3_bucket.file_storage.arn}/*"
        ]
      }
    ]
  })
}

# CloudWatch Logs policy in case we want to troubleshoot later
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda Function
resource "aws_lambda_function" "file_reader" {
  function_name = "${var.project_name}"
  role          = aws_iam_role.lambda_role.arn
  timeout       = 30
  memory_size   = 256

  package_type = "Image"
  image_uri    = "${aws_ecr_repository.lambda_image.repository_url}:${var.image_tag}"

  environment {
    variables = {
      S3_BUCKET = aws_s3_bucket.file_storage.id
    }
  }
}

# Lambda Function URL
resource "aws_lambda_function_url" "file_reader_url" {
  function_name      = aws_lambda_function.file_reader.function_name
  authorization_type = "NONE"
}

# Outputs
output "lambda_function_url" {
  description = "URL endpoint for the Lambda function"
  value       = aws_lambda_function_url.file_reader_url.url
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.lambda_image.repository_url
}

output "s3_bucket_name" {
  description = "Name of the created S3 bucket"
  value       = aws_s3_bucket.file_storage.id
}