output "topic_arn" {
  description = "ARN of the topic."
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

output "alert_archive_queue_url" {
  description = "URL of the queue that keeps a copy of every alert."
  value       = aws_sqs_queue.alert_archive.id
}
