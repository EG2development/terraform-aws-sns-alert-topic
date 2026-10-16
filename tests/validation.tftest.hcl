# Every validation rejects bad input at plan time, before any API call.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111122223333" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
}

variables {
  name = "example-alerts"
}

run "accepts_valid_input" {
  command = plan
}

run "rejects_name_with_invalid_characters" {
  command = plan
  variables {
    name = "example alerts"
  }
  expect_failures = [var.name]
}

run "rejects_fifo_topic_name" {
  command = plan
  variables {
    name = "example-alerts.fifo"
  }
  expect_failures = [var.name]
}

run "rejects_empty_name" {
  command = plan
  variables {
    name = ""
  }
  expect_failures = [var.name]
}

run "rejects_name_longer_than_sns_allows" {
  command = plan
  variables {
    name           = format("%0257d", 0)
    create_kms_key = false
  }
  expect_failures = [var.name]
}

run "rejects_name_too_long_for_the_key_alias" {
  command = plan
  variables {
    name = format("%0247d", 0)
  }
  expect_failures = [var.name]
}

run "rejects_own_key_while_creating_one" {
  command = plan
  variables {
    kms_master_key_id = "alias/payments-alerts"
  }
  expect_failures = [var.kms_master_key_id]
}

run "rejects_aws_managed_sns_key_alias" {
  command = plan
  variables {
    create_kms_key    = false
    kms_master_key_id = "alias/aws/sns"
  }
  expect_failures = [var.kms_master_key_id]
}

run "rejects_aws_managed_sns_key_alias_arn" {
  command = plan
  variables {
    create_kms_key    = false
    kms_master_key_id = "arn:aws:kms:eu-west-2:111122223333:alias/aws/sns"
  }
  expect_failures = [var.kms_master_key_id]
}

run "rejects_empty_key_id" {
  command = plan
  variables {
    create_kms_key    = false
    kms_master_key_id = ""
  }
  expect_failures = [var.kms_master_key_id]
}

run "rejects_deletion_window_below_7_days" {
  command = plan
  variables {
    kms_key_deletion_window_in_days = 6
  }
  expect_failures = [var.kms_key_deletion_window_in_days]
}

run "rejects_deletion_window_above_30_days" {
  command = plan
  variables {
    kms_key_deletion_window_in_days = 31
  }
  expect_failures = [var.kms_key_deletion_window_in_days]
}

run "rejects_fractional_deletion_window" {
  command = plan
  variables {
    kms_key_deletion_window_in_days = 7.5
  }
  expect_failures = [var.kms_key_deletion_window_in_days]
}

run "rejects_plain_http_subscription" {
  command = plan
  variables {
    subscriptions = {
      webhook = { protocol = "http", endpoint = "http://events.example.com/sns" }
    }
  }
  expect_failures = [var.subscriptions]
}

run "rejects_unknown_protocol" {
  command = plan
  variables {
    subscriptions = {
      chat = { protocol = "slack", endpoint = "#alerts" }
    }
  }
  expect_failures = [var.subscriptions]
}

run "rejects_empty_endpoint" {
  command = plan
  variables {
    subscriptions = {
      oncall = { protocol = "email", endpoint = "" }
    }
  }
  expect_failures = [var.subscriptions]
}

run "rejects_firehose_without_role" {
  command = plan
  variables {
    subscriptions = {
      stream = { protocol = "firehose", endpoint = "arn:aws:firehose:eu-west-2:111122223333:deliverystream/alerts" }
    }
  }
  expect_failures = [var.subscriptions]
}

run "rejects_role_on_non_firehose_subscription" {
  command = plan
  variables {
    subscriptions = {
      oncall = { protocol = "email", endpoint = "oncall@example.com", subscription_role_arn = "arn:aws:iam::111122223333:role/sns-to-firehose" }
    }
  }
  expect_failures = [var.subscriptions]
}
