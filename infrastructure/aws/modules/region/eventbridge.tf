###
## EventBridge
##
## Detect container "stopped task" (exit code 1)
## Notify through SNS email
##
## EventBridge doesn't cross regions
##   It requires the SNS Topic and EventBridge Rule
##   to both be in the same (each) region
##   https://repost.aws/knowledge-center/sns-not-getting-eventbridge-notification
##
## https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs_cwet2.html
## https://catalog.workshops.aws/iac-and-tdir/en-US/08-create-an-event-bridge-module#:~:text=Once%20you%20have%20the%20resources,and%20add%20the%20EventBridge%20rule.&text=To%20finish%20the%20task%2C%20initialize,new%20resources%20having%20been%20added
###

###
## SNS Topic
###
resource "aws_sns_topic" "sns_topic_eb" {
  name = "${var.deployment_group}-critical-eb"

  tags = {
    Name = var.deployment_group
  }
}

###
## SNS e-mail subscriptions to topic
##
## NOTE:
##    Orphaned subscription confirmations are expected if a topic is removed
##       https://docs.aws.amazon.com/sns/latest/dg/sns-delete-subscription-topic.html
##       https://www.repost.aws/questions/QUB7bWjl97QfGCuddnrZ4Rpw/sns-orphans-subscription-cannot-be-deleted-because-sns-topic-no-longer-exist
##       https://github.com/hashicorp/terraform/issues/17296
##
###
resource "aws_sns_topic_subscription" "sns_topic_eb_subscription" {
  for_each  = toset(var.sns_email_list)
  topic_arn = aws_sns_topic.sns_topic_eb.arn
  protocol  = "email"
  endpoint  = each.value

  # (tags not supported here)
}

###
## Required Policy to grant EventBridge access to SNS topics
###
resource "aws_sns_topic_policy" "eb_sns_access_policy" {
  arn = aws_sns_topic.sns_topic_eb.arn
  policy = jsonencode(
    {
      Id = "Eventbridge-SNS-Access-Policy"
      Statement = [
        {
          Action = "sns:Publish"
          Effect = "Allow"
          Principal = {
            Service = "events.amazonaws.com"
          }
          Resource = aws_sns_topic.sns_topic_eb.arn
          Sid      = "PublishEventsToSNSTopic"
        },
      ]
    }
  )

  # (tags not supported here)
}

###
## EventBridge Rule
## 
## Essential container in task exited: reported when container exits with exit code 1
##   This is not the same as when a user deletes the task and so that will not be reported
##   Sends the message to the rule's target/s (SNS in this case)
## 
## AWS Console: EventBridge | Buses | Rules
##
###
resource "aws_cloudwatch_event_rule" "eb_rule_taskstopped" {
  name        = "taskstopped-${var.deployment_group}"
  description = "Essential container in task exited code 1"
  is_enabled  = var.enableAlerts

  event_pattern = <<EOF
{
   "source":[
      "aws.ecs"
   ],
   "detail-type":[
      "ECS Task State Change"
   ],
   "detail":{
      "lastStatus":[
         "STOPPED"
      ],
      "stoppedReason":[
         "Essential container in task exited"
      ],
      "clusterArn":[
         "arn:aws:ecs:${data.aws_region.current_region.name}:${data.aws_caller_identity.acct_caller_id.account_id}:cluster/${var.deployment_group}"
      ]
   }
}
 EOF

  tags = {
    Name = var.deployment_group
  }
}

###
## EventBridge Target
## 
## Target of the EventBridge rule trigger: type SNS for email notifications
##
## Console: EventBridge | Buses | Rules | <targetname>
##    Targets tab (Monitor tab shows history graph)
##
###
resource "aws_cloudwatch_event_target" "eb_rule_target_taskstopped" {
  rule      = aws_cloudwatch_event_rule.eb_rule_taskstopped.name
  target_id = "SendToSNS-${var.deployment_group}"
  arn       = aws_sns_topic.sns_topic_eb.arn

  # customize the SNS message (very limited)
  input_transformer {
    # event info fields of interest
    input_paths = {
      reason = "$.detail.stoppedReason",
      name   = "$.detail.group",   # contains the server name
      group  = "$.detail.taskArn", # arn contains the deployment group
      region = "$.region",
    }
    # email body
    input_template = <<EOF
{
  "reason": <reason>,
  "name": <name>,
  "group": <group>,
  "region": <region>
}
 EOF
  }

  # (tags not supported here)
}
