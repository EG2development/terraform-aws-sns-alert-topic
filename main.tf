# Resource names are "main" so that every caller sees the same addresses. They
# are a compatibility contract: renaming one is a breaking change and needs a
# moved block.

# The account ID and partition are needed only for the key policy and the
# topic policy. A caller who wants neither makes no lookups.
data "aws_caller_identity" "current" {
  count = var.create_kms_key || var.allow_eventbridge_publish ? 1 : 0
}

data "aws_partition" "current" {
  count = var.create_kms_key || var.allow_eventbridge_publish ? 1 : 0
}

resource "aws_sns_topic" "main" {
  name              = var.name
  kms_master_key_id = var.create_kms_key ? aws_kms_key.main[0].arn : var.kms_master_key_id

  tags = merge({ Name = var.name }, var.tags)
}

# A topic policy replaces SNS's default policy rather than adding to it. So the
# policy restates what the default gave the owning account and the CloudWatch
# alarms in it, then adds EventBridge. Without EventBridge there is no topic
# policy at all, and SNS's default applies.
resource "aws_sns_topic_policy" "main" {
  count = var.allow_eventbridge_publish ? 1 : 0

  arn = aws_sns_topic.main.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # SNS's default statement, with the principal narrowed from "*" to
        # this account.
        Sid       = "AccountManagement"
        Effect    = "Allow"
        Principal = { AWS = "arn:${data.aws_partition.current[0].partition}:iam::${data.aws_caller_identity.current[0].account_id}:root" }
        Action = [
          "SNS:GetTopicAttributes",
          "SNS:SetTopicAttributes",
          "SNS:AddPermission",
          "SNS:RemovePermission",
          "SNS:DeleteTopic",
          "SNS:Subscribe",
          "SNS:ListSubscriptionsByTopic",
          "SNS:Publish",
        ]
        Resource  = aws_sns_topic.main.arn
        Condition = { StringEquals = { "AWS:SourceOwner" = data.aws_caller_identity.current[0].account_id } }
      },
      {
        # Confused-deputy protection: only alarms in this account.
        Sid       = "CloudWatchAlarmsPublish"
        Effect    = "Allow"
        Principal = { Service = "cloudwatch.amazonaws.com" }
        Action    = "sns:Publish"
        Resource  = aws_sns_topic.main.arn
        Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current[0].account_id } }
      },
      {
        # Confused-deputy protection: only rules in this account.
        Sid       = "EventBridgeRulesPublish"
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "sns:Publish"
        Resource  = aws_sns_topic.main.arn
        Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current[0].account_id } }
      },
    ]
  })
}

# Terraform refuses for_each over a module input that holds any sensitive
# value, and callers often pass sensitive endpoints. So the module iterates
# over the keys alone and declassifies them: keys are labels, documented as
# never secret. Every endpoint keeps its sensitivity.
resource "aws_sns_topic_subscription" "main" {
  for_each = nonsensitive(toset(keys(var.subscriptions)))

  topic_arn             = aws_sns_topic.main.arn
  protocol              = var.subscriptions[each.key].protocol
  endpoint              = var.subscriptions[each.key].endpoint
  subscription_role_arn = var.subscriptions[each.key].subscription_role_arn
}
