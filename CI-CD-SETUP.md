# CI/CD Setup Guide

## 🚀 Setting Up GitHub Actions CI/CD Pipeline

This guide walks you through setting up automated deployments using GitHub Actions.

## Prerequisites

1. GitHub repository created
2. AWS account with administrative access
3. SSH key pair for EC2 instances
4. Terraform code committed to repository

## Step 1: Create GitHub Secrets

Navigate to your GitHub repository:
`Settings → Secrets and variables → Actions → New repository secret`

### Required Secrets:

1. **AWS_ACCESS_KEY_ID**
   ```
   Your AWS access key ID
   ```

2. **AWS_SECRET_ACCESS_KEY**
   ```
   Your AWS secret access key
   ```

3. **TF_VAR_KEY_PAIR_NAME**
   ```
   Name of your EC2 SSH key pair (e.g., "my-key")
   ```

4. **TF_VAR_ALARM_EMAIL**
   ```
   Email address for CloudWatch alarms
   ```

5. **SSH_PRIVATE_KEY**
   ```
   Your EC2 SSH private key (entire .pem file content)
   -----BEGIN RSA PRIVATE KEY-----
   ...
   -----END RSA PRIVATE KEY-----
   ```

### Optional Secrets (for HTTPS):

6. **TF_VAR_DOMAIN_NAME** (if using custom domain)
   ```
   example.com
   ```

## Step 2: Configure AWS IAM for GitHub Actions

### Create IAM User for CI/CD

```bash
# Create IAM user
aws iam create-user --user-name github-actions-user

# Attach required policies
aws iam attach-user-policy \
  --user-name github-actions-user \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Create access keys
aws iam create-access-key --user-name github-actions-user
```

**⚠️ Security Best Practice**: Instead of `AdministratorAccess`, create a custom policy with only required permissions:

<details>
<summary>Click to see minimal IAM policy</summary>

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "vpc:*",
        "elasticloadbalancing:*",
        "autoscaling:*",
        "rds:*",
        "acm:*",
        "route53:*",
        "cloudwatch:*",
        "logs:*",
        "sns:*",
        "iam:*",
        "secretsmanager:*",
        "s3:*"
      ],
      "Resource": "*"
    }
  ]
}
```
</details>

## Step 3: Configure Terraform Backend (Optional but Recommended)

### Create S3 Bucket for State

```bash
# Create bucket
aws s3 mb s3://your-terraform-state-bucket --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket your-terraform-state-bucket \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'
```

### Create DynamoDB Table for State Locking

```bash
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### Update provider.tf

Uncomment and update the backend configuration in `terraform/provider.tf`:

```hcl
backend "s3" {
  bucket         = "your-terraform-state-bucket"
  key            = "infrastructure/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "terraform-state-lock"
}
```

## Step 4: Workflow Files

The following workflow files are already included in `.github/workflows/`:

### deploy.yml - Main Deployment Pipeline

**Triggers:**
- Push to `main` or `develop` branch
- Pull requests to `main`
- Manual workflow dispatch

**Jobs:**
1. **terraform-validate**: Validates Terraform configuration
2. **terraform-plan**: Creates execution plan (PRs only)
3. **terraform-apply**: Applies infrastructure changes (main branch only)
4. **ansible-deploy**: Configures servers with Ansible
5. **security-scan**: Scans for security vulnerabilities
6. **notify**: Sends deployment notifications

### destroy.yml - Destroy Infrastructure

**Trigger:** Manual workflow dispatch only

**Safety:** Requires typing "destroy" to confirm

## Step 5: Branch Protection Rules

Set up branch protection for `main`:

1. Go to `Settings → Branches → Add rule`
2. Branch name pattern: `main`
3. Enable:
   - ✅ Require pull request reviews before merging
   - ✅ Require status checks to pass before merging
   - ✅ Require branches to be up to date before merging
   - ✅ Include administrators

## Step 6: Test the Pipeline

### Test on Pull Request:

