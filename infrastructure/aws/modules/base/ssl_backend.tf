###
## Base SSL/EFS - Setup EFS volume to store SSL certs and renew them
###

locals {
  // sslcert task env
  // creds
  AWS_ACCESS_KEY_ID     = jsondecode(data.aws_secretsmanager_secret_version.common_creds.secret_string)["AWS_ACCESS_KEY_ID"]
  AWS_SECRET_ACCESS_KEY = jsondecode(data.aws_secretsmanager_secret_version.common_creds.secret_string)["AWS_SECRET_ACCESS_KEY"]
}

###
## Security group for allowing EFS traffic to Fargate task
###
resource "aws_security_group" "efs_security_group" {
  name        = "ecs_efs_security_group"
  description = "Setup efs mountpoint for signaling and authentication"
  vpc_id      = var.vpc.id

  ingress {
    description = "EFS mount target"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # egress settings may help avoid efs ResourceInitializationError
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


/* security group for fargate tasks to manually execute ssl renewal */
resource "aws_security_group" "sg_fargate_ssl" {
  name        = "sslcert-manual"
  description = "Initial backend sslcert deployment task security group"
  vpc_id      = var.vpc.id

  ingress {
    description      = "sslcert-manual"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    description = "sslcert-manual"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.deployment_group
  }
}


/* efs mountpoints for letsencrypt cert */
resource "aws_efs_file_system" "efs_signaling" {
  availability_zone_name = var.az_zones.names[0]
  creation_token         = "sslcert-signaling-${var.deployment_group}"

  tags = {
    Name = "ssl-signaling-${var.deployment_group}"
  }
}

resource "aws_efs_file_system" "efs_authentication" {
  availability_zone_name = var.az_zones.names[0]
  creation_token         = "sslcert-auth-${var.deployment_group}"

  tags = {
    Name = "ssl-auth-${var.deployment_group}"
  }
}

resource "aws_efs_mount_target" "mount_signaling" {
  file_system_id  = aws_efs_file_system.efs_signaling.id
  subnet_id       = var.sn_private.id
  security_groups = [aws_security_group.efs_security_group.id]
}

resource "aws_efs_mount_target" "mount_authentication" {
  file_system_id  = aws_efs_file_system.efs_authentication.id
  subnet_id       = var.sn_private.id
  security_groups = [aws_security_group.efs_security_group.id]
}

# need access point to connect to to transfer files
# https://hands-on.cloud/how-to-manage-amazon-efs-using-terraform/
# https://medium.com/@ilia.lazebnik/attaching-an-efs-file-system-to-an-ecs-task-7bd15b76a6ef
resource "aws_efs_access_point" "ssl_certificates_signaling" {
  file_system_id = aws_efs_file_system.efs_signaling.id

  posix_user {
    gid            = 1000
    uid            = 1000
    secondary_gids = [1000]
  }

  root_directory {
    path = "/etc/letsencrypt"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = 766
    }
  }

  tags = {
    Name = var.deployment_group
  }
}

resource "aws_efs_access_point" "ssl_certificates_authentication" {
  file_system_id = aws_efs_file_system.efs_authentication.id

  posix_user {
    gid            = 1000
    uid            = 1000
    secondary_gids = [1000]
  }

  root_directory {
    path = "/"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = 766
    }
  }

  tags = {
    Name = var.deployment_group
  }
}

/*------------------------------------------------------------------------------
# CLOUDWATCH EVENT ROLE
#------------------------------------------------------------------------------*/
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/scheduled_tasks.html
# https://mismo.team/deploying-event-driven-ecs-tasks-using-aws-evenbridge-and-fargate/
# https://github.com/cn-terraform/terraform-aws-ecs-fargate-scheduled-task/blob/main/main.tf
data "aws_iam_policy_document" "scheduled_task_cw_event_role_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["events.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "scheduled_task_cw_event_role_cloudwatch_policy" {
  statement {
    effect    = "Allow"
    actions   = ["ecs:RunTask"]
    resources = ["*"]
    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = [var.ecs_cluster.arn]
    }
  }
  statement {
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${data.aws_caller_identity.acct_caller_id.account_id}:role/ecsTaskExecutionRole"]
  }
}

