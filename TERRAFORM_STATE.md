# Terraform State Backend Setup

## Why Do We Need This?

Terraform needs to store its **state** to track what resources it has created. Without a backend:
- ❌ State is lost after each GitHub Actions workflow run
- ❌ Terraform tries to recreate existing resources
- ❌ Causes "already exists" errors

With an S3 backend:
- ✅ State persists between workflow runs
- ✅ Multiple runs work correctly
- ✅ Terraform knows what already exists

## One-Time Setup

You need to create the S3 bucket for storing Terraform state **once** before running your workflows.

### Option 1: AWS Console (Easiest)

1. Go to **S3** in AWS Console
2. Click **Create bucket**
3. Bucket name: `terraform-state-lambda-s3-docker`
4. Region: `eu-central-1` (same as your main resources)
5. **Block all public access**: ✅ Check (keep state private!)
6. **Bucket Versioning**: Enable (recommended for safety)
7. Click **Create bucket**

### Option 2: AWS CLI

```bash
aws s3api create-bucket \
  --bucket terraform-state-lambda-s3-docker \
  --region eu-central-1 \
  --create-bucket-configuration LocationConstraint=eu-central-1

aws s3api put-bucket-versioning \
  --bucket terraform-state-lambda-s3-docker \
  --versioning-configuration Status=Enabled
```

### Option 3: Terraform (Bootstrap)

Create a temporary file `backend-setup.tf`:

```terraform
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-state-lambda-s3-docker"
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

Then run:
```bash
terraform init
terraform apply
```

After the bucket is created, delete `backend-setup.tf`.

## First Deployment After Setup

After creating the state bucket:

1. Run the **Cleanup Resources** workflow (if resources already exist)
   - Type `destroy` to confirm
   - This cleans up any existing resources

2. Run the **Deploy Lambda Function** workflow
   - Terraform will initialize the S3 backend
   - Resources will be created fresh
   - State will be stored in S3

3. Future deployments will work correctly
   - Terraform reads state from S3
   - Only applies changes (no "already exists" errors)

## Troubleshooting

### Error: "Failed to get existing workspaces"

The S3 bucket doesn't exist yet. Create it using one of the options above.

### Error: "Access Denied" on state bucket

Make sure your IAM role has S3 permissions (already included in the custom policy).

### Want to Reset Everything?

1. Run **Cleanup Resources** workflow
2. Manually delete the state bucket: `terraform-state-lambda-s3-docker`
3. Recreate the state bucket
4. Deploy again

## Security Notes

- ✅ State bucket is private (no public access)
- ✅ Versioning enabled (can recover from mistakes)
- ✅ Only your GitHub Actions role can access it
- ⚠️ State may contain sensitive data (handle carefully)

## Customizing the Bucket Name

If you want to use a different bucket name:

1. Change the bucket name in `main.tf`:
   ```terraform
   backend "s3" {
     bucket = "your-custom-bucket-name"
     key    = "lambda-deploy/terraform.tfstate"
     region = "eu-central-1"
   }
   ```

2. Create the bucket with your custom name
3. Redeploy

Make sure the bucket name is globally unique across all AWS accounts!
