# Data source to get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 Instances
resource "aws_instance" "web" {
  count                  = var.instance_count
  ami                    = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[count.index % length(aws_subnet.public)].id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = var.key_pair_name

  monitoring = var.enable_detailed_monitoring

  user_data = <<-EOF
              #!/bin/bash
              # Update system
              yum update -y
              
              # Install CloudWatch agent
              wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
              rpm -U ./amazon-cloudwatch-agent.rpm
              
              # Install SSM agent (usually pre-installed on Amazon Linux 2)
              yum install -y amazon-ssm-agent
              systemctl enable amazon-ssm-agent
              systemctl start amazon-ssm-agent
              
              # Install Docker
              yum install -y docker
              systemctl start docker
              systemctl enable docker
              usermod -a -G docker ec2-user
              
              # Install basic utilities
              yum install -y git wget curl htop
              
              # Create application directory
              mkdir -p /opt/app
              
              # Configure CloudWatch agent
              cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'EOC'
              {
                "agent": {
                  "metrics_collection_interval": 60,
                  "run_as_user": "root"
                },
                "logs": {
                  "logs_collected": {
                    "files": {
                      "collect_list": [
                        {
                          "file_path": "/var/log/messages",
                          "log_group_name": "/aws/ec2/${var.project_name}",
                          "log_stream_name": "{instance_id}/messages"
                        },
                        {
                          "file_path": "/var/log/secure",
                          "log_group_name": "/aws/ec2/${var.project_name}",
                          "log_stream_name": "{instance_id}/secure"
                        },
                        {
                          "file_path": "/opt/app/app.log",
                          "log_group_name": "/aws/ec2/${var.project_name}",
                          "log_stream_name": "{instance_id}/application"
                        }
                      ]
                    }
                  }
                },
                "metrics": {
                  "namespace": "${var.project_name}",
                  "metrics_collected": {
                    "cpu": {
                      "measurement": [
                        {
                          "name": "cpu_usage_idle",
                          "rename": "CPU_IDLE",
                          "unit": "Percent"
                        }
                      ],
                      "metrics_collection_interval": 60,
                      "totalcpu": false
                    },
                    "disk": {
                      "measurement": [
                        {
                          "name": "used_percent",
                          "rename": "DISK_USED",
                          "unit": "Percent"
                        }
                      ],
                      "metrics_collection_interval": 60,
                      "resources": [
                        "*"
                      ]
                    },
                    "mem": {
                      "measurement": [
                        {
                          "name": "mem_used_percent",
                          "rename": "MEM_USED",
                          "unit": "Percent"
                        }
                      ],
                      "metrics_collection_interval": 60
                    }
                  }
                }
              }
              EOC
              
              # Start CloudWatch agent
              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
                -a fetch-config \
                -m ec2 \
                -s \
                -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
              EOF

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "${var.project_name}-root-volume-${count.index + 1}"
    }
  }

  tags = {
    Name  = "${var.project_name}-web-${count.index + 1}"
    Role  = "web-server"
    Index = count.index + 1
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Elastic IPs for EC2 instances (optional, for static IPs)
resource "aws_eip" "web" {
  count    = var.instance_count
  instance = aws_instance.web[count.index].id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-web-eip-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}
