# <Subject under test>

<!--
Template for experiments/<topic>/README.md. Delete every comment when done.
Light form: keep the "Evidence" section at the end.
Full form: delete "Evidence"; the evidence is in the hypothesis documents.
This file must be readable on its own and safe to publish.
-->

## Question

<The question, in one sentence.>

**Decision that depends on it:** <what will be built or chosen differently depending on the answer>

<!-- If the owner answered scoping questions, record the answers here. -->

## Findings

<!--
One row per fact, stated as what is true, not as what was done.
A refuted hypothesis is also a finding: state what happens instead.
Numbers are permanent. Never renumber or reuse one; mark a dropped finding "withdrawn" and keep its row.
Evidence: a link to the hypothesis document (full form) or to "Evidence" below (light form).
-->

| # | Finding | Holds for | Evidence |
|---|---|---|---|
| F1 | <A statement of fact, specific enough to act on.> | <Versions, platform, environment.> | <link> |

## Not verified

<!-- What was assumed, left out, or could not be settled. Write "Nothing" only if that is true. -->

- <claim, and why it is not verified>

## Consequences

<What the findings mean for the decision.>

Documents that cite these findings:

- <link to the design document or code, and which findings it cites>

## Path taken

<!-- In order, including abandoned branches and corrections to earlier findings. Full form: link each hypothesis document. -->

1. <step>

## How to rerun

<!-- The commands, run from this folder, and what to compare the output against. -->

```bash
<command>
```

Expected: <observation>

## Evidence

<!-- Light form only. -->

### Hypothesis

<!-- Written before running anything. -->

- **Expected:** <prediction>
- **Refuted if:** <the observation that would show the prediction is wrong>
- **Control:** <the case whose outcome must differ, showing the test can fail>

### Conditions

| Item | Value |
|---|---|
| Date | <YYYY-MM-DD> |
| OS and kernel release | <output of `uname -sr`> |
| <tool> | <version> |
| Environment | <sandbox, configuration under test> |

### Commands and output

<!-- Each exact command, its exit status, and the output that bears on the result. Say so if output is redacted. -->

```bash
<command>
```

```
<output>
```

### Verdict

<Confirmed, refuted or inconclusive, and the reason.>
