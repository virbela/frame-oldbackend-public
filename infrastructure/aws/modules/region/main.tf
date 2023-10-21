###
## Setup ingress and egress that point to the base region's api server
###
terraform {
  required_version = "<= 1.3.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "=4.39.0"
    }
  }
}

data "aws_region" "current_region" {}

###
## ECS Services
###
/* begin ingress task */
resource "aws_ecs_service" "ingress" {
  name                               = "ingress"
  cluster                            = var.ecs_cluster.id
  task_definition                    = aws_ecs_task_definition.ingress.arn
  desired_count                      = var.ingress_desired_count # this effects autoscaling: it must be <= aws_appautoscaling_target.min_capacity
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100
  launch_type                        = "FARGATE"
  scheduling_strategy                = "REPLICA"
  enable_execute_command             = true

  network_configuration {
    subnets          = [var.sn_public.id, var.sn_private.id] # private needed for ecr and efs
    assign_public_ip = true
    security_groups  = [aws_security_group.sg_ingress.id]
  }

  # autoscaling changes the desired_count
  # lifecycle {
  #   ignore_changes = [desired_count]
  # }

  tags = {
    Name = var.deployment_group
  }
} /* end ingress service */

/* begin egress service */
resource "aws_ecs_service" "egress" {
  name                               = "egress"
  cluster                            = var.ecs_cluster.id
  task_definition                    = aws_ecs_task_definition.egress.arn
  desired_count                      = var.egress_desired_count # this effects autoscaling: it must be <= aws_appautoscaling_target.min_capacity
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100
  launch_type                        = "FARGATE"
  scheduling_strategy                = "REPLICA"
  enable_execute_command             = true

  network_configuration {
    subnets          = [var.sn_public.id, var.sn_private.id] # private needed for ecr and efs
    assign_public_ip = true
    security_groups  = [aws_security_group.sg_egress.id]
  }

  # autoscaling changes the desired_count
  # lifecycle {
  #   ignore_changes = [desired_count]
  # }

  tags = {
    Name = var.deployment_group
  }
} /* end egress service */


/* begin primary movement service */
resource "aws_ecs_service" "movement_primary" {
  name                               = "movement-primary"
  cluster                            = var.ecs_cluster.id
  task_definition                    = aws_ecs_task_definition.movement_primary.arn
  desired_count                      = 1
  deployment_minimum_healthy_percent = 0 // have only one task running at any time
  deployment_maximum_percent         = 100
  launch_type                        = "FARGATE"
  enable_execute_command             = true

  network_configuration {
    subnets          = [var.sn_public.id] # private needed for ecr and efs
    assign_public_ip = true
    security_groups  = [aws_security_group.sg_movement_lb.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tg_movement_primary.arn
    container_name   = "movement-primary"
    container_port   = 9443
  }
  tags = {
    Name = var.deployment_group
  }
}

// Each service has a load balancer. The load balancer is configured to use the target group
resource "aws_lb_target_group" "tg_movement_primary" {
  name     = "${var.deployment_group}-tg-mvmt-pri"
  port     = 9443
  protocol = "TCP"
  vpc_id   = var.vpc.id
  deregistration_delay = 60  
  target_type = "ip"

  health_check {
    path                = "/health"
    port                = 8081
    interval            = 30
  }

  lifecycle {
    ignore_changes = [health_check]
  }
}

resource "aws_lb_listener" "movement_primary" {
  load_balancer_arn = aws_lb.movement_primary.id
  port              = "443"
  protocol          = "TLS"
  #certificate_arn = var.acm_ssl_cert.arn
  certificate_arn = aws_acm_certificate.movement_cert.arn
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_movement_primary.id
  }
}

// An elastic ip that we associate with a domain name
# resource "aws_eip" "movement_primary" {
#   vpc = true
# }

