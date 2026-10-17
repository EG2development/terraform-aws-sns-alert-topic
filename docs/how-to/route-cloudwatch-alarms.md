# How to route CloudWatch alarms to the topic

The module's key policy already lets CloudWatch alarms in the same account publish to
the topic. Point each alarm at the `topic_arn` output, in your own configuration next
to the module call.

## Notify on alarm and on recovery

```hcl
resource "aws_cloudwatch_metric_alarm" "queue_backlog" {
  alarm_name          = "orders-queue-backlog"
  alarm_description   = "Orders are waiting more than 15 minutes."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateAgeOfOldestMessage"
  dimensions          = { QueueName = "orders" }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 900
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [module.alerts.topic_arn]
  ok_actions    = [module.alerts.topic_arn]
}
```

Leave `ok_actions` out if you want a notification only when the alarm fires. Composite
alarms take the same `alarm_actions` and `ok_actions`.

## Check that a notification arrives

1. Force the alarm into the `ALARM` state. CloudWatch sets it back at the next
   evaluation.

   ```bash
   aws cloudwatch set-alarm-state --alarm-name orders-queue-backlog \
     --state-value ALARM --state-reason "Testing the alert route"
   ```

2. Check the alarm's history for the action:

   ```bash
   aws cloudwatch describe-alarm-history --alarm-name orders-queue-backlog \
     --history-item-type Action --max-records 1 \
     --query 'AlarmHistoryItems[].HistorySummary' --output text
   ```

   `Successfully executed action arn:aws:sns:...` means the topic accepted the
   notification. `Failed to execute action` with a KMS error means the key policy does
   not let CloudWatch use the key; see the next section.

3. Check that each subscriber received it.

## If you brought your own key

With `create_kms_key = false`, the key policy is yours. Add the CloudWatch statement
from [How to bring your own KMS key](bring-your-own-kms-key.md), or every alarm
action fails.

## Alarms in another account or Region

Not supported: the topic accepts alarms only from its own account, and an alarm can
notify only a topic in its own Region. Call the module once per account and Region.
