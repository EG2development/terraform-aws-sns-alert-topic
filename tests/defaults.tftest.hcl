# What a caller gets from the name alone. These assertions pin names, tags and
# secure defaults; a change to any of them changes existing callers'
# infrastructure, which is a major release.
# The provider is mocked: no credentials, nothing created.

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
}

variables {
  name = "example-alerts"
  tags = { Team = "platform" }
}

run "topic_is_encrypted_with_the_module_key" {
  command = apply

  assert {
    condition     = length(aws_kms_key.main) == 1 && aws_sns_topic.main.kms_master_key_id == aws_kms_key.main[0].arn
    error_message = "The topic must be encrypted with the customer managed key the module creates."
  }

  assert {
    condition     = aws_kms_key.main[0].enable_key_rotation && aws_kms_key.main[0].deletion_window_in_days == 30
    error_message = "The key must rotate yearly and wait 30 days before deletion."
  }

  assert {
    condition     = aws_kms_alias.main[0].target_key_id == aws_kms_key.main[0].key_id
    error_message = "The alias must point at the module's key."
  }

  assert {
    condition     = length(aws_sns_topic_policy.main) == 0 && length(aws_sns_topic_subscription.main) == 0
    error_message = "By default there is no topic policy (SNS's default applies) and no subscription."
  }

  assert {
    condition = (
      output.topic_arn == "arn:aws:sns:eu-west-2:111122223333:example-alerts" &&
      output.topic_name == "example-alerts" &&
      output.kms_key_arn == aws_kms_key.main[0].arn &&
      output.subscription_arns == {}
    )
    error_message = "The outputs must report the topic, its key and no subscriptions."
  }
}

run "names_and_tags_are_stable" {
  command = plan

  # Callers rely on these exact names; changing one is a breaking change.
  assert {
    condition     = aws_sns_topic.main.name == "example-alerts" && aws_sns_topic.main.tags == tomap({ Name = "example-alerts", Team = "platform" })
    error_message = "The topic must be named var.name and tagged Name=<name> plus var.tags."
  }

  assert {
    condition     = aws_kms_alias.main[0].name == "alias/example-alerts-sns"
    error_message = "The key alias must be alias/<name>-sns."
  }

  assert {
    condition = (
      aws_kms_key.main[0].tags == tomap({ Name = "example-alerts-sns", Team = "platform" }) &&
      aws_kms_key.main[0].description == "Encrypts messages on the SNS topic example-alerts"
    )
    error_message = "The key's Name tag must be <name>-sns and its description must name the topic."
  }
}

run "key_policy_lets_cloudwatch_alarms_publish" {
  command = plan

  assert {
    condition = (
      length(jsondecode(aws_kms_key.main[0].policy).Statement) == 2 &&
      jsondecode(aws_kms_key.main[0].policy).Statement[0].Sid == "AccountAdministration" &&
      jsondecode(aws_kms_key.main[0].policy).Statement[0].Principal.AWS == "arn:aws:iam::111122223333:root" &&
      jsondecode(aws_kms_key.main[0].policy).Statement[0].Action == "kms:*"
    )
    error_message = "The key policy must start with the account administration statement, and have no EventBridge statement by default."
  }

  assert {
    condition = (
      jsondecode(aws_kms_key.main[0].policy).Statement[1].Sid == "CloudWatchAlarmsUseKey" &&
      jsondecode(aws_kms_key.main[0].policy).Statement[1].Principal.Service == "cloudwatch.amazonaws.com" &&
      jsondecode(aws_kms_key.main[0].policy).Statement[1].Action == ["kms:Decrypt", "kms:GenerateDataKey*"] &&
      jsondecode(aws_kms_key.main[0].policy).Statement[1].Resource == "*" &&
      jsondecode(aws_kms_key.main[0].policy).Statement[1].Condition.StringEquals["aws:SourceAccount"] == "111122223333"
    )
    error_message = "CloudWatch must be able to use the key, only on behalf of this account."
  }
}
