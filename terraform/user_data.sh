#!/bin/bash
set -e

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
yum install -y git wget curl htop python3 python3-pip nginx

# Create application directory
mkdir -p /opt/app
mkdir -p /var/log/${project_name}

# Database connection info (if RDS is enabled)
%{ if db_endpoint != "" }
echo "DB_ENDPOINT=${db_endpoint}" >> /opt/app/.env
echo "DB_NAME=${db_name}" >> /opt/app/.env
%{ endif }

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
            "log_group_name": "/aws/ec2/${project_name}",
            "log_stream_name": "{instance_id}/messages"
          },
          {
            "file_path": "/var/log/secure",
            "log_group_name": "/aws/ec2/${project_name}",
            "log_stream_name": "{instance_id}/secure"
          },
          {
            "file_path": "/opt/app/app.log",
            "log_group_name": "/aws/ec2/${project_name}",
            "log_stream_name": "{instance_id}/application"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "${project_name}",
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
        "resources": ["*"]
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

# Create sample application
cat > /opt/app/app.py <<'EOF'
#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import socket
import os

class SimpleHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {
                'status': 'healthy',
                'hostname': socket.gethostname(),
                'version': '1.0.0'
            }
            self.wfile.write(json.dumps(response).encode())
        elif self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            html = f'''
            <html>
            <head>
                <title>AWS Infrastructure Demo</title>
                <style>
                    body {{ font-family: Arial, sans-serif; margin: 50px; background: #f0f0f0; }}
                    .container {{ background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
                    h1 {{ color: #232F3E; }}
                    .info {{ margin: 20px 0; padding: 15px; background: #f8f9fa; border-left: 4px solid #FF9900; }}
                </style>
            </head>
            <body>
                <div class="container">
                    <h1>🚀 AWS Infrastructure Automation</h1>
                    <div class="info">
                        <p><strong>Server:</strong> {socket.gethostname()}</p>
                        <p><strong>Status:</strong> Running</p>
                        <p><strong>Deployment:</strong> Terraform + Ansible</p>
                        <p><strong>Features:</strong> ALB, Auto Scaling, RDS, CloudWatch</p>
                    </div>
                </div>
            </body>
            </html>
            '''
            self.wfile.write(html.encode())
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', ${app_port}), SimpleHandler)
    print(f'Server running on port ${app_port}')
    server.serve_forever()
EOF

chmod +x /opt/app/app.py

# Create systemd service
cat > /etc/systemd/system/${project_name}.service <<EOF
[Unit]
Description=${project_name} Application
After=network.target

[Service]
Type=simple
User=ec2-user
Group=ec2-user
WorkingDirectory=/opt/app
ExecStart=/usr/bin/python3 /opt/app/app.py
Restart=always
RestartSec=10
StandardOutput=append:/var/log/${project_name}/app.log
StandardError=append:/var/log/${project_name}/app.log

[Install]
WantedBy=multi-user.target
EOF

# Start application
systemctl daemon-reload
systemctl enable ${project_name}
systemctl start ${project_name}

echo "User data script completed successfully"
