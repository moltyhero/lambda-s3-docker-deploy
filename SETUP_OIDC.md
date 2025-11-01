# AWS OIDC Setup for GitHub Actions

This guide shows how to set up AWS IAM OIDC provider to allow GitHub Actions to securely authenticate with AWS without long-lived credentials.

## Why OIDC?

- ✅ No long-lived AWS access keys to manage or rotate
- ✅ Temporary, automatically rotating credentials
- ✅ More secure - credentials can't be leaked
- ✅ Easy to share repo - each user deploys to their own AWS account
- ✅ GitHub recommended best practice

## One-Time AWS Setup

### Step 1: Create IAM OIDC Provider

1. Go to **IAM → Identity providers** in AWS Console
2. Click **Add provider**
3. Choose **OpenID Connect**
4. Provider URL: `https://token.actions.githubusercontent.com`
5. Audience: `sts.amazonaws.com`
6. Click **Add provider**

### Step 2: Create IAM Role

1. Go to **IAM → Roles** in AWS Console
2. Click **Create role**
3. Select **Web identity**
4. Identity provider: `token.actions.githubusercontent.com`
5. Audience: `sts.amazonaws.com`
6. **Fill in GitHub details** (recommended for security):
   - **GitHub organization**: Your GitHub username
   - **GitHub repository**: `lambda-s3-docker-deploy` 
   - **GitHub branch**: `main`
   
   *Note: These settings restrict the role to only your specific repo and branch. The wizard will auto-generate a secure trust policy based on these values.*
7. Click **Next**

### Step 3: Attach Permissions

Attach these AWS managed policies:
- `AmazonS3FullAccess`
- `AWSLambda_FullAccess`
- `IAMFullAccess`
- `AmazonEC2ContainerRegistryFullAccess`
- `CloudWatchLogsFullAccess`

**Or** create a custom policy with least privilege (see below for recommended policy).

### Step 4: Configure Trust Policy

**If you used the wizard and filled in GitHub details in Step 2:**
- AWS will auto-generate the trust policy for you
- Review it to ensure it looks similar to the examples below
- Your generated policy will include `ref:refs/heads/main` which is more restrictive and secure
- No need to edit manually - the wizard did it for you! ✅

**If you need to edit or create the trust policy manually:**

1. On the **Trust relationships** tab, edit the trust policy
2. Replace with this policy (update with your GitHub username and repo):

**For single user (just you):**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/lambda-s3-docker-deploy:*"
        }
      }
    }
  ]
}
```

**For sharing with collaborators or allowing forks:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:YOUR_GITHUB_USERNAME/lambda-s3-docker-deploy:*",
            "repo:COLLABORATOR_GITHUB_USERNAME/lambda-s3-docker-deploy:*"
          ]
        }
      }
    }
  ]
}
```

