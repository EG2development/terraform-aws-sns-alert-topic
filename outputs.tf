output "topic_arn" {
  description = "ARN of the topic, for alarm_actions and ok_actions on CloudWatch alarms, EventBridge rule targets and IAM policies."
  value       = aws_sns_topic.main.arn
}

output "topic_name" {
  description = "Name of the topic."
  value       = aws_sns_topic.main.name
}

output "kms_key_arn" {
  description = "Key that encrypts the topic: the ARN of the module's key, or kms_master_key_id exactly as given when you brought your own. Null when the topic is not encrypted. Grant publishers kms:GenerateDataKey* and kms:Decrypt on it."
  value       = var.create_kms_key ? aws_kms_key.main[0].arn : var.kms_master_key_id
}

output "subscription_arns" {
  description = "ARN of each subscription, keyed by the labels in subscriptions."
  value       = { for label, subscription in aws_sns_topic_subscription.main : label => subscription.arn }
}
