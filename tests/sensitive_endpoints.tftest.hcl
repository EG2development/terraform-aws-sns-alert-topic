# Callers pass sensitive endpoints, and often decide whether a subscription
# exists from a sensitive value. Terraform rejects for_each over a sensitive
# map, so these runs fail if the module stops iterating over its declassified
# keys. Endpoints themselves stay sensitive.

mock_provider "aws" {}

run "sensitive_condition_with_an_address" {
  command = plan

  module {
    source = "./tests/fixtures/optional-sensitive-email"
  }

  variables {
    alert_email = "alerts@example.com"
  }

  assert {
    condition     = keys(module.alerts.subscription_arns) == ["email"]
    error_message = "A subscription built from a sensitive condition must still be planned."
  }
}

run "sensitive_condition_without_an_address" {
  command = plan

  module {
    source = "./tests/fixtures/optional-sensitive-email"
  }

  variables {
    alert_email = ""
  }

  assert {
    condition     = length(module.alerts.subscription_arns) == 0
    error_message = "No address means no subscription."
  }
}