resource "aws_lb" "movement_primary" {
  name               = "${var.deployment_group}-mvmt-pri"
  internal           = false
  load_balancer_type = "network"
  subnets            = ["${var.sn_public.id}"]
  #security_groups    = [aws_security_group.sg_movement.id] # Security groups are not supported for load balancers with type 'network'
  # subnet_mapping {
  #   subnet_id     = var.sn_public.id
  #   allocation_id = aws_eip.movement_primary.id
  # }

  tags = {
    Name = var.deployment_group
  }
}

resource "aws_route53_record" "movement_primary" {
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  name    = "primary-${data.aws_region.current_region.name}.movement.${var.dns_base}"
  type    = "A"
  
  alias {
    name                   = aws_lb.movement_primary.dns_name
    zone_id                = aws_lb.movement_primary.zone_id
    evaluate_target_health = true
  }
}
/* end primary movement service */

/* begin secondary movement service */

resource "aws_ecs_service" "movement_secondary" {
  name                               = "movement-secondary"
  cluster                            = var.ecs_cluster.id
  task_definition                    = aws_ecs_task_definition.movement_secondary.arn
  desired_count                      = 1
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100
  launch_type                        = "FARGATE"
  enable_execute_command             = true

  network_configuration {
    subnets          = [var.sn_public.id]
    assign_public_ip = true
    security_groups  = [aws_security_group.sg_movement_lb.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tg_movement_secondary.arn
    container_name   = "movement-secondary"
    container_port   = 9443
  }
  tags = {
    Name = var.deployment_group
  }
}
resource "aws_lb_target_group" "tg_movement_secondary" {
  name     = "${var.deployment_group}-tg-mvmt-sec"
  port     = 9443
  protocol = "TCP"
  vpc_id   = var.vpc.id
  deregistration_delay = 60  
  target_type = "ip"

  health_check {
    path                = "/health"
    port                = 8081
    interval            = 30
  }

  lifecycle {
    ignore_changes = [health_check]
  }
}
resource "aws_lb_listener" "movement_secondary" {
  load_balancer_arn = aws_lb.movement_secondary.id
  port              = "443"
  protocol          = "TLS"
  #certificate_arn = var.acm_ssl_cert.arn
  certificate_arn = aws_acm_certificate.movement_cert.arn
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_movement_secondary.id
  }
}
// An elastic ip that we associate with a domain name
# resource "aws_eip" "movement_secondary" {
#   vpc = true
# }

resource "aws_lb" "movement_secondary" {
  name               = "${var.deployment_group}-mvmt-sec"
  internal           = false
  load_balancer_type = "network"
  subnets            = ["${var.sn_public.id}"]
  #security_groups    = [aws_security_group.sg_movement.id] # Security groups are not supported for load balancers with type 'network'
  # subnet_mapping {
  #   subnet_id     = var.sn_public.id
  #   allocation_id = aws_eip.movement_secondary.id
  # }
  tags = {
    Name = var.deployment_group
  }
}

resource "aws_route53_record" "movement_secondary" {
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  name    = "secondary-${data.aws_region.current_region.name}.movement.${var.dns_base}"
  type    = "A"
  
  alias {
    name                   = aws_lb.movement_secondary.dns_name
    zone_id                = aws_lb.movement_secondary.zone_id
    evaluate_target_health = true
  }
}
/* end secondary movement service */

