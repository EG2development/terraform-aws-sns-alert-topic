# How to let EventBridge publish

EventBridge rules need a topic policy statement, and, on an encrypted topic, a key
policy statement. `allow_eventbridge_publish` adds both for rules in the topic's own
account.

## Before you start

The setting gives the topic a policy, which replaces SNS's default topic policy. The
new policy keeps access for the owning account and for CloudWatch alarms. Any other
AWS service that publishes to this topic through the default policy loses access.
Check the current publishers first:

```bash
aws sns get-topic-attributes --topic-arn "$(terraform output -raw topic_arn)" \
  --query 'Attributes.Policy' --output text
```

## 1. Turn it on

```hcl
module "alerts" {
  # ...
  allow_eventbridge_publish = true
}
```

Run `terraform plan`. Check it contains exactly these changes:

- `aws_sns_topic_policy.main[0]` will be created,
- `aws_kms_key.main[0]` will be updated in place (its policy gains the
  `EventBridgeRulesUseKey` statement), unless you brought your own key.

With your own key, add the EventBridge statement to its key policy yourself; see
[How to bring your own KMS key](bring-your-own-kms-key.md).

Apply it.

## 2. Add a rule that targets the topic

```hcl
resource "aws_cloudwatch_event_rule" "aws_health" {
  name        = "aws-health-to-alerts"
  description = "AWS Health events for this account."

  event_pattern = jsonencode({
    source        = ["aws.health"]
    "detail-type" = ["AWS Health Event"]
  })
}

resource "aws_cloudwatch_event_target" "aws_health" {
  rule      = aws_cloudwatch_event_rule.aws_health.name
  target_id = "alert-topic"
  arn       = module.alerts.topic_arn
}
```

Leave `role_arn` unset on the target: the topic policy grants the access.

## 3. Check that an event arrives

AWS reserves `aws.*` sources, so test with a rule of your own that matches a custom
source, for example `{ source = ["example.alerts"] }`, targeting the topic in the
same way. Then send a matching event:

```bash
aws events put-events --entries \
  '[{"Source":"example.alerts","DetailType":"Test alert","Detail":"{\"message\":\"test\"}"}]'
```

Each subscriber receives the event as JSON. If nothing arrives, check the rule's
`FailedInvocations` metric in the `AWS/Events` namespace.