**Wildcard for any fork (use with caution):**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:*/lambda-s3-docker-deploy:*"
        }
      }
    }
  ]
}
```

**Important**: Replace:
- `YOUR_ACCOUNT_ID` with your AWS account ID
- `YOUR_GITHUB_USERNAME` with your GitHub username
- `COLLABORATOR_GITHUB_USERNAME` with your collaborator's username

**Note:** If you used the AWS wizard in Step 2, you likely don't need to modify the trust policy - it was already configured correctly!

3. Name the role: `GitHubActionsLambdaDeploy`
4. Click **Create role**

### Step 5: Copy Role ARN

1. Open the role you just created
2. Copy the **ARN** (looks like: `arn:aws:iam::123456789012:role/GitHubActionsLambdaDeploy`)

### Step 6: Add GitHub Secret

1. Go to your GitHub repository
2. Navigate to **Settings → Secrets and variables → Actions**
3. Click **New repository secret**
4. Name: `AWS_ROLE_ARN`
5. Value: Paste the role ARN from Step 5
6. Click **Add secret**

## Done! 🎉

Your workflows will now use OIDC authentication.

## Sharing Access with Others

### Option 1: Add as GitHub Collaborator (Easiest)
Perfect for when you want someone to use **your** AWS account:

1. Go to your repo: **Settings → Collaborators → Add people**
2. Add the collaborator's GitHub username
3. They can now run workflows that deploy to your AWS account
4. Use the **single user** trust policy above (no changes needed)

### Option 2: Allow Their Fork
If they want to fork your repo but still deploy to **your** AWS account:

1. Use the **sharing with collaborators** trust policy (add their fork to the array)
2. Share your `AWS_ROLE_ARN` with them
3. They add it as a secret in their forked repo
4. Their workflows deploy to your AWS account

### Option 3: Independent Deployment
If they want to deploy to **their own** AWS account:

1. They fork/clone the repo
2. They follow Steps 1-6 in **their own AWS account**
3. They use **their own** `AWS_ROLE_ARN` secret
4. Their workflows deploy to their AWS account (completely separate from yours)

## Troubleshooting

### Error: "Not authorized to perform sts:AssumeRoleWithWebIdentity"

- Check that the trust policy has the correct GitHub username and repo name
- Ensure the role ARN in GitHub secrets is correct

### Error: "Access Denied" during deployment

- Verify the IAM role has sufficient permissions
- Check that all required policies are attached

## Recommended Least Privilege Policy

For production use, replace the AWS managed policies with this custom policy:

**Note:** This policy includes permissions for Terraform to store its state in an S3 backend.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:PutBucketVersioning",
        "s3:GetBucketVersioning",
        "s3:GetBucketPolicy",
        "s3:PutBucketPolicy",
        "s3:DeleteBucketPolicy",
        "s3:GetBucketTagging",
        "s3:PutBucketTagging",
        "s3:GetBucketAcl",
        "s3:PutBucketAcl",
        "s3:GetBucketPublicAccessBlock",
        "s3:PutBucketPublicAccessBlock",
        "s3:GetBucketCORS",
        "s3:PutBucketCORS",
        "s3:GetBucketWebsite",
        "s3:PutBucketWebsite",
        "s3:DeleteBucketWebsite",
        "s3:GetBucketLogging",
        "s3:PutBucketLogging",
        "s3:GetEncryptionConfiguration",
        "s3:PutEncryptionConfiguration",
        "s3:GetLifecycleConfiguration",
        "s3:PutLifecycleConfiguration",
        "s3:GetReplicationConfiguration",
        "s3:PutReplicationConfiguration",
        "s3:GetAccelerateConfiguration",
        "s3:PutAccelerateConfiguration",
        "s3:GetBucketRequestPayment",
        "s3:PutBucketRequestPayment",
        "s3:GetBucketObjectLockConfiguration",
        "s3:PutBucketObjectLockConfiguration",
        "s3:GetBucketNotification",
        "s3:PutBucketNotification",
        "s3:GetBucketOwnershipControls",
        "s3:PutBucketOwnershipControls",
        "s3:GetIntelligentTieringConfiguration",
        "s3:PutIntelligentTieringConfiguration",
        "s3:GetBucketLocation",
        "ecr:CreateRepository",
        "ecr:DeleteRepository",
        "ecr:DescribeRepositories",
        "ecr:BatchGetImage",
        "ecr:BatchDeleteImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:GetAuthorizationToken",
        "ecr:DescribeImages",
        "ecr:ListTagsForResource",
        "ecr:TagResource",
        "ecr:UntagResource",
        "ecr:PutImageScanningConfiguration",
        "ecr:GetLifecyclePolicy",
        "ecr:PutLifecyclePolicy",
        "ecr:GetRepositoryPolicy",
        "ecr:SetRepositoryPolicy",
        "ecr:DeleteRepositoryPolicy",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "lambda:CreateFunction",
        "lambda:DeleteFunction",
        "lambda:UpdateFunctionCode",
        "lambda:UpdateFunctionConfiguration",
        "lambda:GetFunction",
        "lambda:ListVersionsByFunction",
        "lambda:AddPermission",
        "lambda:RemovePermission",
        "lambda:CreateFunctionUrlConfig",
        "lambda:DeleteFunctionUrlConfig",
        "lambda:GetFunctionUrlConfig",
        "lambda:TagResource",
        "lambda:UntagResource",
        "lambda:ListTags",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:GetRole",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:ListAttachedRolePolicies",
        "iam:ListRolePolicies",
        "iam:GetRolePolicy",
        "iam:ListInstanceProfilesForRole",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:ListRoleTags",
        "logs:CreateLogGroup",
        "logs:DeleteLogGroup",
        "logs:DescribeLogGroups",
        "logs:ListTagsLogGroup",
        "logs:TagLogGroup",
        "logs:UntagLogGroup"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": "lambda.amazonaws.com"
        }
      }
    }
  ]
}
```

## Alternative: Using Secrets

If you prefer using traditional AWS access keys, switch to the `secrets-auth` branch:

```bash
git checkout secrets-auth
```

The `secrets-auth` branch uses:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_ACCOUNT_ID`

However, OIDC (this `main` branch) is the recommended approach for security and ease of sharing.
