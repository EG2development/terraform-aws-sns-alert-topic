# Design decisions

Why the module is shaped the way it is, and what it leaves out on purpose.

## One topic for one account's alerts

An alert topic is where an account's alarms and rules converge before they reach
people and tools. The module creates the topic, the key that encrypts it and the
subscriptions, and stops. The alarms and rules that publish belong to the services
they watch, so they live next to the module call and use `topic_arn`.

## A customer managed key by default

Alerts carry resource names, metric values and error text. Encryption at rest costs
one KMS key a month plus its requests, which SNS keeps low by reusing each data key
for up to five minutes. So the module encrypts unless told not to.
The key rotates yearly, and a 30-day deletion window leaves time to notice a mistaken
destroy.

## Why not `alias/aws/sns`

The AWS managed key for SNS is the obvious choice, and the wrong one for alerts. Its
key policy lets only principals in the account use it through SNS, and nobody can
change that policy. CloudWatch publishes alarm notifications as the service principal
`cloudwatch.amazonaws.com`, which that policy does not admit. An alarm pointed at such
a topic fails each time it fires, and the failure shows only in the alarm's history.
Teams that discover this usually remove encryption. The module rejects the alias
instead, and creates a key whose policy it controls.

## Who may use the key, and on whose behalf

The key policy names exactly the publishers the module supports. CloudWatch gets
`kms:Decrypt` and `kms:GenerateDataKey*`, the two actions SNS needs from a publisher,
and only when acting for the topic's account (`aws:SourceAccount`). That condition is
the confused-deputy protection: another account's alarm cannot make CloudWatch use
this key.

EventBridge gets the same two actions without a condition, because AWS does not
support source conditions in a key policy for EventBridge publishing to an encrypted
topic, and events are dropped when one is present. The protection then comes from the
topic policy, which admits only rules in the topic's account. EventBridge uses the
key only while publishing to a topic encrypted with it, and the module encrypts only
this topic with it.

## No topic policy unless EventBridge needs one

SNS gives every topic a default policy that lets the owning account manage the topic
and lets AWS services acting for that account publish. CloudWatch alarms work with it.
A topic policy replaces the default rather than adding to it, so any policy the module
wrote would have to restate it and would own the topic's policy for good. The module
writes one only when EventBridge needs a statement, and then restates what the default
gave the account and CloudWatch. Existing callers, who have no topic policy, keep
having none.

## Plain http is rejected

An `http` subscription sends every alert across the internet in clear text, to an
endpoint that nothing authenticates. Alert content is exactly what an attacker
mapping an estate wants. `https` costs nothing extra, so `http` is not offered.

## Subscriptions are a map of labels

Subscriptions are keyed by labels the caller chooses, so adding or removing one never
moves another, and the address `aws_sns_topic_subscription.main["oncall"]` says what it
is. Endpoints are often sensitive, and a caller often decides whether a subscription
exists from a sensitive value, which makes the whole map sensitive. Terraform refuses
`for_each` over a sensitive value, so the module iterates over the keys alone and
treats them as not secret. The endpoints keep their sensitivity.

## Names and addresses are stable

Resource names inside the module are fixed (`main`), the topic is named exactly
`var.name`, and the alias follows `alias/<name>-sns`. A caller whose topic has a name,
tags and email subscription and nothing else can adopt the module with
`create_kms_key = false` and a few `moved` blocks, and see no change in the plan. The
[reference](../reference/resources-policies-and-permissions.md) is the contract:
changing any of those names is a breaking change.

## Left out on purpose

| Not included | Why |
| --- | --- |
| FIFO topics | Alerts need no ordering or deduplication, and FIFO topics cannot deliver to email, SMS or https |
| Delivery policies | The defaults retry https deliveries; tuning them belongs to the endpoint's owner |
| Message filtering | An alert topic delivers everything to everyone; route with separate topics, or filter in the subscriber |
| Data protection policies | Alerts should not carry personal data in the first place; a data protection policy would hide that, not fix it |
| Cross-account publishers | They need a wider topic policy and key policy, and every extra account weakens the confused-deputy protection; call the module in each account |
| Chatbot and Slack integration | Amazon Q Developer in chat applications subscribes to a topic through its own configuration; create it next to the module with `topic_arn` |
| Extra topic-policy statements | The module owns the topic policy when it writes one; a second writer would overwrite it |
| Subscription options such as raw delivery and redrive | Alert subscribers need none of them; add a subscription next to the module if one does |
