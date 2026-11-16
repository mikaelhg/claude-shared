# Lessons

<!--
Template for experiments/LESSONS.md. Delete every comment and every example row when done.
This file records obstacles and techniques that apply across experiments in this repository.
It does not record findings about the thing under test; those go in the topic README.
Keep it to about a page: merge duplicates and delete entries that no longer hold whenever you edit it.
This file must be safe to publish.
-->

What a session should know before running an experiment in this repository: the limits of the environment, the behaviour of services the experiments depend on, and techniques that worked. Read it together with the [index](README.md).

Each entry was observed, not verified by experiment. The source says where it came up, so that a reader can judge it.

## Environment limits

<!--
Limits of the sandbox, the machine or the toolchain that an experiment cannot change.
"Deliberate" means someone chose the limit. Never work around a deliberate limit; if an experiment needs what it blocks, ask the owner.
-->

| Limit | What you see | Deliberate | What to do | Source, last confirmed |
|---|---|---|---|---|
| <The sandbox does not allow Unix sockets.> | <`connect: Operation not permitted`> | <Yes> | <Design tests that need no socket, or ask the owner to run the step.> | <[topic](topic/README.md), YYYY-MM-DD> |

## External services

<!--
Services an experiment reaches over the network, and how they fail for reasons unrelated to the experiment.
Name public services. Describe private or internal hosts generically.
-->

| Service | What you see | What it means | What to do | Source, last confirmed |
|---|---|---|---|---|
| <host> | <Timeouts or HTTP 5xx, intermittently.> | <The host is down. This says nothing about the question.> | <Retry later. Record the result as inconclusive, never as refuted.> | <[topic](topic/README.md), YYYY-MM-DD> |
| <host> | <HTTP 403 with a challenge page for automated requests.> | <The host is behind bot protection.> | <Do not try to get past it. Use the documented API, or ask the owner to fetch the page.> | <[topic](topic/README.md), YYYY-MM-DD> |

## Techniques

<!-- Ways of setting up, isolating or running tests that worked here and will apply to other topics. -->

| Lesson | Source, date |
|---|---|
| <Run `<tool>` with `<flag>` to keep it away from the personal configuration.> | <[topic](topic/README.md), YYYY-MM-DD> |
