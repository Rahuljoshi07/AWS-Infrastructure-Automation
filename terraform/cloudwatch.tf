# CloudWatch Log Group for EC2 Instances
resource "aws_cloudwatch_log_group" "ec2_logs" {
  name              = "/aws/ec2/${var.project_name}"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-ec2-logs"
  }
}

# SNS Topic for CloudWatch Alarms
resource "aws_sns_topic" "cloudwatch_alarms" {
  name = "${var.project_name}-cloudwatch-alarms"

  tags = {
    Name = "${var.project_name}-cloudwatch-alarms"
  }
}

# SNS Topic Subscription (Email)
resource "aws_sns_topic_subscription" "cloudwatch_alarms_email" {
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.cloudwatch_alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# CloudWatch Alarm - High CPU Utilization
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  count               = var.instance_count
  alarm_name          = "${var.project_name}-high-cpu-${count.index + 1}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]

  dimensions = {
    InstanceId = aws_instance.web[count.index].id
  }

  tags = {
    Name = "${var.project_name}-high-cpu-alarm-${count.index + 1}"
  }
}

# CloudWatch Alarm - Instance Status Check Failed
resource "aws_cloudwatch_metric_alarm" "instance_status_check" {
  count               = var.instance_count
  alarm_name          = "${var.project_name}-status-check-failed-${count.index + 1}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "0"
  alarm_description   = "This metric monitors instance status checks"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]

  dimensions = {
    InstanceId = aws_instance.web[count.index].id
  }

  tags = {
    Name = "${var.project_name}-status-check-alarm-${count.index + 1}"
  }
}

# CloudWatch Alarm - High Memory Utilization (custom metric)
resource "aws_cloudwatch_metric_alarm" "high_memory" {
  count               = var.instance_count
  alarm_name          = "${var.project_name}-high-memory-${count.index + 1}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MEM_USED"
  namespace           = var.project_name
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors memory utilization"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.web[count.index].id
  }

  tags = {
    Name = "${var.project_name}-high-memory-alarm-${count.index + 1}"
  }
}

# CloudWatch Alarm - High Disk Utilization
resource "aws_cloudwatch_metric_alarm" "high_disk" {
  count               = var.instance_count
  alarm_name          = "${var.project_name}-high-disk-${count.index + 1}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DISK_USED"
  namespace           = var.project_name
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "This metric monitors disk utilization"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.web[count.index].id
  }

  tags = {
    Name = "${var.project_name}-high-disk-alarm-${count.index + 1}"
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            for i in range(var.instance_count) : [
              "AWS/EC2",
              "CPUUtilization",
              {
                stat   = "Average"
                period = 300
              },
              {
                dimensions = {
                  InstanceId = aws_instance.web[i].id
                }
              }
            ]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "EC2 CPU Utilization"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            for i in range(var.instance_count) : [
              var.project_name,
              "MEM_USED",
              {
                stat   = "Average"
                period = 300
              },
              {
                dimensions = {
                  InstanceId = aws_instance.web[i].id
                }
              }
            ]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Memory Utilization"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            for i in range(var.instance_count) : [
              var.project_name,
              "DISK_USED",
              {
                stat   = "Average"
                period = 300
              },
              {
                dimensions = {
                  InstanceId = aws_instance.web[i].id
                }
              }
            ]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Disk Utilization"
        }
      },
      {
        type = "log"
        properties = {
          query   = "SOURCE '/aws/ec2/${var.project_name}' | fields @timestamp, @message | sort @timestamp desc | limit 100"
          region  = var.aws_region
          title   = "Recent EC2 Logs"
          stacked = false
        }
      }
    ]
  })
}
