###
## CloudWatch Alerts
##
## Manual alert example:
##    https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CreateMetricFilterProcedure.html
## Pattern matching:
##    https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/FilterAndPatternSyntax.html
##    (when in doubt, enclose pattern in an escaped string)
## Validating:
##    CloudWatch | Logs, log groups
##       Find the group, click the Filters link
##       Find the filter group: check the box in its upper right corner, Edit button
###

locals {
  warningMsg = "?\"WARNING\" ?\"Delivery error Error: getaddrinfo\""
}

###
## SNS Topic
###
resource "aws_sns_topic" "sns_topic" {
  name = "${var.deployment_group}-critical"

  tags = {
    Name = var.deployment_group
  }
}

###
## SNS e-mail subscription to topic
##
## NOTE:
##    Orphaned subscription confirmations are expected if a topic is removed
##       https://docs.aws.amazon.com/sns/latest/dg/sns-delete-subscription-topic.html
##       https://www.repost.aws/questions/QUB7bWjl97QfGCuddnrZ4Rpw/sns-orphans-subscription-cannot-be-deleted-because-sns-topic-no-longer-exist
##       https://github.com/hashicorp/terraform/issues/17296
##
###
resource "aws_sns_topic_subscription" "sns_topic_subscription" {
  for_each  = toset(var.sns_email_list)
  topic_arn = aws_sns_topic.sns_topic.arn
  protocol  = "email"
  endpoint  = each.value

  # (tags not supported here)
}

#####################
## Log Alarm
##
## Alarm for log metric action trigger
## These details appear in the SNS message
###

#####################
## Critical Errors Alarms
###
resource "aws_cloudwatch_metric_alarm" "alarm_failures" {
  alarm_name        = "${var.deployment_group}-failure-alarm"
  alarm_description = "SIGTERM found in ${var.deployment_group} logs"

  namespace           = "Failures-${var.deployment_group}" # separates the alarm for its deployment group
  metric_name         = "ContainerFailures"                # a sort of category
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = "1"
  treat_missing_data  = "notBreaching"
  statistic           = "Maximum"
  evaluation_periods  = "1"
  period              = "300" # seconds
  actions_enabled     = var.enableAlerts
  alarm_actions       = [aws_sns_topic.sns_topic.arn]

  tags = {
    Name = var.deployment_group
  }
}

# calling out critical errors individually to ID them quicker
resource "aws_cloudwatch_metric_alarm" "alarm_failures_mem" {
  alarm_name        = "${var.deployment_group}-failure-mem-alarm"
  alarm_description = "Killed found in ${var.deployment_group} logs"

  namespace           = "Failures-${var.deployment_group}" # separates the alarm for its deployment group
  metric_name         = "ContainerFailuresMem"             # a sort of category
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = "1"
  treat_missing_data  = "notBreaching"
  statistic           = "Maximum"
  evaluation_periods  = "1"
  period              = "300" # seconds
  actions_enabled     = var.enableAlerts
  alarm_actions       = [aws_sns_topic.sns_topic.arn]

  tags = {
    Name = var.deployment_group
  }
}

resource "aws_cloudwatch_metric_alarm" "alarm_failures_ipc" {
  alarm_name        = "${var.deployment_group}-failure-ipc-alarm"
  alarm_description = "Killed found in ${var.deployment_group} logs"

  namespace           = "Failures-${var.deployment_group}" # separates the alarm for its deployment group
  metric_name         = "ContainerFailuresIPC"             # a sort of category
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = "1"
  treat_missing_data  = "notBreaching"
  statistic           = "Maximum"
  evaluation_periods  = "1"
  period              = "300" # seconds
  actions_enabled     = var.enableAlerts
  alarm_actions       = [aws_sns_topic.sns_topic.arn]

  tags = {
    Name = var.deployment_group
  }
}

