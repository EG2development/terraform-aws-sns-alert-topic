# Tutorial: create your first alert topic

In this tutorial you create an encrypted alert topic with an email subscription,
confirm the subscription, send yourself a test alert, and remove everything again.
It takes about ten minutes. The KMS key costs a small monthly fee, prorated by the
hour; the test message is free.

## Before you start

- Terraform 1.16 or later, the AWS CLI, and credentials for a sandbox AWS account
  that may create SNS topics and subscriptions and KMS keys and aliases. An
  administrator role in a sandbox account has every permission this tutorial needs.
- An email address you can read now.
- Read access to this repository (`git ls-remote https://github.com/EG2development/terraform-aws-sns-alert-topic.git`
  lists its tags).

## 1. Write the configuration

Create an empty directory and a file `main.tf` in it:

```hcl
terraform {
  required_version = ">= 1.16.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}

variable "alert_email" {
  type      = string
  sensitive = true
}

module "alerts" {
  source = "git::https://github.com/EG2development/terraform-aws-sns-alert-topic.git?ref=v1.0.0"

  name = "tutorial-alerts"

  subscriptions = {
    me = { protocol = "email", endpoint = var.alert_email }
  }
}

output "topic_arn" {
  value = module.alerts.topic_arn
}
```

## 2. Create the topic

Set your address, then apply:

```bash
export TF_VAR_alert_email="you@example.com"
terraform init
terraform apply
```

Read the plan before you type `yes`. You should see four resources: the KMS key, its
alias `alias/tutorial-alerts-sns`, the topic `tutorial-alerts`, and the subscription
`module.alerts.aws_sns_topic_subscription.main["me"]`. The email address shows as
`(sensitive value)`.

## 3. Confirm the subscription

Within a few minutes, AWS sends an email titled "AWS Notification - Subscription
Confirmation" to your address. Open it and choose **Confirm subscription**. Then
check the subscription:

```bash
TOPIC_ARN="$(terraform output -raw topic_arn)"
aws sns list-subscriptions-by-topic --topic-arn "${TOPIC_ARN}" \
  --query 'Subscriptions[].[Protocol,SubscriptionArn]' --output table
```

The row for `email` shows a full subscription ARN. Before you confirm, it shows
`PendingConfirmation`.

## 4. Send a test alert

```bash
aws sns publish --topic-arn "${TOPIC_ARN}" \
  --subject "Test alert" --message "This is a test of the tutorial alert topic."
```

The command prints a `MessageId`, and the message arrives by email within a minute.
The topic is encrypted, so publishing needs `kms:GenerateDataKey*` and `kms:Decrypt`
on its key as well as `sns:Publish`; an administrator has all three.

## 5. Clean up

```bash
terraform destroy
```

The topic and the subscription are deleted. The KMS key is scheduled for deletion and
removed after 30 days; until then you can cancel the deletion. If you did not confirm
the subscription, Terraform cannot unsubscribe it, but deleting the topic removes it.

## Next steps

- [Route CloudWatch alarms to the topic](../how-to/route-cloudwatch-alarms.md).
- [Let EventBridge publish](../how-to/let-eventbridge-publish.md) if rules, for
  example AWS Health events, should alert too.
