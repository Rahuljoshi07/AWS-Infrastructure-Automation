# Architecture Diagram

## 🏗️ High-Level Architecture

```
                                    Internet
                                       |
                                       |
                                  [Route 53]
                                       |
                                  (Optional DNS)
                                       |
                               [ACM Certificate]
                                       |
                                  (SSL/TLS)
                                       |
                        ┌──────────────┴──────────────┐
                        │                             │
                        │   Application Load Balancer │
                        │   (Public Subnets)          │
                        │   - Health Checks           │
                        │   - SSL Termination         │
                        └──────────────┬──────────────┘
                                       |
                        ┌──────────────┴──────────────┐
                        │                             │
                   Target Group                  Target Group
                        │                             │
        ┌───────────────┴────────────┐   ┌──────────┴───────────┐
        │                            │   │                       │
   [AZ-1a]                      [AZ-1b]                    [AZ-1c]
        │                            │   │                       │
   Public Subnet               Public Subnet             Public Subnet
   10.0.1.0/24                10.0.2.0/24               10.0.3.0/24
        │                            │   │                       │
   Auto Scaling Group              │   │                       │
        │                            │   │                       │
   EC2 Instance                EC2 Instance              EC2 Instance
   (CloudWatch Agent)         (CloudWatch Agent)       (CloudWatch Agent)
        │                            │   │                       │
        └────────────┬───────────────┘   │                       │
                     │                   │                       │
                [NAT Gateway]            │                       │
                     │                   │                       │
        ┌────────────┴───────────────────┴───────────────────────┘
        │                                                         
   Private Subnet             Private Subnet            Private Subnet
   10.0.10.0/24              10.0.20.0/24              10.0.30.0/24
        │                            │                        │
        └────────────┬───────────────┴────────────────────────┘
                     │
           ┌─────────┴─────────┐
           │                   │
     [RDS Primary]      [RDS Replica]
     PostgreSQL 15      (Optional)
     Multi-AZ           Read-Only
           │
     [Secrets Manager]
     (DB Credentials)
```

## 🔒 Security Layers

```
┌─────────────────────────────────────────────────────────────┐
│                    VPC (10.0.0.0/16)                        │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │              Security Groups                          │ │
│  │  • ALB-SG: 80, 443 from Internet                     │ │
│  │  • Web-SG: 80, 443 from ALB-SG, 22 from Admin       │ │
│  │  • RDS-SG: 5432 from Web-SG only                     │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │              IAM Roles                                │ │
│  │  • EC2 Role: CloudWatch, SSM, Secrets Manager        │ │
│  │  • RDS Role: Enhanced Monitoring                     │ │
│  │  • VPC Flow Logs Role: Write to CloudWatch          │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │              Encryption                               │ │
│  │  • EBS: Encrypted at rest                            │ │
│  │  • RDS: Encrypted at rest                            │ │
│  │  • ALB: TLS 1.2+ with ACM certificates              │ │
│  │  • Secrets Manager: KMS encrypted                    │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │              Monitoring                               │ │
│  │  • VPC Flow Logs: All traffic                        │ │
│  │  • CloudWatch Logs: Application & System logs        │ │
│  │  • CloudWatch Metrics: Custom metrics & alarms       │ │
│  │  • RDS Enhanced Monitoring & Performance Insights    │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 🔄 Auto Scaling Flow

```
User Traffic Increase
        │
        ▼
CloudWatch Alarm: CPU > 70%
        │
        ▼
Auto Scaling Policy: Scale Up
        │
        ▼
Launch New EC2 Instance
        │
        ▼
CloudWatch Agent Installation
        │
        ▼
Application Deployment (User Data)
        │
        ▼
Health Check Passes
        │
        ▼
Add to ALB Target Group
        │
        ▼
Start Serving Traffic


Traffic Decrease
        │
        ▼
CloudWatch Alarm: CPU < 20%
        │
        ▼
Auto Scaling Policy: Scale Down
        │
        ▼
Drain Connections from Instance
        │
        ▼
Remove from ALB Target Group
        │
        ▼
Terminate Instance
```

## 📊 Data Flow

```
1. Client Request
        │
        ▼
2. Route 53 (Optional) → Resolves to ALB
        │
        ▼
3. Application Load Balancer
        │ (SSL Termination)
        ▼
4. Target Group Health Check
        │
        ▼
5. EC2 Instance (via Auto Scaling)
        │
        ├─→ Application Logic
        │
        ├─→ Database Query (RDS PostgreSQL)
        │   │
        │   ├─→ Primary: Read/Write
        │   └─→ Replica: Read-Only (if enabled)
        │
        ├─→ Secrets Manager (DB Credentials)
        │
        └─→ CloudWatch (Logs & Metrics)
        │
        ▼
6. Response to Client
```

## 🔐 CI/CD Pipeline Flow

```
GitHub Repository
        │
        ├─→ Pull Request
        │        │
        │        ├─→ Terraform Validate
        │        ├─→ Terraform Plan
        │        ├─→ Security Scan (Trivy)
        │        └─→ Comment on PR
        │
        └─→ Push to Main
                 │
                 ├─→ Terraform Apply
                 │        │
                 │        ├─→ Provision Infrastructure
                 │        ├─→ Generate Ansible Inventory
                 │        └─→ Upload Artifacts
                 │
                 └─→ Ansible Deploy
                          │
                          ├─→ Configure Servers
                          ├─→ Deploy Application
                          ├─→ Health Checks
                          └─→ Notify Success/Failure
```

## 🛡️ Disaster Recovery

```
Regular Operations:
- Automated RDS backups (7 days retention)
- Multi-AZ deployment for high availability
- Auto Scaling for instance failures

Disaster Scenarios:

1. Single Instance Failure
   → Auto Scaling automatically replaces
   → ALB routes traffic to healthy instances

2. Availability Zone Failure
   → Multi-AZ RDS fails over automatically
   → ASG launches instances in other AZs
   → ALB distributes to remaining AZs

3. Database Corruption
   → Restore from automated RDS backup
   → Point-in-time recovery available
   → Read replica promotion if needed

4. Complete Region Failure
   → Manual failover to another region
   → Requires multi-region setup (future enhancement)
```

## 📈 Monitoring Dashboard Layout

```
┌─────────────────────────────────────────────────────────────┐
│            CloudWatch Dashboard                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────┐  ┌──────────────────┐               │
│  │   ALB Metrics    │  │  ASG Capacity    │               │
│  │  - Requests      │  │  - Current: 2    │               │
│  │  - Latency       │  │  - Desired: 2    │               │
│  │  - 5xx Errors    │  │  - Min: 2        │               │
│  └──────────────────┘  └──────────────────┘               │
│                                                             │
│  ┌──────────────────┐  ┌──────────────────┐               │
│  │  EC2 CPU Usage   │  │  RDS Metrics     │               │
│  │  (All Instances) │  │  - CPU           │               │
│  │                  │  │  - Connections   │               │
│  │                  │  │  - Storage       │               │
│  └──────────────────┘  └──────────────────┘               │
│                                                             │
│  ┌──────────────────┐  ┌──────────────────┐               │
│  │  Memory Usage    │  │  Recent Logs     │               │
│  │  (Custom Metric) │  │  (Last 100)      │               │
│  │                  │  │                  │               │
│  └──────────────────┘  └──────────────────┘               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

**Last Updated**: January 2026  
**Version**: 2.0.0 - Production Ready with ALB, ASG, RDS, and CI/CD
