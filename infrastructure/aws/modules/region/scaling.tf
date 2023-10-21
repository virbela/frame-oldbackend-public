////////////////////////////////////
/* Autoscaling                    */
////////////////////////////////////

/* Egress */
/* Console: Cluster | <cluster> | <server> | Service | Configuration and tasks*/
resource "aws_appautoscaling_target" "ecs_target_egress" {
  service_namespace  = "ecs"
  resource_id        = "service/${var.ecs_cluster.name}/${aws_ecs_service.egress.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.autoscale_egress_min_count # can be < aws_ecs_service.desired_count (in Console), but would still return to higher aws_ecs_service.desired_count
  max_capacity       = var.autoscale_egress_max_count # maximum number of tasks to scale up
}

########### cpu util scaling
resource "aws_appautoscaling_policy" "ecs_policy_cpu_egress_scaleup" {
  name = "${var.deployment_group}-egress-cpu-scaleup"

  policy_type = "StepScaling"

  service_namespace  = aws_appautoscaling_target.ecs_target_egress.service_namespace
  resource_id        = aws_appautoscaling_target.ecs_target_egress.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target_egress.scalable_dimension

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 2 # number of members to scale when the adjustment bounds are breached: positive scales up, negative down.
    }
  }
}

resource "aws_appautoscaling_policy" "ecs_policy_cpu_egress_scaledown" {
  name = "${var.deployment_group}-egress-cpu-scaledown"

  policy_type = "StepScaling"

  service_namespace  = aws_appautoscaling_target.ecs_target_egress.service_namespace
  resource_id        = aws_appautoscaling_target.ecs_target_egress.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target_egress.scalable_dimension

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 150 # seconds after scaling activity completes before another one
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1 # number of members to scale when the adjustment bounds are breached: positive scales up, negative down.
    }
  }
}

########### cpu util alarms
resource "aws_cloudwatch_metric_alarm" "ecs_alarm_cpu_high_egress" {
  alarm_name = "${var.deployment_group}-egress-high-cpu"

  namespace   = "AWS/ECS"
  metric_name = "CPUUtilization" # case-sensitive

  comparison_operator = "GreaterThanOrEqualToThreshold"
  statistic           = "Average"
  period              = 300 # interval in seconds
  evaluation_periods  = 3   # number of datapoints in $period minutes
  threshold           = 80  # % utilized

  dimensions = {
    ClusterName = var.ecs_cluster.name
    ServiceName = aws_ecs_service.egress.name
  }

  alarm_actions = [aws_appautoscaling_policy.ecs_policy_cpu_egress_scaleup.arn]

  tags = {
    Name = var.deployment_group
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_alarm_cpu_low_egress" {
  alarm_name = "${var.deployment_group}-egress-low-cpu"

  namespace   = "AWS/ECS"
  metric_name = "CPUUtilization" # case-sensitive

  comparison_operator = "LessThanOrEqualToThreshold"
  statistic           = "Average"
  period              = 300 # interval in seconds
  evaluation_periods  = 3   # # number of datapoints in $period minutes
  threshold           = 0   # % utilized

  dimensions = {
    ClusterName = var.ecs_cluster.name
    ServiceName = aws_ecs_service.egress.name
  }

  alarm_actions = [aws_appautoscaling_policy.ecs_policy_cpu_egress_scaledown.arn]

  tags = {
    Name = var.deployment_group
  }
}

//////////////////////
//// in progress: step scaling
/// https://github.com/oowlish/terraform-aws-ecs-fargate-service
////////////////////
/* Ingress */
resource "aws_appautoscaling_target" "ecs_target_ingress" {
  service_namespace  = "ecs"
  resource_id        = "service/${var.ecs_cluster.name}/${aws_ecs_service.ingress.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.autoscale_ingress_min_count # can be < aws_ecs_service.desired_count (in Console), but would still return to higher aws_ecs_service.desired_count
  max_capacity       = var.autoscale_ingress_max_count # maximum number of tasks to scale up
}

########### cpu util scaling
resource "aws_appautoscaling_policy" "ecs_policy_cpu_ingress_scaleup" {
  name = "${var.deployment_group}-ingress-cpu-scaleup"

  policy_type = "StepScaling"

  service_namespace  = aws_appautoscaling_target.ecs_target_ingress.service_namespace
  resource_id        = aws_appautoscaling_target.ecs_target_ingress.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target_ingress.scalable_dimension

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 2 # number of members to scale when the adjustment bounds are breached: positive scales up, negative down.
    }
  }
}

resource "aws_appautoscaling_policy" "ecs_policy_cpu_ingress_scaledown" {
  name = "${var.deployment_group}-ingress-cpu-scaledown"

  policy_type = "StepScaling"

  service_namespace  = aws_appautoscaling_target.ecs_target_ingress.service_namespace
  resource_id        = aws_appautoscaling_target.ecs_target_ingress.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target_ingress.scalable_dimension

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 150 # seconds after scaling activity completes before another one
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1 # number of members to scale when the adjustment bounds are breached: positive scales up, negative down.
    }
  }
}

########### cpu util alarms
resource "aws_cloudwatch_metric_alarm" "ecs_alarm_cpu_high_ingress" {
  alarm_name = "${var.deployment_group}-ingress-high-cpu"

  namespace   = "AWS/ECS"
  metric_name = "CPUUtilization" # case-sensitive

  comparison_operator = "GreaterThanOrEqualToThreshold"
  statistic           = "Average"
  period              = 300 # interval in seconds
  evaluation_periods  = 3   # number of datapoints in $period minutes
  threshold           = 80  # % utilized

  dimensions = {
    ClusterName = var.ecs_cluster.name
    ServiceName = aws_ecs_service.ingress.name
  }

  alarm_actions = [aws_appautoscaling_policy.ecs_policy_cpu_ingress_scaleup.arn]

  tags = {
    Name = var.deployment_group
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_alarm_cpu_low_ingress" {
  alarm_name = "${var.deployment_group}-ingress-low-cpu"

  namespace   = "AWS/ECS"
  metric_name = "CPUUtilization" # case-sensitive

  comparison_operator = "LessThanOrEqualToThreshold"
  statistic           = "Average"
  period              = 300 # interval in seconds
  evaluation_periods  = 3   # # number of datapoints in $period minutes
  threshold           = 0   # % utilized

  dimensions = {
    ClusterName = var.ecs_cluster.name
    ServiceName = aws_ecs_service.ingress.name
  }

  alarm_actions = [aws_appautoscaling_policy.ecs_policy_cpu_ingress_scaledown.arn]

  tags = {
    Name = var.deployment_group
  }
}
