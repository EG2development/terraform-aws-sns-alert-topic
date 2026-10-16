# A production-style alert topic: encrypted with the module's key, open to
# EventBridge rules in this account, every alert copied to an SQS queue and
# sent to an incident tool over https. Next to the module, a CloudWatch alarm
# and an EventBridge rule publish to it through the topic_arn output.

provider "aws" {
  region = var.region
}

module "alerts" {
  source = "../.."

  name                      = var.name
  allow_eventbridge_publish = true

  subscriptions = {
    archive = { protocol = "sqs", endpoint = aws_sqs_queue.alert_archive.arn }
    # The endpoint must confirm the subscription: SNS posts a
    # SubscriptionConfirmation request to it first.
    incident_tool = { protocol = "https", endpoint = var.incident_webhook_url }
  }

  tags = {
    Environment = "prod"
    Team        = "platform"
  }
}

# A copy of every alert, kept for two weeks. SQS-managed encryption needs no
# key policy for SNS to deliver.
resource "aws_sqs_queue" "alert_archive" {
  name                      = "${var.name}-archive"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}

# Only this topic may send to the queue.
resource "aws_sqs_queue_policy" "alert_archive" {
  queue_url = aws_sqs_queue.alert_archive.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AlertTopicDelivers"
        Effect    = "Allow"
        Principal = { Service = "sns.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.alert_archive.arn
        Condition = { ArnEquals = { "aws:SourceArn" = module.alerts.topic_arn } }
      },
    ]
  })
}

# Composition: a CloudWatch alarm notifies the topic when it fires and when it
# recovers.
resource "aws_cloudwatch_metric_alarm" "worker_errors" {
  alarm_name          = "${var.name}-worker-errors"
  alarm_description   = "The ${var.function_name} function reported errors."
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = var.function_name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [module.alerts.topic_arn]
  ok_actions    = [module.alerts.topic_arn]
}

# Composition: an EventBridge rule forwards AWS Health events for this account.
resource "aws_cloudwatch_event_rule" "aws_health" {
  name        = "${var.name}-aws-health"
  description = "AWS Health events for this account."

  event_pattern = jsonencode({
    source        = ["aws.health"]
    "detail-type" = ["AWS Health Event"]
  })
}

resource "aws_cloudwatch_event_target" "aws_health" {
  rule      = aws_cloudwatch_event_rule.aws_health.name
  target_id = "alert-topic"
  arn       = module.alerts.topic_arn
}
