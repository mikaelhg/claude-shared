# Lessons

What a session should know before running an experiment in this repository. Read it together with the [index](README.md).

Each entry was observed, not verified by experiment. The source says where it came up.

## Environment limits

| Limit | What you see | Deliberate | What to do | Source, last confirmed |
|---|---|---|---|---|
| The session sets `GIT_CONFIG_*` variables for every command. | Git behaves as if extra configuration were present, even with the global and system files switched off. | Yes | Run git under test with `env -i` and an empty `HOME`, not only with `GIT_CONFIG_GLOBAL=/dev/null`. | [skill-tightening-ab](skill-tightening-ab/README.md), 2026-11-16 |
| The sandbox does not allow new namespaces. | `unshare: Operation not permitted` | Yes | Do not test behaviour that depends on the host name or other namespaced state here; record it as not verified. | [skill-tightening-ab](skill-tightening-ab/README.md), 2026-11-16 |

## Techniques

| Lesson | Source, date |
|---|---|
| Model sessions can be test subjects: give each its own folder and a neutral folder name, fix the rubric first, and include a subject without the thing under test as the control. | [skill-tightening-ab](skill-tightening-ab/README.md), 2026-11-16 |
