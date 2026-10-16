variable "region" {
  description = "AWS Region to create the topic in."
  type        = string
  default     = "eu-west-2"
}

variable "name" {
  description = "Name of the topic."
  type        = string
  default     = "example-alerts"
}

variable "alert_email" {
  description = "Email address that receives the alerts. The recipient must confirm the subscription from the email AWS sends."
  type        = string
  sensitive   = true
}
