# Deployment Checklist

Use this checklist to ensure a smooth deployment of your AWS infrastructure.

## 📋 Pre-Deployment Checklist

### AWS Account Setup
- [ ] AWS account created and verified
- [ ] AWS CLI installed and configured
- [ ] IAM user created with appropriate permissions
- [ ] AWS access keys generated and secured
- [ ] Billing alerts configured
- [ ] Cost budget set up

### Tools Installation
- [ ] Terraform installed (>= 1.0)
- [ ] Ansible installed (>= 2.9)
- [ ] Python 3 installed
- [ ] Git installed
- [ ] SSH client available

### Project Configuration
- [ ] Repository cloned locally
- [ ] `terraform.tfvars` created from example
- [ ] SSH key pair created in AWS EC2
- [ ] Key pair name updated in `terraform.tfvars`
- [ ] Your IP address added to `allowed_ssh_cidr`
- [ ] Email address configured for alarms
- [ ] AWS region confirmed

### Optional Configuration
- [ ] Domain name registered (for HTTPS)
- [ ] Route53 hosted zone created (if using custom domain)
- [ ] Certificate settings configured in `terraform.tfvars`
- [ ] RDS settings reviewed and adjusted
- [ ] Auto Scaling parameters tuned

---

## 🚀 Deployment Steps

### Phase 1: Infrastructure Provisioning

#### Step 1: Validate Configuration
```bash
cd terraform/
terraform validate
terraform fmt
```
- [ ] No validation errors
- [ ] Code properly formatted

#### Step 2: Initialize Terraform
```bash
terraform init
```
- [ ] Providers downloaded successfully
- [ ] Backend initialized (if using remote state)
- [ ] No initialization errors

#### Step 3: Plan Infrastructure
```bash
terraform plan -out=tfplan
```
- [ ] Plan reviewed for accuracy
- [ ] Expected resources confirmed
- [ ] No unexpected deletions
- [ ] Resource count verified

#### Step 4: Apply Infrastructure
```bash
terraform apply tfplan
```
- [ ] Apply completed successfully
- [ ] All resources created
- [ ] Outputs displayed correctly
- [ ] No errors in logs

**⏱️ Expected Time: 10-15 minutes**

### Phase 2: Server Configuration

#### Step 5: Generate Ansible Inventory
```bash
terraform output -raw ansible_inventory > ../ansible/inventory.ini
```
- [ ] Inventory file generated
- [ ] Instance IPs populated
- [ ] SSH key path verified

#### Step 6: Test Connectivity
```bash
cd ../ansible/
ansible all -m ping
```
- [ ] All hosts reachable
- [ ] SSH authentication successful
- [ ] No connection errors

#### Step 7: Run Ansible Playbook
```bash
ansible-playbook playbook.yml
```
- [ ] Playbook executed successfully
- [ ] All tasks completed
- [ ] No failed tasks
- [ ] Application deployed

**⏱️ Expected Time: 5-10 minutes**

### Phase 3: Verification

#### Step 8: Infrastructure Verification
```bash
# Check ALB status
aws elbv2 describe-load-balancers \
  --names aws-infrastructure-automation-alb

# Check Auto Scaling Group
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names aws-infrastructure-automation-asg

# Check RDS (if enabled)
aws rds describe-db-instances \
  --db-instance-identifier aws-infrastructure-automation-db
```
- [ ] ALB is active and healthy
- [ ] Auto Scaling Group running
- [ ] Desired capacity met
- [ ] RDS instance available (if enabled)

#### Step 9: Application Testing
```bash
# Get ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test health endpoint
curl http://$ALB_DNS/health

# Test main application
curl http://$ALB_DNS/
```
- [ ] Health check returns 200 OK
- [ ] Application responds correctly
- [ ] No error messages

#### Step 10: Access Application
- [ ] Open browser to ALB DNS name
- [ ] Application loads successfully
- [ ] UI displays correctly
- [ ] No JavaScript errors

**⏱️ Expected Time: 5 minutes**

---

## 🔍 Post-Deployment Verification

### CloudWatch Monitoring
- [ ] Navigate to CloudWatch console
- [ ] Verify dashboard exists: `aws-infrastructure-automation-dashboard`
- [ ] Check metrics are being collected
- [ ] Confirm alarms are in OK state
- [ ] Verify logs are being received

### Security Verification
- [ ] Security groups configured correctly
- [ ] Only necessary ports open
- [ ] IAM roles attached to instances
- [ ] EBS volumes encrypted
- [ ] RDS instance encrypted (if enabled)
- [ ] VPC Flow Logs active

### Auto Scaling Test
- [ ] Generate load on application
- [ ] Monitor CPU metrics in CloudWatch
- [ ] Verify new instances launch when CPU > 70%
- [ ] Confirm instances terminate when CPU < 20%
- [ ] Check ALB distributes traffic properly

### Database Verification (if RDS enabled)
- [ ] RDS instance available
- [ ] Connection from EC2 successful
- [ ] Database credentials in Secrets Manager
- [ ] Automated backups configured
- [ ] Enhanced monitoring active
- [ ] Performance Insights enabled

