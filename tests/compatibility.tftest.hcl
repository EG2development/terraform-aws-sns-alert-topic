# An existing caller's topic, adopted into the module: unencrypted, one email
# subscription, no topic policy. Its plan must show exactly these two
# resources, with exactly these values, or adopting the module changes the
# caller's infrastructure.

mock_provider "aws" {}

variables {
  name           = "example-prod-alerts"
  create_kms_key = false
  subscriptions = {
    email = { protocol = "email", endpoint = "alerts@example.com" }
  }
  tags = {
    Project     = "example"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

run "existing_unencrypted_caller_is_unchanged" {
  command = plan

  assert {
    condition = (
      aws_sns_topic.main.name == "example-prod-alerts" &&
      aws_sns_topic.main.kms_master_key_id == null &&
      aws_sns_topic.main.tags == tomap({ Project = "example", Environment = "prod", ManagedBy = "terraform", Name = "example-prod-alerts" })
    )
    error_message = "The topic must have exactly the caller's name and tags, and no encryption."
  }

  assert {
    condition = (
      keys(aws_sns_topic_subscription.main) == ["email"] &&
      aws_sns_topic_subscription.main["email"].protocol == "email" &&
      aws_sns_topic_subscription.main["email"].endpoint == "alerts@example.com" &&
      aws_sns_topic_subscription.main["email"].subscription_role_arn == null
    )
    error_message = "There must be exactly one subscription, aws_sns_topic_subscription.main[\"email\"], with protocol email."
  }

  assert {
    condition     = length(aws_kms_key.main) == 0 && length(aws_kms_alias.main) == 0 && length(aws_sns_topic_policy.main) == 0
    error_message = "No KMS key, alias or topic policy may be planned for this caller."
  }

  assert {
    condition     = length(data.aws_caller_identity.current) == 0 && length(data.aws_partition.current) == 0
    error_message = "This caller needs no account lookup."
  }

  assert {
    condition     = output.kms_key_arn == null
    error_message = "kms_key_arn is null for an unencrypted topic."
  }
}
