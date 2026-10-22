# terraform-aws-sns-alert-topic

A Terraform module for one SNS topic for operational alerts. CloudWatch alarms in
the same account can publish to it, and so can EventBridge rules if you allow them.
It is encrypted by default with a customer managed KMS key whose policy lets those
services use it, and it carries your email, https, SQS, Lambda and other
subscriptions.

Use it when alarms need somewhere encrypted to send alerts. CloudWatch alarms cannot
publish to a topic encrypted with the AWS managed key `alias/aws/sns`, so alert
topics are often left unencrypted; this module makes the encrypted path the default.
You do not need to know anything about the project it came from.

It deliberately does **not** manage:

- **What publishes to the topic.** Alarms and EventBridge rules belong next to the
  module call; point them at the `topic_arn` output.
- **What subscribers need.** An SQS queue policy, a Lambda permission or a Firehose
  delivery role belongs to the subscriber.
- **FIFO topics, cross-account publishers, message filtering and chat integrations.**
  See [design decisions](docs/explanation/design-decisions.md) for why.
- **Provider configuration and state.** There is no `provider` or `backend` block.

## Usage

```hcl
module "alerts" {
  source = "git::https://github.com/EG2development/terraform-aws-sns-alert-topic.git?ref=v2.0.0" # x-release-please-version

  name = "payments-prod-alerts"

  subscriptions = {
    oncall = { protocol = "email", endpoint = var.oncall_email }
  }
}
```

Pin `?ref=`
to a release tag (inside the organisation) or the release's full commit SHA (outside
it), never to a branch. Run `terraform init` after changing `source`.

## Examples

| Example | Shows |
| --- | --- |
| [`examples/basic`](examples/basic) | A topic encrypted with the module's key and one email subscription whose address is a sensitive variable |
| [`examples/complete`](examples/complete) | EventBridge allowed to publish, an SQS archive queue and an https incident-tool subscription, plus a CloudWatch alarm and an EventBridge rule wired to the topic |

## Documentation

| You want to | Read |
| --- | --- |
| Create your first alert topic with this module | [Tutorial: create your first alert topic](docs/tutorials/create-your-first-alert-topic.md) |
| Send CloudWatch alarm notifications to the topic | [How to route CloudWatch alarms to the topic](docs/how-to/route-cloudwatch-alarms.md) |
| Let EventBridge rules publish to the topic | [How to let EventBridge publish](docs/how-to/let-eventbridge-publish.md) |
| Encrypt the topic with a key you already have | [How to bring your own KMS key](docs/how-to/bring-your-own-kms-key.md) |
| Look up every resource, policy statement and permission | [Reference: resources, policies and permissions](docs/reference/resources-policies-and-permissions.md) |
| See the resources and how they connect, on one page | [Architecture diagram](docs/reference/architecture.png) |
| Understand why it is built this way | [Design decisions](docs/explanation/design-decisions.md) |

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.16.0 |
| aws | >= 6.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 6.0 |

## Resources