```bash
# Create feature branch
git checkout -b feature/test-deployment

# Make a small change
echo "# Test" >> README.md

# Commit and push
git add README.md
git commit -m "Test CI/CD pipeline"
git push origin feature/test-deployment

# Create pull request on GitHub
# Watch the workflow run: Actions tab
```

### Deploy to Production:

```bash
# Merge PR to main
git checkout main
git pull origin main

# Push triggers automatic deployment
# Check Actions tab for progress
```

## Step 7: Monitor Deployment

### View Workflow Logs

1. Navigate to `Actions` tab in GitHub
2. Click on the running workflow
3. Expand job steps to see detailed logs

### Check AWS Resources

```bash
# Get ALB DNS name
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?contains(LoadBalancerName, `aws-infrastructure`)].DNSName' \
  --output text

# Check Auto Scaling Group
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names aws-infrastructure-automation-asg

# Verify RDS
aws rds describe-db-instances \
  --query 'DBInstances[?DBInstanceIdentifier==`aws-infrastructure-automation-db`]'
```

## Step 8: Manual Deployment (Alternative)

If you prefer manual deployment without CI/CD:

```bash
# Deploy infrastructure
cd terraform/
terraform init
terraform apply

# Deploy application
cd ../ansible/
terraform output -raw ansible_inventory > inventory.ini
ansible-playbook playbook.yml
```

## Workflow Customization

### Modify Environment

Edit `.github/workflows/deploy.yml`:

```yaml
env:
  AWS_REGION: us-west-2  # Change region
  TF_VERSION: 1.7.0      # Update Terraform version
```

### Add Slack Notifications

Add to `notify` job in `deploy.yml`:

```yaml
- name: Notify Slack
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK_URL }}
    payload: |
      {
        "text": "Deployment ${{ job.status }}"
      }
```

### Add Email Notifications

```yaml
- name: Send Email
  uses: dawidd6/action-send-mail@v3
  with:
    server_address: smtp.gmail.com
    server_port: 465
    username: ${{ secrets.EMAIL_USERNAME }}
    password: ${{ secrets.EMAIL_PASSWORD }}
    subject: Deployment Status
    to: team@example.com
    from: CI/CD Pipeline
    body: Deployment completed with status ${{ job.status }}
```

## Troubleshooting

### Issue: Terraform State Lock

**Error**: `Error locking state: ConditionalCheckFailedException`

**Solution**:
```bash
# List locks
aws dynamodb scan --table-name terraform-state-lock

# Force unlock (use carefully!)
terraform force-unlock <LOCK_ID>
```

### Issue: SSH Connection Failed

**Error**: `Permission denied (publickey)`

**Solution**:
1. Verify SSH_PRIVATE_KEY secret is correct
2. Check key permissions: `chmod 600 ~/.ssh/id_rsa`
3. Verify key matches the EC2 key pair

### Issue: AWS Credentials Invalid

**Error**: `UnauthorizedOperation`

**Solution**:
1. Verify AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
2. Check IAM user permissions
3. Ensure keys haven't expired

### Issue: Workflow Not Triggering

**Solution**:
1. Check branch protection rules
2. Verify workflow file syntax: `yamllint .github/workflows/deploy.yml`
3. Check workflow permissions in repository settings

## Security Best Practices

1. **Rotate AWS Access Keys** every 90 days
2. **Use OIDC** instead of long-lived credentials (recommended):

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::ACCOUNT:role/GitHubActionsRole
    aws-region: us-east-1
```

3. **Enable GitHub Secret Scanning**
4. **Review workflow permissions**: Use least privilege
5. **Require manual approval** for production deployments

## Cost Monitoring

Monitor CI/CD costs:
- GitHub Actions: 2,000 minutes/month free (public repos)
- AWS resources: Use CloudWatch billing alarms
- Set up budget alerts in AWS Console

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Terraform Cloud Integration](https://www.terraform.io/cloud)
- [AWS CodePipeline Alternative](https://aws.amazon.com/codepipeline/)

---

**Last Updated**: January 2026  
**Version**: 1.0.0
