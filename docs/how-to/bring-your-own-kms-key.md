# How to bring your own KMS key

Use this when the topic must be encrypted with a key you already manage, for example a
shared key for all alerting in an account. The module then creates no key and no
alias.

## 1. Give the key the statements the topic needs

The key must be a symmetric encryption key in the topic's Region, and its policy must
include the statements below. Replace `111122223333` with the account ID.

| Statement | When |
| --- | --- |
| `CloudWatchAlarmsUseKey` | Always |
| `EventBridgeRulesUseKey` | Only with `allow_eventbridge_publish = true` |

```json
{
  "Sid": "CloudWatchAlarmsUseKey",
  "Effect": "Allow",
  "Principal": { "Service": "cloudwatch.amazonaws.com" },
  "Action": ["kms:Decrypt", "kms:GenerateDataKey*"],
  "Resource": "*",
  "Condition": { "StringEquals": { "aws:SourceAccount": "111122223333" } }
}
```

```json
{
  "Sid": "EventBridgeRulesUseKey",
  "Effect": "Allow",
  "Principal": { "Service": "events.amazonaws.com" },
  "Action": ["kms:Decrypt", "kms:GenerateDataKey*"],
  "Resource": "*"
}
```

Do not add a condition to the EventBridge statement: AWS does not support
`aws:SourceAccount`, `aws:SourceArn` or `aws:SourceOrgID` there, and events are
dropped.

Other publishers, such as applications, need `kms:GenerateDataKey*` and
`kms:Decrypt` on the key in their IAM policies, as well as `sns:Publish` on the topic.

## 2. Point the module at the key

```hcl
module "alerts" {
  # ...
  create_kms_key    = false
  kms_master_key_id = aws_kms_key.alerting.arn
}
```

`kms_master_key_id` accepts a key ID, key ARN, alias name or alias ARN. The module
rejects `alias/aws/sns`.

## 3. Apply

Run `terraform plan`. For a topic that used the module's key, check it contains exactly
these changes:

- `aws_sns_topic.main` will be updated in place (`kms_master_key_id`),
- `aws_kms_alias.main[0]` will be destroyed,
- `aws_kms_key.main[0]` will be destroyed, which schedules the key for deletion after
  `kms_key_deletion_window_in_days`.

Apply it, then force a test alarm as in
[How to route CloudWatch alarms to the topic](route-cloudwatch-alarms.md#check-that-a-notification-arrives).
If the notification fails, the key policy is missing the CloudWatch statement.

To go back to a module-managed key, remove both inputs and apply.
