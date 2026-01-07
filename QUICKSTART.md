# Quick Start Guide

## 🚀 Deploy in 5 Minutes

### 1. Prerequisites Check
```bash
# Verify installations
terraform --version  # Should be >= 1.0
ansible --version    # Should be >= 2.9
aws --version        # AWS CLI installed

# Configure AWS credentials
aws configure
aws sts get-caller-identity  # Verify credentials work
```

### 2. Create SSH Key (if needed)
```bash
# Create key pair in AWS
aws ec2 create-key-pair --key-name aws-infra-key \
  --query 'KeyMaterial' --output text > ~/.ssh/aws-infra-key.pem

chmod 400 ~/.ssh/aws-infra-key.pem
```

### 3. Configure Terraform
```bash
cd terraform/

# Copy and edit configuration
cp terraform.tfvars.example terraform.tfvars

# Edit these required values:
# - key_pair_name = "aws-infra-key"
# - allowed_ssh_cidr = ["YOUR_IP/32"]  # Get your IP: curl ifconfig.me
# - alarm_email = "your.email@example.com"
```

### 4. Deploy Infrastructure
```bash
# Initialize and deploy
terraform init
terraform plan
terraform apply -auto-approve

# Wait 3-5 minutes for deployment
# Save the output IPs
```

### 5. Configure Servers
```bash
# Generate inventory
terraform output -raw ansible_inventory > ../ansible/inventory.ini

# Update Ansible config
cd ../ansible/
# Edit ansible.cfg: private_key_file = ~/.ssh/aws-infra-key.pem

# Deploy application
ansible-playbook playbook.yml
```

### 6. Test & Verify
```bash
# Get IP addresses
cd ../terraform
terraform output instance_public_ips

# Test application (replace with your IP)
curl http://YOUR_INSTANCE_IP
curl http://YOUR_INSTANCE_IP/health

# Open in browser
# http://YOUR_INSTANCE_IP
```

## 🎉 Success!

Your infrastructure is now deployed with:
- ✅ VPC and networking configured
- ✅ EC2 instances running
- ✅ Application deployed and accessible
- ✅ CloudWatch monitoring active
- ✅ Security groups configured

## 📊 View Monitoring

1. **CloudWatch Dashboard**:
   - AWS Console → CloudWatch → Dashboards
   - Open: `aws-infrastructure-automation-dashboard`

2. **Confirm SNS Email**:
   - Check your email for SNS subscription confirmation
   - Click "Confirm subscription"

## 🧹 Cleanup When Done

```bash
cd terraform/
terraform destroy -auto-approve
```

## ❓ Need Help?

Check the main [README.md](README.md) for detailed documentation and troubleshooting.

---

**Deployment Time**: ~10 minutes  
**Cost**: ~$56/month (can be reduced with spot instances)