resource "aws_iam_role" "scheduled_task_cw_event_role" {
  name               = "scheduled_task_cw_event_role_${var.deployment_group}"
  assume_role_policy = data.aws_iam_policy_document.scheduled_task_cw_event_role_assume_role_policy.json

  tags = {
    Name = var.deployment_group
  }
}

resource "aws_iam_role_policy" "scheduled_task_cw_event_role_cloudwatch_policy" {
  name   = "scheduled_task_cw_event_role_cloudwatch_policy"
  role   = aws_iam_role.scheduled_task_cw_event_role.id
  policy = data.aws_iam_policy_document.scheduled_task_cw_event_role_cloudwatch_policy.json
}


/* begin sslcert task */
/* 
   The task logs to CloudWatch
   The task itself should appear in the cluster, but you need to explicitly search for the name
   https://eff-certbot.readthedocs.io/en/stable/using.html#certbot-command-line-options
*/
resource "aws_ecs_task_definition" "sslcert" {
  family                   = "sslcert-${var.deployment_group}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 2048
  memory                   = 4096
  execution_role_arn       = "arn:aws:iam::${data.aws_caller_identity.acct_caller_id.account_id}:role/${var.arn_taskexecution_name}"
  skip_destroy             = true

  container_definitions = jsonencode([
    {
      name      = "sslcert"
      image     = "certbot/dns-route53:latest"
      cpu       = 2048
      memory    = 4096
      essential = true
      # TODO: move AWS_* to AWS secrets
      environment = [
        {
          "name" : "AWS_ACCESS_KEY_ID",
          "value" : "${local.AWS_ACCESS_KEY_ID}",
        },
        {
          "name" : "AWS_SECRET_ACCESS_KEY",
          "value" : "${local.AWS_SECRET_ACCESS_KEY}",
        },
      ],
      mountPoints = [
        {
          containerPath = "/etc/letsencrypt",
          sourceVolume  = "sslcert-signaling-${var.deployment_group}",
        },
      ],
      entryPoint = ["/bin/sh"],
      command    = ["-c", "certbot certonly -v --dns-route53 --email webmaster@framevr.io --agree-tos --eff-email --force-renew -d api.${var.dns_base} -d api.quick.${var.dns_base} && chown -R 1000:1000 /etc/letsencrypt && ln -sf /etc/letsencrypt/live/api.${var.dns_base} /etc/letsencrypt/live/framevr.io"],
      logConfiguration : {
        "logDriver" : "awslogs",
        "options" : {
          "awslogs-group" : "/ecs/${var.deployment_group}",
          "awslogs-region" : "${data.aws_region.current_region.name}",
          "awslogs-create-group" : "true",
          "awslogs-stream-prefix" : "sslcert"
        }
      }
    }
  ])

  volume {
    name = "sslcert-signaling-${var.deployment_group}" # this is the volume name for the config mountpoint
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.efs_signaling.id
    }
  }

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  tags = {
    Name = var.deployment_group
  }
} /* end sslcert task */

/*------------------------------------------------------------------------------
# CLOUDWATCH EVENT RULE
#------------------------------------------------------------------------------*/
# The schedule_expression should appear in the cluster under Scheduled Tasks
# NOTE: certbot/letsencrypt only allows 5 renewals per week and will block further requests
resource "aws_cloudwatch_event_rule" "event_rule" {
  name = "sslcert-${var.deployment_group}"
  #schedule_expression = "cron(0 0 1 * ? *)" # monthly - NOTE: need a means to kick this off manually the first time
  schedule_expression = "rate(7 days)" # for troubleshooting

  description = "SSL cert renewal"
  is_enabled  = true

  tags = {
    Name = var.deployment_group
  }
}

/*------------------------------------------------------------------------------
# CLOUDWATCH EVENT TARGET
#------------------------------------------------------------------------------*/
resource "aws_cloudwatch_event_target" "ecs_scheduled_task" {
  rule     = aws_cloudwatch_event_rule.event_rule.name
  arn      = var.ecs_cluster.arn
  role_arn = aws_iam_role.scheduled_task_cw_event_role.arn

  ecs_target {
    group               = var.deployment_group
    launch_type         = "FARGATE"
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.sslcert.arn

    network_configuration {
      subnets          = [var.sn_private.id]
      security_groups  = [aws_security_group.sg_fargate_ssl.id]
      assign_public_ip = true
    }
  }
}