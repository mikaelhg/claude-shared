# H<n>: <the hypothesis, in one sentence>

<!--
Template for experiments/<topic>/h<n>-<slug>.md. Delete every comment when done.
Parts 1 to 3: the designer writes them before any test runs.
Part 4: the executor fills it in while running.
Part 5: the reviewer writes it after reading part 4.
This file must be safe to publish.
-->

**Status:** <planned | running | stopped | confirmed | refuted | inconclusive>

## 1. Hypothesis

- **Expected:** <prediction>
- **Refuted if:** <the observation that would show the prediction is wrong>
- **Control:** <the case whose outcome must differ, showing the test can fail>

## 2. Conditions

<!-- The designer lists the items; the executor fills in the observed values. -->

| Item | Value |
|---|---|
| Date | <YYYY-MM-DD> |
| OS and kernel release | <output of `uname -sr`> |
| <tool> | <version> |
| Environment | <sandbox, configuration under test> |

## 3. Plan

<!--
Fully specified: the executor should need no judgement about what to test.
Each step gives the exact command or the script to write, where the output is saved, and the observation expected under the hypothesis.
Include the control as a step.
-->

| Step | Command or script | Output saved to | Expected observation |
|---|---|---|---|
| 1 | `<command>` | `logs/<file>` | <observation> |

## 4. Actions and results

<!--
One entry per plan step, in the order run.
Quote only the output that bears on the result; the rest goes in logs/. Say so if output is redacted.
-->

### Step 1

```bash
<exact command as run>
```

Exit status: <n>

```
<output that bears on the result>
```

Matches the expected observation: <yes | no>

### Deviations and surprises

<!-- Anything that failed, could not be followed, or differed from the plan. Describe what happened; do not interpret it. Write "None" if none. -->

## 5. Verdict

<Confirmed, refuted or inconclusive, and the reason. Name the findings in the topic README that rest on this document.>
