# Optional inputs change only what they say.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111122223333" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  # The provider checks that these are ARNs, so the mock must return ARN-shaped values.
  mock_resource "aws_kms_key" {
    defaults = {
      arn    = "arn:aws:kms:eu-west-2:111122223333:key/00000000-0000-0000-0000-000000000000"
      key_id = "00000000-0000-0000-0000-000000000000"
    }
  }
  mock_resource "aws_sns_topic" {
    defaults = { arn = "arn:aws:sns:eu-west-2:111122223333:example-alerts" }
  }
  mock_resource "aws_sns_topic_subscription" {
    defaults = { arn = "arn:aws:sns:eu-west-2:111122223333:example-alerts:00000000-0000-0000-0000-000000000000" }
  }
}

variables {
  name = "example-alerts"
}

run "eventbridge_can_publish" {
  command = apply

  variables {
    allow_eventbridge_publish = true
  }

  assert {
    condition     = length(aws_sns_topic_policy.main) == 1 && aws_sns_topic_policy.main[0].arn == aws_sns_topic.main.arn
    error_message = "allow_eventbridge_publish must attach a topic policy to the topic."
  }

  assert {
    condition = (
      [for s in jsondecode(aws_sns_topic_policy.main[0].policy).Statement : s.Sid] == ["AccountManagement", "CloudWatchAlarmsPublish", "EventBridgeRulesPublish"] &&
      alltrue([for s in jsondecode(aws_sns_topic_policy.main[0].policy).Statement : s.Resource == "arn:aws:sns:eu-west-2:111122223333:example-alerts"])
    )
    error_message = "The topic policy must restate the owner and CloudWatch access and add EventBridge, all on this topic only."
  }

  assert {
    condition = (
      jsondecode(aws_sns_topic_policy.main[0].policy).Statement[0].Principal.AWS == "arn:aws:iam::111122223333:root" &&
      jsondecode(aws_sns_topic_policy.main[0].policy).Statement[0].Action == ["SNS:GetTopicAttributes", "SNS:SetTopicAttributes", "SNS:AddPermission", "SNS:RemovePermission", "SNS:DeleteTopic", "SNS:Subscribe", "SNS:ListSubscriptionsByTopic", "SNS:Publish"] &&
      jsondecode(aws_sns_topic_policy.main[0].policy).Statement[0].Condition.StringEquals["AWS:SourceOwner"] == "111122223333"
    )
    error_message = "The owner statement must mirror SNS's default statement, for this account only."
  }

  assert {
    condition = (
      jsondecode(aws_sns_topic_policy.main[0].policy).Statement[1].Principal.Service == "cloudwatch.amazonaws.com" &&
      jsondecode(aws_sns_topic_policy.main[0].policy).Statement[2].Principal.Service == "events.amazonaws.com" &&
      alltrue([for s in slice(jsondecode(aws_sns_topic_policy.main[0].policy).Statement, 1, 3) : s.Action == "sns:Publish" && s.Condition.StringEquals["aws:SourceAccount"] == "111122223333"])
    )
    error_message = "CloudWatch and EventBridge may only publish, and only on behalf of this account."
  }

  assert {
    condition = (
      length(jsondecode(aws_kms_key.main[0].policy).Statement) == 3 &&
      jsondecode(aws_kms_key.main[0].policy).Statement[2].Sid == "EventBridgeRulesUseKey" &&
      jsondecode(aws_kms_key.main[0].policy).Statement[2].Principal.Service == "events.amazonaws.com" &&
      jsondecode(aws_kms_key.main[0].policy).Statement[2].Action == ["kms:Decrypt", "kms:GenerateDataKey*"] &&
      !contains(keys(jsondecode(aws_kms_key.main[0].policy).Statement[2]), "Condition")
    )
    error_message = "EventBridge must be able to use the key, with no source condition (AWS does not support one for EventBridge)."
  }
}

