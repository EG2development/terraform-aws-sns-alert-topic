# A customer managed key for the topic. CloudWatch alarms cannot publish to a
# topic encrypted with the AWS managed key alias/aws/sns, because that key's
# policy does not let the CloudWatch service use it and cannot be changed.
# This key's policy can. In a key policy, Resource "*" means this key.

resource "aws_kms_key" "main" {
  count = var.create_kms_key ? 1 : 0

  description             = "Encrypts messages on the SNS topic ${var.name}"
  enable_key_rotation     = true
  deletion_window_in_days = var.kms_key_deletion_window_in_days

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          # The standard first statement: the account administers and uses
          # the key through IAM policies. Without it the key is unmanageable.
          Sid       = "AccountAdministration"
          Effect    = "Allow"
          Principal = { AWS = "arn:${data.aws_partition.current[0].partition}:iam::${data.aws_caller_identity.current[0].account_id}:root" }
          Action    = "kms:*"
          Resource  = "*"
        },
        {
          # What a publisher needs on an encrypted topic. Confused-deputy
          # protection: only on behalf of this account.
          Sid       = "CloudWatchAlarmsUseKey"
          Effect    = "Allow"
          Principal = { Service = "cloudwatch.amazonaws.com" }
          Action    = ["kms:Decrypt", "kms:GenerateDataKey*"]
          Resource  = "*"
          Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current[0].account_id } }
        },
      ],
      # No source condition here: AWS does not support aws:SourceAccount,
      # aws:SourceArn or aws:SourceOrgID in a key policy for EventBridge
      # publishing to an encrypted topic, and with one the events are dropped.
      # The topic policy limits EventBridge to rules in this account instead.
      var.allow_eventbridge_publish ? [
        {
          Sid       = "EventBridgeRulesUseKey"
          Effect    = "Allow"
          Principal = { Service = "events.amazonaws.com" }
          Action    = ["kms:Decrypt", "kms:GenerateDataKey*"]
          Resource  = "*"
        },
      ] : [],
    )
  })

  tags = merge({ Name = "${var.name}-sns" }, var.tags)
}

resource "aws_kms_alias" "main" {
  count = var.create_kms_key ? 1 : 0

  name          = "alias/${var.name}-sns"
  target_key_id = aws_kms_key.main[0].key_id
}