| Name | Type |
|------|------|
| [aws_kms_alias.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_sns_topic.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |
| [aws_sns_topic_subscription.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Name of the SNS topic, for example "payments-prod-alerts". It also names the module's KMS key alias, "alias/{name}-sns". Changing it replaces the topic and its subscriptions, and email recipients must confirm again. | `string` | n/a | yes |
| allow\_eventbridge\_publish | Let EventBridge rules in this account publish to the topic. Adds a topic policy, which replaces SNS's default policy and restates the access of this account and its CloudWatch alarms, and an events.amazonaws.com statement in the module's key policy. Off by default. | `bool` | `false` | no |
| create\_kms\_key | Create a customer managed KMS key for the topic, with a key policy that lets CloudWatch alarms (and EventBridge, with allow\_eventbridge\_publish) publish. On by default. Set it to false to use your own key in kms\_master\_key\_id; false with no kms\_master\_key\_id leaves the topic unencrypted. | `bool` | `true` | no |
| kms\_key\_deletion\_window\_in\_days | Days KMS waits before deleting the module's key once it is scheduled for deletion, for example by terraform destroy. The key can be restored during the wait. 7-30, default 30. | `number` | `30` | no |
| kms\_master\_key\_id | Your own KMS key for the topic, used only when create\_kms\_key is false: a key ID, key ARN, alias name or alias ARN. Its key policy must let cloudwatch.amazonaws.com use kms:Decrypt and kms:GenerateDataKey*. The AWS managed key alias/aws/sns is rejected: CloudWatch alarms cannot publish to a topic encrypted with it. Null (default). | `string` | `null` | no |
| subscriptions | Subscriptions to create, keyed by a static label you choose, for example { oncall = { protocol = "email", endpoint = var.oncall\_email } }. protocol is email, email-json, https, sqs, lambda, firehose, sms or application; plain http is rejected. firehose also needs subscription\_role\_arn. Email subscriptions stay pending until the recipient confirms. Endpoints appear in plan output unless you pass sensitive values. Keys always appear in plan output and resource addresses: never put a secret in a key. | <pre>map(object({<br/>    protocol              = string<br/>    endpoint              = string<br/>    subscription_role_arn = optional(string)<br/>  }))</pre> | `{}` | no |
| tags | Tags for the topic and the KMS key. The module adds a Name tag to each; a Name key here overrides it, so it is rarely what you want. Tags from the provider's default\_tags apply as usual. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| kms\_key\_arn | Key that encrypts the topic: the ARN of the module's key, or kms\_master\_key\_id exactly as given when you brought your own. Null when the topic is not encrypted. Grant publishers kms:GenerateDataKey* and kms:Decrypt on it. |
| subscription\_arns | ARN of each subscription, keyed by the labels in subscriptions. |
| topic\_arn | ARN of the topic, for alarm\_actions and ok\_actions on CloudWatch alarms, EventBridge rule targets and IAM policies. |
| topic\_name | Name of the topic. |
<!-- END_TF_DOCS -->

## Defaults and security decisions

| Decision | Default | Why | How to change it |
| --- | --- | --- | --- |
| Encryption | A customer managed key the module creates: rotated yearly, 30-day deletion window | Alerts are encrypted at rest, and CloudWatch can still publish | `create_kms_key`, `kms_master_key_id`, `kms_key_deletion_window_in_days` |
| Who may use the key | The account, through IAM policies; CloudWatch acting for this account; EventBridge only when allowed | Each publisher gets `kms:Decrypt` and `kms:GenerateDataKey*`, nothing more | `allow_eventbridge_publish` |
| AWS managed key `alias/aws/sns` | Rejected | Alarm notifications would fail | Not configurable |
| Topic policy | None: SNS's default policy applies | Nothing to restate unless EventBridge needs a statement | `allow_eventbridge_publish` |
| Publishers | CloudWatch alarms and IAM principals in this account; EventBridge rules in this account when allowed | Confused-deputy protection on every service statement | Not configurable |
| Subscription protocols | `email`, `email-json`, `https`, `sqs`, `lambda`, `firehose`, `sms`, `application`; plain `http` rejected | `http` would send alert content unencrypted | Not configurable |
| Subscription endpoints | Shown in plan output | Terraform shows what it plans | Pass sensitive values; keys always show |

## Security scanning

Checkov runs on every pull request via
[Static Analysis](.github/workflows/workflow.yml). No AWS check is skipped in
[`configs/checkov.yml`](configs/checkov.yml). `CKV_AWS_26` (SNS topic encrypted) passes
with the defaults.

The key policy uses `Resource = "*"`, which in a key policy means the key itself. It is
written inline with `jsonencode`, so Checkov's IAM wildcard-resource checks
(`CKV_AWS_109`, `CKV_AWS_111`, `CKV_AWS_356`) do not apply to it, and nothing needs a
skip. A caller that sets `create_kms_key = false` without `kms_master_key_id` creates
an unencrypted topic, and its own scan should report `CKV_AWS_26`.

## Upgrading

Read [`CHANGELOG.md`](CHANGELOG.md) for every version between yours and the new one,
change `?ref=`, run `terraform init`, and review the plan. A minor or patch release
plans no changes unless you opt into something new. Changing `name` replaces the topic
and its subscriptions, and email recipients must confirm again. Turning encryption on
for an existing topic updates it in place; publishers other than CloudWatch and
EventBridge then need `kms:GenerateDataKey*` and `kms:Decrypt` on the key.

## Versioning and releases

Semantic versions, tags `vMAJOR.MINOR.PATCH`, created by release-please from
Conventional Commit pull-request titles. Patch: a fix that changes no plan. Minor: a
new optional input, output or off-by-default resource. Major: anything that can
change or replace an existing caller's resources, or raise a minimum version.
For the contribution and release checks, see [`CONTRIBUTING.md`](CONTRIBUTING.md)
and [the release workflow](.github/workflows/release-please.yml).

## Contributing and ownership

See [`CONTRIBUTING.md`](CONTRIBUTING.md). The team in
[`.github/CODEOWNERS`](.github/CODEOWNERS) reviews every change and owns releases.
Report vulnerabilities as described in [`SECURITY.md`](SECURITY.md).
