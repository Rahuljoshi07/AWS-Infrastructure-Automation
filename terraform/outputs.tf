# VPC Outputs
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

# EC2 Outputs
output "instance_ids" {
  description = "List of EC2 instance IDs"
  value       = aws_instance.web[*].id
}

output "instance_public_ips" {
  description = "List of public IP addresses of EC2 instances"
  value       = aws_eip.web[*].public_ip
}

output "instance_private_ips" {
  description = "List of private IP addresses of EC2 instances"
  value       = aws_instance.web[*].private_ip
}

output "instance_public_dns" {
  description = "List of public DNS names of EC2 instances"
  value       = aws_instance.web[*].public_dns
}

# Security Group Outputs
output "web_security_group_id" {
  description = "ID of the web security group"
  value       = aws_security_group.web_sg.id
}

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb_sg.id
}

# IAM Outputs
output "ec2_iam_role_arn" {
  description = "ARN of the EC2 IAM role"
  value       = aws_iam_role.ec2_role.arn
}

output "ec2_instance_profile_name" {
  description = "Name of the EC2 instance profile"
  value       = aws_iam_instance_profile.ec2_profile.name
}

# CloudWatch Outputs
output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.ec2_logs.name
}

output "cloudwatch_dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for CloudWatch alarms"
  value       = aws_sns_topic.cloudwatch_alarms.arn
}

# Connection Information
output "ssh_connection_commands" {
  description = "SSH commands to connect to instances"
  value = [
    for i, ip in aws_eip.web[*].public_ip :
    "ssh -i /path/to/${var.key_pair_name}.pem ec2-user@${ip}"
  ]
}

# ALB Outputs
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "alb_url" {
  description = "URL to access the application via ALB"
  value       = var.enable_https ? "https://${var.domain_name}" : "http://${aws_lb.main.dns_name}"
}

# Auto Scaling Outputs
output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.main.name
}

output "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.main.arn
}

# RDS Outputs
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = var.enable_rds ? aws_db_instance.main[0].endpoint : "RDS not enabled"
}

output "rds_database_name" {
  description = "RDS database name"
  value       = var.enable_rds ? aws_db_instance.main[0].db_name : "RDS not enabled"
}

output "rds_secret_arn" {
  description = "ARN of the Secrets Manager secret containing DB credentials"
  value       = var.enable_rds ? aws_secretsmanager_secret.db_password[0].arn : "RDS not enabled"
  sensitive   = true
}

# SSL Certificate Outputs
output "acm_certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = var.enable_https ? aws_acm_certificate.main[0].arn : "HTTPS not enabled"
}

# Ansible Inventory Output
output "ansible_inventory" {
  description = "Ansible inventory format"
  value = templatefile("${path.module}/templates/inventory.tpl", {
    instances = [
      for i, instance in aws_instance.web :
      {
        name       = instance.tags["Name"]
        public_ip  = aws_eip.web[i].public_ip
        private_ip = instance.private_ip
        id         = instance.id
      }
    ]
  })
  sensitive = false
}