### Email Notifications
- [ ] Check email for SNS subscription
- [ ] Confirm SNS subscription
- [ ] Test alarm by stopping an instance
- [ ] Verify alarm email received

---

## 🎯 Success Criteria

Your deployment is successful when:

✅ **Infrastructure**
- All Terraform resources created without errors
- ALB is in active state
- Auto Scaling Group running with desired capacity
- RDS instance available (if enabled)

✅ **Application**
- Health check endpoint returns 200 OK
- Application accessible via ALB DNS
- Web page loads correctly in browser
- No error messages in application logs

✅ **Monitoring**
- CloudWatch dashboard visible and populated
- All alarms in OK state
- Logs flowing to CloudWatch
- SNS subscription confirmed

✅ **Security**
- All resources encrypted at rest
- Security groups properly configured
- IAM roles attached
- VPC Flow Logs active

✅ **Auto Scaling**
- Instances can scale up under load
- Instances can scale down when idle
- ALB health checks passing
- Traffic distributed evenly

---

## 🚨 Troubleshooting Common Issues

### Issue: Terraform Apply Fails

**Error**: `InvalidKeyPair.NotFound`
- [ ] Verify SSH key pair exists in AWS
- [ ] Check key name in `terraform.tfvars`
- [ ] Ensure correct AWS region

**Error**: `UnauthorizedOperation`
- [ ] Verify AWS credentials
- [ ] Check IAM permissions
- [ ] Confirm AWS CLI configured

**Error**: `ResourceInUse`
- [ ] Check for existing resources with same names
- [ ] Review Terraform state
- [ ] Consider destroying old resources

### Issue: Ansible Connection Failed

**Error**: `Permission denied (publickey)`
- [ ] Verify SSH key path in `ansible.cfg`
- [ ] Check key file permissions: `chmod 400 key.pem`
- [ ] Confirm security group allows SSH from your IP
- [ ] Wait 2-3 minutes after EC2 instance creation

**Error**: `Host unreachable`
- [ ] Verify instance has public IP
- [ ] Check Internet Gateway attached
- [ ] Confirm route table configuration
- [ ] Verify network connectivity

### Issue: Application Not Accessible

**Error**: `Connection refused`
- [ ] Check application service status: `systemctl status aws-infrastructure-automation`
- [ ] Verify application listening on correct port
- [ ] Check security group allows traffic
- [ ] Review application logs

**Error**: `502 Bad Gateway`
- [ ] Verify target health in ALB
- [ ] Check application is running
- [ ] Review health check configuration
- [ ] Check instance connectivity

### Issue: Auto Scaling Not Working

**Problem**: Instances not launching
- [ ] Check launch template configuration
- [ ] Verify AMI ID is valid
- [ ] Check IAM instance profile
- [ ] Review Auto Scaling activity logs

**Problem**: Scaling policies not triggering
- [ ] Verify CloudWatch alarms configured
- [ ] Check alarm thresholds
- [ ] Ensure metrics are being published
- [ ] Review cooldown periods

### Issue: RDS Connection Failed

**Error**: `Could not connect to server`
- [ ] Verify RDS endpoint in application
- [ ] Check security group allows port 5432
- [ ] Confirm RDS instance is available
- [ ] Verify credentials in Secrets Manager

---

## 🧹 Cleanup Checklist

When you're done testing:

### Manual Cleanup
```bash
cd terraform/
terraform destroy
```

Verify deletion:
- [ ] Terraform destroy completed
- [ ] All EC2 instances terminated
- [ ] ALB deleted
- [ ] RDS instance deleted
- [ ] VPC resources removed
- [ ] CloudWatch logs retained as needed

### Cost Verification
- [ ] Check AWS billing console
- [ ] Verify no unexpected charges
- [ ] Confirm all resources deleted
- [ ] Review billing alerts

---

## 📝 Notes Section

Use this space for deployment-specific notes:

**Deployment Date**: ________________

**AWS Account ID**: ________________

**AWS Region**: ________________

**ALB DNS Name**: ________________

**Database Endpoint**: ________________

**Issues Encountered**:
1. 
2. 
3. 

**Resolution Notes**:
1. 
2. 
3. 

**Team Members**:
- Deployed by: ________________
- Reviewed by: ________________
- Approved by: ________________

---

## ✅ Final Sign-Off

- [ ] All checklist items completed
- [ ] Infrastructure verified working
- [ ] Monitoring confirmed active
- [ ] Documentation updated
- [ ] Team notified of deployment
- [ ] Runbook created for operations

**Deployment Status**: ⬜ Success  ⬜ Issues  ⬜ Failed

**Signed**: ________________  **Date**: ________________

---

**Need Help?** 
- Check [README.md](README.md) for detailed documentation
- Review [ARCHITECTURE.md](ARCHITECTURE.md) for system design
- See [CI-CD-SETUP.md](CI-CD-SETUP.md) for automation
- Read [PROJECT-SUMMARY.md](PROJECT-SUMMARY.md) for overview
