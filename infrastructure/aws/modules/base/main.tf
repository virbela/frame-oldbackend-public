###
## Setup base region with api and authentication
###

terraform {
  #required_version = "<= 1.3.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "=4.39.0"
    }
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "1.8.1"
    }
  }
}

data "aws_region" "current_region" {}

###
##  aws secrets data
###
data "aws_secretsmanager_secret_version" "auth_creds" {
  secret_id = "terraform/${var.deployment_group}/auth"
}

data "aws_secretsmanager_secret_version" "signaling_creds" {
  secret_id = "terraform/${var.deployment_group}/signaling"
}


###
## Create S3 Bucket for branding content
###
module "branding_s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "branding.${var.dns_base}" # public bucket could already be claimed
  #acl    = "private"
  block_public_acls = true

  force_destroy = true

  tags = {
    Name = var.deployment_group
  }
}

###
##  task environment variables
##
##  NOTE: pem entries in aws secrets need to be stored as base64 encoded *without* hard-coded \n
##
###
locals {
  // auth task env
  // creds
  smtpUser          = jsondecode(data.aws_secretsmanager_secret_version.auth_creds.secret_string)["smtpUser"]
  domain            = jsondecode(data.aws_secretsmanager_secret_version.auth_creds.secret_string)["domain"]
  easySecret        = jsondecode(data.aws_secretsmanager_secret_version.auth_creds.secret_string)["easySecret"]
  hub               = jsondecode(data.aws_secretsmanager_secret_version.auth_creds.secret_string)["hub"]
  loginRedirect     = jsondecode(data.aws_secretsmanager_secret_version.auth_creds.secret_string)["loginRedirect"]
  sessionSecret     = jsondecode(data.aws_secretsmanager_secret_version.auth_creds.secret_string)["sessionSecret"]
  smtpClient        = jsondecode(data.aws_secretsmanager_secret_version.auth_creds.secret_string)["smtpClient"]
  smtpHost          = jsondecode(data.aws_secretsmanager_secret_version.auth_creds.secret_string)["smtpHost"]
  smtpKey           = jsondecode(data.aws_secretsmanager_secret_version.auth_creds.secret_string)["smtpKey"]
  smtpPort          = jsondecode(data.aws_secretsmanager_secret_version.auth_creds.secret_string)["smtpPort"]
  name              = jsondecode(data.aws_secretsmanager_secret_version.auth_creds.secret_string)["name"]
  systemUserName    = jsondecode(data.aws_secretsmanager_secret_version.auth_creds.secret_string)["systemUserName"]
  systemDisplayName = jsondecode(data.aws_secretsmanager_secret_version.auth_creds.secret_string)["systemDisplayName"]

  // mongodb
  authPass = random_password.dbuser_pass.result # mongodb user password
  # insert the creds (mongodb+srv://host... -> mongodb+srv://<user>:<password>@host...)
  connection_string = replace(local.csbase, "/([\\w+]*).{3}(.*)/", "$1://${random_string.dbuser.id}:${local.authPass}@$2")

  // signaling task env
  // creds
  IMMERS_SERVER                      = jsondecode(data.aws_secretsmanager_secret_version.signaling_creds.secret_string)["IMMERS_SERVER"]
  IMMERS_ADMIN_KEY                   = jsondecode(data.aws_secretsmanager_secret_version.signaling_creds.secret_string)["IMMERS_ADMIN_KEY"]
  AZURE_SUBSCRIBERKEY                = jsondecode(data.aws_secretsmanager_secret_version.signaling_creds.secret_string)["AZURE_SUBSCRIBERKEY"]
  TWILIO_ACCOUNTSID                  = jsondecode(data.aws_secretsmanager_secret_version.signaling_creds.secret_string)["TWILIO_ACCOUNTSID"]
  TWILIO_AUTHTOKEN                   = jsondecode(data.aws_secretsmanager_secret_version.signaling_creds.secret_string)["TWILIO_AUTHTOKEN"]
  TWILIO_TIMETOLIVEINSECONDS         = jsondecode(data.aws_secretsmanager_secret_version.signaling_creds.secret_string)["TWILIO_TIMETOLIVEINSECONDS"]
  TWILIO_REFRESHINSECONDS            = jsondecode(data.aws_secretsmanager_secret_version.signaling_creds.secret_string)["TWILIO_REFRESHINSECONDS"]
  SLACK_SECRET                       = jsondecode(data.aws_secretsmanager_secret_version.signaling_creds.secret_string)["SLACK_SECRET"]
  SLACK_CLIENT_ID                    = jsondecode(data.aws_secretsmanager_secret_version.signaling_creds.secret_string)["SLACK_CLIENT_ID"]
  SENDGRID_KEY                       = jsondecode(data.aws_secretsmanager_secret_version.signaling_creds.secret_string)["SENDGRID_KEY"]
  SENDGRID_FROM                      = jsondecode(data.aws_secretsmanager_secret_version.signaling_creds.secret_string)["SENDGRID_FROM"]
  CLOUDINARY_CLOUD_NAME              = jsondecode(data.aws_secretsmanager_secret_version.signaling_creds.secret_string)["CLOUDINARY_CLOUD_NAME"]
  CLOUDINARY_API_KEY                 = jsondecode(data.aws_secretsmanager_secret_version.signaling_creds.secret_string)["CLOUDINARY_API_KEY"]
  CLOUDINARY_API_SECRET              = jsondecode(data.aws_secretsmanager_secret_version.signaling_creds.secret_string)["CLOUDINARY_API_SECRET"]
  CLOUDINARY_VIDEO_UPLOAD_PRESET     = jsondecode(data.aws_secretsmanager_secret_version.signaling_creds.secret_string)["CLOUDINARY_VIDEO_UPLOAD_PRESET"]
  GOOGLECLOUDSTORAGE_BUCKET_NAME     = jsondecode(data.aws_secretsmanager_secret_version.signaling_creds.secret_string)["GOOGLECLOUDSTORAGE_BUCKET_NAME"]
  GOOGLECLOUDSTORAGE_PROJECTID       = jsondecode(data.aws_secretsmanager_secret_version.signaling_creds.secret_string)["GOOGLECLOUDSTORAGE_PROJECTID"]
  GOOGLECLOUDSTORAGE_CREDENTIALS_KEY = jsondecode(data.aws_secretsmanager_secret_version.signaling_creds.secret_string)["GOOGLECLOUDSTORAGE_CREDENTIALS_KEY"]
  GOOGLECLOUDSTORAGE_CLIENT_EMAIL    = jsondecode(data.aws_secretsmanager_secret_version.signaling_creds.secret_string)["GOOGLECLOUDSTORAGE_CLIENT_EMAIL"]
  FIREBASE_DATABASEURL               = jsondecode(data.aws_secretsmanager_secret_version.signaling_creds.secret_string)["FIREBASE_DATABASEURL"]
  HYPERBEAM                          = jsondecode(data.aws_secretsmanager_secret_version.signaling_creds.secret_string)["HYPERBEAM"]
  ROOT_ADMIN_EMAIL                   = jsondecode(data.aws_secretsmanager_secret_version.signaling_creds.secret_string)["ROOT_ADMIN_EMAIL"]
  OPENAI_API_KEY                     = jsondecode(data.aws_secretsmanager_secret_version.signaling_creds.secret_string)["OPENAI_API_KEY"]
  AI_CHAT_MODEL_NAME                 = jsondecode(data.aws_secretsmanager_secret_version.signaling_creds.secret_string)["AI_CHAT_MODEL_NAME"]
  AI_SUMMARY_MODEL_NAME              = jsondecode(data.aws_secretsmanager_secret_version.signaling_creds.secret_string)["AI_SUMMARY_MODEL_NAME"]
  EXP_CLIENT_ID                      = jsondecode(data.aws_secretsmanager_secret_version.signaling_creds.secret_string)["EXP_CLIENT_ID"]
  EXP_CLIENT_SECRET                  = jsondecode(data.aws_secretsmanager_secret_version.signaling_creds.secret_string)["EXP_CLIENT_SECRET"]
}