###
## ECS Task Definitions
###
/* begin ingress task */
/* To view resources: ecs Clusters | <site> | Tasks | <task id> | Configuration | Containers 
| <server>: Configuration tab, Containers section */
resource "aws_ecs_task_definition" "ingress" {
  family                   = "ingress-${var.deployment_group}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 4096 # 4 CPUs are required to avoid strange behavior
  memory                   = 8192 # Fargate imposes this minimum RAM requirement for 4 CPUs
  execution_role_arn       = "arn:aws:iam::${data.aws_caller_identity.acct_caller_id.account_id}:role/${var.arn_taskexecution_name}"
  task_role_arn            = var.fargate_manage_task.arn
  skip_destroy             = true

  container_definitions = jsonencode([
    {
      name      = "ingress"
      image     = "${var.aws_account_id}.dkr.ecr.us-east-1.amazonaws.com/${var.ingress_image_path}:latest"
      cpu       = 4096
      memory    = 8192
      essential = true
      environment = [
        {
          "name" : "signalingserver",
          "value" : "api.${var.dns_base}",
        },
        {
          "name" : "region",
          "value" : "${data.aws_region.current_region.name}",
        }
      ],
      portMappings = [
        {
          containerPort = 10000,
          hostPort      = 10000,
          protocol      = "udp"
        },
        {
          containerPort = 10001,
          hostPort      = 10001,
          protocol      = "udp"
        },
        {
          containerPort = 10002,
          hostPort      = 10002,
          protocol      = "udp"
        },
        {
          containerPort = 10003,
          hostPort      = 10003,
          protocol      = "udp"
        },
        {
          containerPort = 10004,
          hostPort      = 10004,
          protocol      = "udp"
        }
      ],
      ulimits = [
        {
          name      = "nofile",
          softLimit = 1048576,
          hardLimit = 1048576
        },
        {
          name      = "nproc",
          softLimit = 1048576,
          hardLimit = 1048576
        },
      ],
      logConfiguration : {
        "logDriver" : "awslogs",
        "options" : {
          "awslogs-group" : "/ecs/${var.deployment_group}",
          "awslogs-region" : "${data.aws_region.current_region.name}",
          "awslogs-create-group" : "true",
          "awslogs-stream-prefix" : "ingress"
        }
      }
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  tags = {
    Name = var.deployment_group
  }
} /* end ingress task */

/* begin egress task */
resource "aws_ecs_task_definition" "egress" {
  family                   = "egress-${var.deployment_group}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 4096 # 4 CPUs are required to avoid strange behavior
  memory                   = 8192 # Fargate imposes this minimum RAM requirement for 4 CPUs
  execution_role_arn       = "arn:aws:iam::${data.aws_caller_identity.acct_caller_id.account_id}:role/${var.arn_taskexecution_name}"
  task_role_arn            = var.fargate_manage_task.arn
  skip_destroy             = true

  container_definitions = jsonencode([
    {
      name      = "egress"
      image     = "${var.aws_account_id}.dkr.ecr.us-east-1.amazonaws.com/${var.egress_image_path}:latest"
      cpu       = 4096
      memory    = 8192
      essential = true
      environment = [
        {
          "name" : "signalingserver",
          "value" : "api.${var.dns_base}",
        },
        {
          "name" : "region",
          "value" : "${data.aws_region.current_region.name}",
        }
      ],
      portMappings = [
        {
          containerPort = 20000,
          hostPort      = 20000,
          protocol      = "udp"
        },
        {
          containerPort = 20001,
          hostPort      = 20001,
          protocol      = "udp"
        },
        {
          containerPort = 20002,
          hostPort      = 20002,
          protocol      = "udp"
        },
        {
          containerPort = 20003,
          hostPort      = 20003,
          protocol      = "udp"
        },
        {
          containerPort = 20004,
          hostPort      = 20004,
          protocol      = "udp"
        }
      ],
      ulimits = [
        {
          name      = "nofile",
          softLimit = 1048576,
          hardLimit = 1048576
        },
        {
          name      = "nproc",
          softLimit = 1048576,
          hardLimit = 1048576
        },
      ],
      logConfiguration : {
        "logDriver" : "awslogs",
        "options" : {
          "awslogs-group" : "/ecs/${var.deployment_group}",
          "awslogs-region" : "${data.aws_region.current_region.name}",
          "awslogs-create-group" : "true",
          "awslogs-stream-prefix" : "egress"
        }
      }
    }
  ])
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  tags = {
    Name = var.deployment_group
  }
} /* end egress task */

/* begin primary movement task */
resource "aws_ecs_task_definition" "movement_primary" {
  family                   = "movement-primary-${var.deployment_group}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 4096
  memory                   = 8192
  execution_role_arn       = "arn:aws:iam::${data.aws_caller_identity.acct_caller_id.account_id}:role/${var.arn_taskexecution_name}"
  task_role_arn            = var.fargate_manage_task.arn

  container_definitions = jsonencode([
    {
      name      = "movement-primary"
      image     = "${var.aws_account_id}.dkr.ecr.us-east-1.amazonaws.com/${var.movement_image_path}:latest"
      cpu       = 4096
      memory    = 8192
      essential = true
      environment = [
        {
          "name" : "signalingserver",
          "value" : "api.${var.dns_base}",
        },
        {
          "name" : "host",
          "value" : "wss://primary-${data.aws_region.current_region.name}.movement.${var.dns_base}",
        },
        {
          "name" : "region",
          "value" : "${data.aws_region.current_region.name}",
        }
      ],
      portMappings = [
        { 
          // WebSocket port
          containerPort = 9443,
          hostPort      = 9443,
          protocol      = "tcp"
        },
        {
          // Health check port
          containerPort = 8081,
          hostPort      = 8081,
          protocol      = "tcp"
        }
      ],
      ulimits = [
        {
          name      = "nofile",
          softLimit = 1048576,
          hardLimit = 1048576
        },
        {
          name      = "nproc",
          softLimit = 1048576,
          hardLimit = 1048576
        },
      ],
      logConfiguration : {
        "logDriver" : "awslogs",
        "options" : {
          "awslogs-group" : "/ecs/${var.deployment_group}",
          "awslogs-region" : "${data.aws_region.current_region.name}",
          "awslogs-create-group" : "true",
          "awslogs-stream-prefix" : "movement-primary"
        }
      }
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  tags = {
    Name = var.deployment_group
  }
}  


/* end primary movement task */

/* begin secondary movement task */
resource "aws_ecs_task_definition" "movement_secondary" {
  family                   = "movement-secondary-${var.deployment_group}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 4096
  memory                   = 8192
  execution_role_arn       = "arn:aws:iam::${data.aws_caller_identity.acct_caller_id.account_id}:role/${var.arn_taskexecution_name}"
  task_role_arn            = var.fargate_manage_task.arn

  container_definitions = jsonencode([
    {
      name      = "movement-secondary"
      image     = "${var.aws_account_id}.dkr.ecr.us-east-1.amazonaws.com/${var.movement_image_path}:latest"
      cpu       = 4096
      memory    = 8192
      essential = true
      environment = [
        {
          "name" : "signalingserver",
          "value" : "api.${var.dns_base}",
        },
        {
          "name" : "host",
          "value" : "wss://secondary-${data.aws_region.current_region.name}.movement.${var.dns_base}",
        },
        {
          "name" : "region",
          "value" : "${data.aws_region.current_region.name}",
        }
      ],
      portMappings = [
        { 
          // WebSocket port
          containerPort = 9443,
          hostPort      = 9443,
          protocol      = "tcp"
        },
        {
          // Health check port
          containerPort = 8081,
          hostPort      = 8081,
          protocol      = "tcp"
        }
      ],
      ulimits = [
        {
          name      = "nofile",
          softLimit = 1048576,
          hardLimit = 1048576
        },
        {
          name      = "nproc",
          softLimit = 1048576,
          hardLimit = 1048576
        },
      ],
      logConfiguration : {
        "logDriver" : "awslogs",
        "options" : {
          "awslogs-group" : "/ecs/${var.deployment_group}",
          "awslogs-region" : "${data.aws_region.current_region.name}",
          "awslogs-create-group" : "true",
          "awslogs-stream-prefix" : "movement-secondary"
        }
      }
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  tags = {
    Name = var.deployment_group
  }
}
