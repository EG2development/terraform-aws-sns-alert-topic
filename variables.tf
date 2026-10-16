variable "name" {
  description = "Name of the SNS topic, for example \"payments-prod-alerts\". It also names the module's KMS key alias, \"alias/{name}-sns\". Changing it replaces the topic and its subscriptions, and email recipients must confirm again."
  type        = string
  nullable    = false

  validation {
    # SNS standard topic names. A FIFO topic name ends in ".fifo", which the
    # character set below excludes: the module creates standard topics only.
    condition     = can(regex("^[A-Za-z0-9_-]{1,256}$", var.name))
    error_message = "name must be 1-256 characters: letters, digits, hyphens and underscores. FIFO topics (\".fifo\") are not supported."
  }

  validation {
    # KMS alias names are limited to 256 characters, "alias/" and "-sns" included.
    condition     = !var.create_kms_key || length(var.name) <= 246
    error_message = "name must be at most 246 characters when create_kms_key is true, so that the alias \"alias/<name>-sns\" fits in 256."
  }
}

variable "create_kms_key" {
  description = "Create a customer managed KMS key for the topic, with a key policy that lets CloudWatch alarms (and EventBridge, with allow_eventbridge_publish) publish. On by default. Set it to false to use your own key in kms_master_key_id; false with no kms_master_key_id leaves the topic unencrypted."
  type        = bool
  default     = true
  nullable    = false
}

variable "kms_master_key_id" {
  description = "Your own KMS key for the topic, used only when create_kms_key is false: a key ID, key ARN, alias name or alias ARN. Its key policy must let cloudwatch.amazonaws.com use kms:Decrypt and kms:GenerateDataKey*. The AWS managed key alias/aws/sns is rejected: CloudWatch alarms cannot publish to a topic encrypted with it. Null (default)."
  type        = string
  default     = null

  validation {
    condition     = var.kms_master_key_id == null || !var.create_kms_key
    error_message = "kms_master_key_id is used only when create_kms_key is false. Set create_kms_key = false to bring your own key, or remove kms_master_key_id."
  }

  validation {
    condition     = var.kms_master_key_id == null ? true : !can(regex("^(arn:[^:]+:kms:[^:]*:[0-9]*:)?alias/aws/sns$", var.kms_master_key_id))
    error_message = "kms_master_key_id must not be the AWS managed key alias/aws/sns: its key policy does not let CloudWatch use it and cannot be changed, so alarm notifications would fail. Use a customer managed key, or let the module create one (create_kms_key = true)."
  }

  validation {
    condition     = var.kms_master_key_id == null ? true : length(trimspace(var.kms_master_key_id)) > 0
    error_message = "kms_master_key_id must not be empty. Use null for no key."
  }
}

variable "kms_key_deletion_window_in_days" {
  description = "Days KMS waits before deleting the module's key once it is scheduled for deletion, for example by terraform destroy. The key can be restored during the wait. 7-30, default 30."
  type        = number
  default     = 30
  nullable    = false

  validation {
    condition     = var.kms_key_deletion_window_in_days >= 7 && var.kms_key_deletion_window_in_days <= 30 && floor(var.kms_key_deletion_window_in_days) == var.kms_key_deletion_window_in_days
    error_message = "kms_key_deletion_window_in_days must be a whole number from 7 to 30."
  }
}

variable "allow_eventbridge_publish" {
  description = "Let EventBridge rules in this account publish to the topic. Adds a topic policy, which replaces SNS's default policy and restates the access of this account and its CloudWatch alarms, and an events.amazonaws.com statement in the module's key policy. Off by default."
  type        = bool
  default     = false
  nullable    = false
}

variable "subscriptions" {
  description = "Subscriptions to create, keyed by a static label you choose, for example { oncall = { protocol = \"email\", endpoint = var.oncall_email } }. protocol is email, email-json, https, sqs, lambda, firehose, sms or application; plain http is rejected. firehose also needs subscription_role_arn. Email subscriptions stay pending until the recipient confirms. Endpoints appear in plan output unless you pass sensitive values. Keys always appear in plan output and resource addresses: never put a secret in a key."
  type = map(object({
    protocol              = string
    endpoint              = string
    subscription_role_arn = optional(string)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for s in values(var.subscriptions) : s.protocol != "http"])
    error_message = "Plain http subscriptions are not allowed: SNS would send alert content unencrypted, and nothing proves the endpoint is who it claims to be. Use https."
  }

  validation {
    condition     = alltrue([for s in values(var.subscriptions) : contains(["email", "email-json", "https", "sqs", "lambda", "firehose", "sms", "application", "http"], s.protocol)])
    error_message = "Every subscription's protocol must be email, email-json, https, sqs, lambda, firehose, sms or application."
  }

  validation {
    condition     = alltrue([for s in values(var.subscriptions) : length(trimspace(s.endpoint)) > 0])
    error_message = "Every subscription needs a non-empty endpoint. To make a subscription optional, leave its key out of the map."
  }

  validation {
    condition     = alltrue([for s in values(var.subscriptions) : (s.protocol == "firehose") == (s.subscription_role_arn != null)])
    error_message = "subscription_role_arn is required for firehose subscriptions and not allowed for any other protocol."
  }
}

variable "tags" {
  description = "Tags for the topic and the KMS key. The module adds a Name tag to each; a Name key here overrides it, so it is rarely what you want. Tags from the provider's default_tags apply as usual."
  type        = map(string)
  default     = {}
  nullable    = false
}
