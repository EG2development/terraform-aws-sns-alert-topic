variable "region" {
  description = "AWS Region to create the topic in."
  type        = string
  default     = "eu-west-2"
}

variable "name" {
  description = "Name of the topic, and the prefix of the queue, alarm and rule next to it."
  type        = string
  default     = "example-prod-alerts"
}

variable "incident_webhook_url" {
  description = "https URL of the incident tool's SNS integration. Sensitive because such URLs often carry a token."
  type        = string
  sensitive   = true
}

variable "function_name" {
  description = "Lambda function whose errors the example alarm watches."
  type        = string
  default     = "example-worker"
}