#####################
##
## Error: failed to create ingress
## Description: Ingress failure blocks connectivity (grey button)
###
resource "aws_cloudwatch_metric_alarm" "alarm_failures_ingcreate" {
  alarm_name        = "${var.deployment_group}-failure-ingcreate-alarm"
  alarm_description = "failed to create ingress found in ${var.deployment_group} logs"

  namespace           = "Failures-${var.deployment_group}" # separates the alarm for its deployment group
  metric_name         = "ConnectionFailuresMediaserver"    # a sort of category
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = "1"
  treat_missing_data  = "notBreaching"
  statistic           = "Maximum"
  evaluation_periods  = "1"
  period              = "300" # seconds
  actions_enabled     = var.enableAlerts
  alarm_actions       = [aws_sns_topic.sns_topic.arn]

  tags = {
    Name = var.deployment_group
  }
}

#####################
## Warnings Alarms
###
resource "aws_cloudwatch_metric_alarm" "alarm_warning" {
  alarm_name        = "${var.deployment_group}-warning-alarm"
  alarm_description = "${local.warningMsg} found in ${var.deployment_group} logs"

  namespace           = "Warnings-${var.deployment_group}" # separates the alarm for its deployment group
  metric_name         = "ContainerWarnings"                # a sort of category
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = "1"
  treat_missing_data  = "notBreaching"
  statistic           = "Maximum"
  evaluation_periods  = "1"
  period              = "300" # seconds
  actions_enabled     = false # disabling emails for warnings

  tags = {
    Name = var.deployment_group
  }
}

#####################
## Log Metric
##
## filter for container log
###

#####################
## Critical Errors Metric
###
resource "aws_cloudwatch_log_metric_filter" "cloudwatch_metric_failures" {
  name           = "${var.deployment_group}-metric-failure"
  log_group_name = var.logGroup.name

  pattern = "SIGTERM" # case-sensitive

  metric_transformation {
    name          = aws_cloudwatch_metric_alarm.alarm_failures.metric_name # must match the alarm value
    namespace     = aws_cloudwatch_metric_alarm.alarm_failures.namespace   # must match the alarm value
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }

  # (tags not supported here)
}

resource "aws_cloudwatch_log_metric_filter" "cloudwatch_metric_mem_failures" {
  name           = "${var.deployment_group}-metric-mem-failure"
  log_group_name = var.logGroup.name

  pattern = "Killed" # case-sensitive

  metric_transformation {
    name          = aws_cloudwatch_metric_alarm.alarm_failures_mem.metric_name # must match the alarm value
    namespace     = aws_cloudwatch_metric_alarm.alarm_failures_mem.namespace   # must match the alarm value
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }

  # (tags not supported here)
}

resource "aws_cloudwatch_log_metric_filter" "cloudwatch_metric_ipc_failures" {
  name           = "${var.deployment_group}-metric-ipc-failure"
  log_group_name = var.logGroup.name

  pattern = "ERR_IPC_CHANNEL_CLOSED" # case-sensitive

  metric_transformation {
    name          = aws_cloudwatch_metric_alarm.alarm_failures_ipc.metric_name # must match the alarm value
    namespace     = aws_cloudwatch_metric_alarm.alarm_failures_ipc.namespace   # must match the alarm value
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }

  # (tags not supported here)
}

#####################
## 
## Error: failed to create ingress
## Description: Ingress failure blocks connectivity (grey button)
###
resource "aws_cloudwatch_log_metric_filter" "cloudwatch_metric_ingcreate_failures" {
  name           = "${var.deployment_group}-metric-ingcreate-failure"
  log_group_name = var.logGroup.name

  pattern = "failed to create ingress" # case-sensitive

  metric_transformation {
    name          = aws_cloudwatch_metric_alarm.alarm_failures_ingcreate.metric_name # must match the alarm value
    namespace     = aws_cloudwatch_metric_alarm.alarm_failures_ingcreate.namespace   # must match the alarm value
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }

  # (tags not supported here)
}

#####################
## Warnings Metric
###
resource "aws_cloudwatch_log_metric_filter" "cloudwatch_metric_warning" {
  name           = "${var.deployment_group}-metric-warnings"
  log_group_name = var.logGroup.name

  pattern = local.warningMsg # case-sensitive

  metric_transformation {
    name          = aws_cloudwatch_metric_alarm.alarm_warning.metric_name # must match the alarm value
    namespace     = aws_cloudwatch_metric_alarm.alarm_warning.namespace   # must match the alarm value
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }

  # (tags not supported here)
}