###
##  IAM Roles
###
# Allows shell access via CloudShell: aws ecs execute-command
resource "aws_iam_role" "fargate_manage_task" {
  name = "${var.deployment_group}-fargate-manage-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}


////////////////////////////////////
/* Services                       */
////////////////////////////////////

/* begin signaling service */
resource "aws_ecs_service" "signaling" {
  name                               = "signaling"
  cluster                            = var.ecs_cluster.id
  task_definition                    = aws_ecs_task_definition.signaling.arn
  desired_count                      = 1
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100
  launch_type                        = "FARGATE"
  platform_version                   = "1.4.0" # may help avoid efs ResourceInitializationError
  scheduling_strategy                = "REPLICA"
  enable_execute_command             = true
  health_check_grace_period_seconds  = 0 # seconds to ignore failed load balancer health checks

  network_configuration {
    subnets          = [var.sn_private.id] # private needed for ecr and efs
    assign_public_ip = true
    security_groups  = [aws_security_group.sg_signaling.id, aws_security_group.efs_security_group.id] # otherwise defaults to the VPC security group
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.alb_tg_alt_https.arn
    container_name   = "signaling"
    container_port   = 8443
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.alb_tg_netsocket.arn
    container_name   = "signaling"
    container_port   = 1188
  }

  # ignore task_definition which changes on every deployment
  # lifecycle {
  #   ignore_changes = [task_definition]
  # }

  tags = {
    Name = var.deployment_group
  }
} /* end signaling service */

/* begin authentication service */
resource "aws_ecs_service" "authentication" {
  name                               = "authentication"
  cluster                            = var.ecs_cluster.id
  task_definition                    = aws_ecs_task_definition.authentication.arn
  desired_count                      = 1
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100
  launch_type                        = "FARGATE"
  platform_version                   = "1.4.0" # may help avoid efs ResourceInitializationError
  scheduling_strategy                = "REPLICA"
  enable_execute_command             = true
  health_check_grace_period_seconds  = 0 # seconds to ignore failed load balancer health checks

  network_configuration {
    subnets          = [var.sn_private.id] # private needed for ecr and efs
    assign_public_ip = true
    security_groups  = [aws_security_group.sg_authentication.id, aws_security_group.efs_security_group.id]
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.auth_alb_tg_https.arn
    container_name   = "authentication"
    container_port   = 443
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.auth_alb_tg_http.arn
    container_name   = "authentication"
    container_port   = 80
  }

  # ignore task_definition which changes on every deployment
  # lifecycle {
  #   ignore_changes = [task_definition]
  # }

  tags = {
    Name = var.deployment_group
  }
} /* end authentication service */

###
## ECS Task definitions
###
/* begin signaling task */
resource "aws_ecs_task_definition" "signaling" {
  family                   = "signaling-${var.deployment_group}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 4096
  memory                   = 8192
  execution_role_arn       = "arn:aws:iam::${data.aws_caller_identity.acct_caller_id.account_id}:role/${var.arn_taskexecution_name}"
  task_role_arn            = aws_iam_role.fargate_manage_task.arn
  skip_destroy             = true

  ### Using heredoc format instead of jsonencode because jsonencode causes
  ###    issues with pem file values where new lines are double escaped (\\n)
  container_definitions = <<TASK_DEFINITION
[
  {
    "name": "signaling",
    "image": "${data.aws_caller_identity.acct_caller_id.account_id}.dkr.ecr.us-east-1.amazonaws.com/${var.signaling_image_path}:latest",
    "cpu": 2048,
    "memory": 4096,
    "essential": true,
    "environment": [
      {
        "name": "IMMERS_SERVER",
        "value": "${local.IMMERS_SERVER}"
      },
      {
        "name": "IMMERS_ADMIN_KEY",
        "value": "${local.IMMERS_ADMIN_KEY}"
      },
      {
        "name": "AZURE_SUBSCRIBERKEY",
        "value": "${local.AZURE_SUBSCRIBERKEY}"
      },
      {
        "name": "TWILIO_ACCOUNTSID",
        "value": "${local.TWILIO_ACCOUNTSID}"
      },
      {
        "name": "TWILIO_AUTHTOKEN",
        "value": "${local.TWILIO_AUTHTOKEN}"
      },
      {
        "name": "TWILIO_TIMETOLIVEINSECONDS",
        "value": "${local.TWILIO_TIMETOLIVEINSECONDS}"
      },
      {
        "name": "TWILIO_REFRESHINSECONDS",
        "value": "${local.TWILIO_REFRESHINSECONDS}"
      },
      {
        "name": "SLACK_SECRET",
        "value": "${local.SLACK_SECRET}"
      },
      {
        "name": "SLACK_CLIENT_ID",
        "value": "${local.SLACK_CLIENT_ID}"
      },
      {
        "name": "SENDGRID_KEY",
        "value": "${local.SENDGRID_KEY}"
      },
      {
        "name": "SENDGRID_FROM",
        "value": "${local.SENDGRID_FROM}"
      },
      {
        "name": "CLOUDINARY_CLOUD_NAME",
        "value": "${local.CLOUDINARY_CLOUD_NAME}"
      },
      {
        "name": "CLOUDINARY_API_KEY",
        "value": "${local.CLOUDINARY_API_KEY}"
      },
      {
        "name": "CLOUDINARY_API_SECRET",
        "value": "${local.CLOUDINARY_API_SECRET}"
      },
      {
        "name": "CLOUDINARY_VIDEO_UPLOAD_PRESET",
        "value": "${local.CLOUDINARY_VIDEO_UPLOAD_PRESET}"
      },
      {
        "name": "GOOGLECLOUDSTORAGE_BUCKET_NAME",
        "value": "${local.GOOGLECLOUDSTORAGE_BUCKET_NAME}"
      },
      {
        "name": "GOOGLECLOUDSTORAGE_PROJECTID",
        "value": "${local.GOOGLECLOUDSTORAGE_PROJECTID}"
      },
      {
        "name": "GOOGLECLOUDSTORAGE_CREDENTIALS_KEY",
        "value": "${local.GOOGLECLOUDSTORAGE_CREDENTIALS_KEY}"
      },
      {
        "name": "GOOGLECLOUDSTORAGE_CLIENT_EMAIL",
        "value": "${local.GOOGLECLOUDSTORAGE_CLIENT_EMAIL}"
      },
      {
        "name": "FIREBASE_DATABASEURL",
        "value": "${local.FIREBASE_DATABASEURL}"
      },
      {
        "name": "HYPERBEAM",
        "value": "${local.HYPERBEAM}"
      },
      {
        "name": "ROOT_ADMIN_EMAIL",
        "value": "${local.ROOT_ADMIN_EMAIL}"
      },
      {
        "name": "OPENAI_API_KEY",
        "value": "${local.OPENAI_API_KEY}"
      },
      {
        "name": "AI_CHAT_MODEL_NAME",
        "value": "${local.AI_CHAT_MODEL_NAME}"
      },
            {
        "name": "AI_SUMMARY_MODEL_NAME",
        "value": "${local.AI_SUMMARY_MODEL_NAME}"
      },
      {
        "name": "EXP_CLIENT_ID",
        "value": "${local.EXP_CLIENT_ID}"
      },
            {
        "name": "EXP_CLIENT_SECRET",
        "value": "${local.EXP_CLIENT_SECRET}"
      }
    ],
    "mountPoints": [
      {
        "containerPath": "/etc/letsencrypt",
        "sourceVolume": "sslcert-signaling-${var.deployment_group}",
        "readOnly": false
      }
    ],
    "portMappings": [
      {
        "protocol": "tcp",
        "containerPort": 8443,
        "hostPort": 8443
      },
      {
        "protocol": "tcp",
        "containerPort": 1188,
        "hostPort": 1188
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/${var.deployment_group}",
        "awslogs-region": "${data.aws_region.current_region.name}",
        "awslogs-create-group": "true",
        "awslogs-stream-prefix": "signaling"
      }
    }
  }
]
TASK_DEFINITION

  volume {
    name = "sslcert-signaling-${var.deployment_group}"
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
} /* end signaling task */

/* begin authentication task */
resource "aws_ecs_task_definition" "authentication" {
  family                   = "authentication-${var.deployment_group}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 2048
  memory                   = 4096
  execution_role_arn       = "arn:aws:iam::${data.aws_caller_identity.acct_caller_id.account_id}:role/${var.arn_taskexecution_name}"
  task_role_arn            = aws_iam_role.fargate_manage_task.arn
  skip_destroy             = true

  ### Using heredoc format instead of jsonencode because jsonencode causes
  ###    issues with pem file values where new lines are double escaped (\\n)
  container_definitions = <<TASK_DEFINITION
[
  {
    "name": "authentication",
    "image": "${data.aws_caller_identity.acct_caller_id.account_id}.dkr.ecr.us-east-1.amazonaws.com/${var.authentication_image_path}:latest",
    "cpu": 2048,
    "memory": 4096,
    "essential": true,
    "environment": [
        {
          "name" : "dbString",
          "value" : "${local.connection_string}/immers-${var.immers_db}?retryWrites=true&w=majority"
        },
        {
          "name" : "domain",
          "value" : "${local.domain}"
        },
        {
          "name" : "easySecret",
          "value" : "${local.easySecret}"
        },
        {
          "name" : "hub",
          "value" : "${local.hub}"
        },
        {
          "name" : "loginRedirect",
          "value" : "${local.loginRedirect}"
        },
        {
          "name" : "sessionSecret",
          "value" : "${local.sessionSecret}"
        },
        {
          "name" : "smtpClient",
          "value" : "${local.smtpClient}"
        },
        {
          "name" : "smtpHost",
          "value" : "${local.smtpHost}"
        },
        {
          "name" : "smtpKey",
          "value" : "${local.smtpKey}"
        },
        {
          "name" : "smtpPort",
          "value" : "${local.smtpPort}"
        },
        {
          "name" : "smtpUser",
          "value" : "${local.smtpUser}"
        },
        {
          "name" : "name",
          "value" : "${local.name}"
        },
        {
          "name" : "systemUserName",
          "value" : "${local.systemUserName}"
        },
        {
          "name" : "systemDisplayName",
          "value" : "${local.systemDisplayName}"
        }
      ],
      "mountPoints": [
        {
          "containerPath": "/root/.small-tech.org/auto-encrypt",
          "sourceVolume": "sslcert-authentication-${var.deployment_group}",
          "readOnly": false
        }
    ],
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 80
      },
      {
        "containerPort": 443,
        "hostPort": 443
      }
    ],
    "logConfiguration" : {
      "logDriver" : "awslogs",
      "options" : {
        "awslogs-group" : "/ecs/${var.deployment_group}",
        "awslogs-region" : "${data.aws_region.current_region.name}",
        "awslogs-create-group" : "true",
        "awslogs-stream-prefix" : "authentication"
      }
    }
  }
]
TASK_DEFINITION

  volume {
    name = "sslcert-authentication-${var.deployment_group}"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.efs_authentication.id
    }
  }

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  tags = {
    Name = var.deployment_group
  }
} /* end authentication task */
