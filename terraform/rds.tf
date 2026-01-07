# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  count      = var.enable_rds ? 1 : 0
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# Security Group for RDS
resource "aws_security_group" "rds_sg" {
  count       = var.enable_rds ? 1 : 0
  name        = "${var.project_name}-rds-sg"
  description = "Security group for RDS database"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from web servers"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# RDS Parameter Group
resource "aws_db_parameter_group" "main" {
  count  = var.enable_rds ? 1 : 0
  name   = "${var.project_name}-pg"
  family = "postgres15"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  tags = {
    Name = "${var.project_name}-parameter-group"
  }
}

# RDS Option Group
resource "aws_db_option_group" "main" {
  count                = var.enable_rds ? 1 : 0
  name                 = "${var.project_name}-og"
  option_group_description = "Option group for ${var.project_name}"
  engine_name          = "postgres"
  major_engine_version = "15"

  tags = {
    Name = "${var.project_name}-option-group"
  }
}

# Random Password for RDS
resource "random_password" "db_password" {
  count   = var.enable_rds ? 1 : 0
  length  = 32
  special = true
}

# AWS Secrets Manager Secret for DB Password
resource "aws_secretsmanager_secret" "db_password" {
  count                   = var.enable_rds ? 1 : 0
  name                    = "${var.project_name}-db-password"
  recovery_window_in_days = 7

  tags = {
    Name = "${var.project_name}-db-password"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  count     = var.enable_rds ? 1 : 0
  secret_id = aws_secretsmanager_secret.db_password[0].id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password[0].result
    engine   = "postgres"
    host     = aws_db_instance.main[0].address
    port     = 5432
    dbname   = var.db_name
  })
}

# RDS Instance
resource "aws_db_instance" "main" {
  count                  = var.enable_rds ? 1 : 0
  identifier             = "${var.project_name}-db"
  engine                 = "postgres"
  engine_version         = "15.4"
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
  max_allocated_storage  = var.db_max_allocated_storage
  storage_type           = "gp3"
  storage_encrypted      = true
  
  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password[0].result
  port     = 5432

  multi_az               = var.db_multi_az
  db_subnet_group_name   = aws_db_subnet_group.main[0].name
  vpc_security_group_ids = [aws_security_group.rds_sg[0].id]
  parameter_group_name   = aws_db_parameter_group.main[0].name
  option_group_name      = aws_db_option_group.main[0].name

  backup_retention_period = var.db_backup_retention_period
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  monitoring_interval             = 60
  monitoring_role_arn            = aws_iam_role.rds_monitoring[0].arn

  auto_minor_version_upgrade = true
  deletion_protection        = var.environment == "prod" ? true : false
  skip_final_snapshot       = var.environment != "prod"
  final_snapshot_identifier = var.environment == "prod" ? "${var.project_name}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null

  performance_insights_enabled    = true
  performance_insights_retention_period = 7

  tags = {
    Name = "${var.project_name}-database"
  }
}

# IAM Role for RDS Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  count = var.enable_rds ? 1 : 0
  name  = "${var.project_name}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-rds-monitoring-role"
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count      = var.enable_rds ? 1 : 0
  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# RDS Read Replica (Optional)
resource "aws_db_instance" "replica" {
  count                  = var.enable_rds && var.enable_rds_replica ? 1 : 0
  identifier             = "${var.project_name}-db-replica"
  replicate_source_db    = aws_db_instance.main[0].identifier
  instance_class         = var.db_instance_class
  auto_minor_version_upgrade = true
  publicly_accessible    = false
  skip_final_snapshot    = true

  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn         = aws_iam_role.rds_monitoring[0].arn

  tags = {
    Name = "${var.project_name}-database-replica"
  }
}

# CloudWatch Alarms for RDS
resource "aws_cloudwatch_metric_alarm" "db_cpu" {
  count               = var.enable_rds ? 1 : 0
  alarm_name          = "${var.project_name}-db-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Database CPU utilization is too high"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main[0].id
  }
}

resource "aws_cloudwatch_metric_alarm" "db_storage" {
  count               = var.enable_rds ? 1 : 0
  alarm_name          = "${var.project_name}-db-low-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "10737418240" # 10 GB in bytes
  alarm_description   = "Database free storage space is low"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main[0].id
  }
}

resource "aws_cloudwatch_metric_alarm" "db_connections" {
  count               = var.enable_rds ? 1 : 0
  alarm_name          = "${var.project_name}-db-high-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Database connections are too high"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main[0].id
  }
}
