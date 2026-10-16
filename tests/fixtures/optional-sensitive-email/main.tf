# Test fixture: a caller whose alert address is sensitive and optional. The
# map is built by a condition on the sensitive value, so Terraform 1.10 and
# later mark the whole map sensitive, keys included.

variable "alert_email" {
  description = "Address that receives alerts; empty for none."
  type        = string
  sensitive   = true
}

module "alerts" {
  source = "../../.."

  name           = "example-alerts"
  create_kms_key = false

  subscriptions = var.alert_email != "" ? {
    email = { protocol = "email", endpoint = var.alert_email }
  } : {}
}