run "bring_your_own_key" {
  command = plan

  variables {
    create_kms_key    = false
    kms_master_key_id = "alias/payments-alerts"
  }

  assert {
    condition     = aws_sns_topic.main.kms_master_key_id == "alias/payments-alerts" && output.kms_key_arn == "alias/payments-alerts"
    error_message = "The topic must use the caller's key, and kms_key_arn must report it as given."
  }

  assert {
    condition     = length(aws_kms_key.main) == 0 && length(aws_kms_alias.main) == 0 && length(data.aws_caller_identity.current) == 0
    error_message = "With the caller's key the module creates no key and makes no lookups."
  }
}

run "eventbridge_with_your_own_key" {
  command = apply

  variables {
    create_kms_key            = false
    kms_master_key_id         = "arn:aws:kms:eu-west-2:111122223333:key/11111111-1111-1111-1111-111111111111"
    allow_eventbridge_publish = true
  }

  assert {
    condition     = length(aws_sns_topic_policy.main) == 1 && length(aws_kms_key.main) == 0
    error_message = "The topic policy does not depend on the module creating the key."
  }
}

run "unencrypted_without_a_key" {
  command = plan

  variables {
    create_kms_key = false
  }

  assert {
    condition     = aws_sns_topic.main.kms_master_key_id == null && output.kms_key_arn == null
    error_message = "create_kms_key = false with no kms_master_key_id leaves the topic unencrypted."
  }
}

run "one_subscription_per_key" {
  command = apply

  variables {
    subscriptions = {
      oncall  = { protocol = "email", endpoint = "oncall@example.com" }
      pager   = { protocol = "https", endpoint = "https://events.example.com/sns" }
      archive = { protocol = "sqs", endpoint = "arn:aws:sqs:eu-west-2:111122223333:alerts-archive" }
      stream = {
        protocol              = "firehose"
        endpoint              = "arn:aws:firehose:eu-west-2:111122223333:deliverystream/alerts"
        subscription_role_arn = "arn:aws:iam::111122223333:role/sns-to-firehose"
      }
    }
  }

  assert {
    condition     = toset(keys(aws_sns_topic_subscription.main)) == toset(["oncall", "pager", "archive", "stream"])
    error_message = "One subscription per key, addressed by the key."
  }

  assert {
    condition = (
      aws_sns_topic_subscription.main["oncall"].protocol == "email" &&
      aws_sns_topic_subscription.main["pager"].endpoint == "https://events.example.com/sns" &&
      aws_sns_topic_subscription.main["archive"].topic_arn == aws_sns_topic.main.arn
    )
    error_message = "Each subscription must carry its protocol and endpoint, on this topic."
  }

  assert {
    condition     = aws_sns_topic_subscription.main["stream"].subscription_role_arn == "arn:aws:iam::111122223333:role/sns-to-firehose" && aws_sns_topic_subscription.main["oncall"].subscription_role_arn == null
    error_message = "subscription_role_arn reaches the firehose subscription only."
  }

  assert {
    condition     = toset(keys(output.subscription_arns)) == toset(["oncall", "pager", "archive", "stream"]) && output.subscription_arns["oncall"] == aws_sns_topic_subscription.main["oncall"].arn
    error_message = "subscription_arns maps each label to its subscription ARN."
  }
}

run "key_deletion_window" {
  command = plan

  variables {
    kms_key_deletion_window_in_days = 7
  }

  assert {
    condition     = aws_kms_key.main[0].deletion_window_in_days == 7
    error_message = "kms_key_deletion_window_in_days must reach the key."
  }
}

run "longest_name_without_a_key" {
  command = plan

  # 256 characters is the SNS limit; the 246-character limit applies only to
  # the alias of a key the module creates.
  variables {
    name           = format("%0256d", 0)
    create_kms_key = false
  }

  assert {
    condition     = length(aws_sns_topic.main.name) == 256
    error_message = "A 256-character name is valid when the module creates no key."
  }
}
