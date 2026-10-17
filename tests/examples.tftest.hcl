# The examples are real configurations. Each must plan against the mocked
# provider, so an example that stops working fails CI. Both pass a sensitive
# endpoint, which proves the module accepts one.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111122223333" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
}

run "basic_example_plans" {
  command = plan

  module {
    source = "./examples/basic"
  }

  variables {
    alert_email = "alerts@example.com"
  }

  assert {
    condition     = keys(module.alerts.subscription_arns) == ["oncall"]
    error_message = "The basic example creates one email subscription."
  }
}

run "complete_example_plans" {
  command = plan

  module {
    source = "./examples/complete"
  }

  variables {
    incident_webhook_url = "https://incidents.example.com/hooks/sns"
  }

  assert {
    condition     = toset(keys(module.alerts.subscription_arns)) == toset(["archive", "incident_tool"])
    error_message = "The complete example creates an SQS and an https subscription."
  }
}
