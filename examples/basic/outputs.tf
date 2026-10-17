output "topic_arn" {
  description = "ARN of the topic, for alarm_actions on CloudWatch alarms."
  value       = module.alerts.topic_arn
}

output "kms_key_arn" {
  description = "ARN of the key that encrypts the topic."
  value       = module.alerts.kms_key_arn
}

output "subscription_arns" {
  description = "ARN of each subscription, by label."
  value       = module.alerts.subscription_arns
}
