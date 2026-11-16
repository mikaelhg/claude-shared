---
name: "experiments"
description: "Protocol for verifying by experiment how an API, a tool, an OS mechanism or similar actually behaves, and recording the findings in the repository so later sessions can look them up instead of re-testing. Records are written to be safe to publish. Includes templates and a privacy check script. Use only when the user or the project's CLAUDE.md asks for it, not for ordinary quick checks."
---

# Experiments

An experiment answers a factual question about something we do not control: how an API, a tool, an OS mechanism, a file format or a protocol actually behaves. It produces a verified answer, obtained by observation and not from recall or documentation, and a record that lets a later reader find the answer, judge whether it still applies, and rerun the test.

Follow this protocol only when the user asks for a documented experiment, or the project's CLAUDE.md directs you to this skill. An ordinary quick check needs no record.

The skill's own folder holds a template for every document, in `templates/`, and `tools/privacy-check.py`. Copy the templates; they define each document's structure.

## Before you start

1. Read `experiments/README.md`, the index of findings, and `experiments/LESSONS.md`. If the question is already answered for the versions and environment in use, cite the finding and stop. If it is answered for other conditions, rerun that topic's scripts and update its record.
2. Write down the question and the decision that depends on it. A question nobody's decision depends on does not need an experiment.
3. Choose the form:
   - **Light:** one hypothesis and a plan of a few commands. The topic README is the only document, and the main session runs the test.
   - **Full:** several hypotheses, or a plan that needs scripts or exploration. Each hypothesis gets its own document, and subagents run the tests.

   Move a light experiment to the full form when it outgrows the light one.

## Designing the test

- **State the hypothesis first**, with the observation that would refute it. A result interpreted only afterwards proves little.
- **Test the real thing**: the version, platform and environment the decision concerns. A result from elsewhere is a lead, not a finding.
- **Isolate.** Use the smallest setup that shows the behaviour, so that the result has one explanation.
- **Show that the test can fail.** Include a control whose outcome differs.
- **Separate the environment from the substance.** A failure caused by a dead host or a sandbox limit is inconclusive, never a refutation.
- **Observe, do not infer.** Evidence is the exact command and what it produced. Documentation and recall say what to test; a claim that rests on them is marked as not verified.
- **Record the conditions**: versions, OS release, relevant configuration and date. A finding is known to hold only under them.

## Records may be public

The records are committed to the repository the experiment is for. Assume it is or will become public. Describe the thing under test, never the person or machine that ran the test: no names, account or host names, absolute paths, addresses, hardware identifiers, real keys or secrets, and no dumps of the environment.

Prevent private detail from entering, instead of removing it afterwards:

- Use generated, throwaway keys and placeholder identities such as `Test User <test@example.invalid>`.
- Point tools at an empty configuration, not the personal one, and use relative paths.
- Capture only the fact you need: `uname -sr`, not `uname -a`.
- Redact output before it is written to any file.

Before every commit that includes experiment files, run the check from the repository root:

    python3 <skill folder>/tools/privacy-check.py experiments

Fix every `FOUND` line. Read each `REVIEW` line and decide. The output quotes the private values, so never save it. A committed value stays in the history; if one got in, tell the owner.

## Layout

Each repository keeps its own records, under `experiments/` at its root:

    experiments/
      README.md            # index: every topic, its question and its answer
      LESSONS.md           # obstacles and techniques that apply across topics
      <topic>/
        README.md          # findings first, then how they were reached
        h1-<slug>.md       # full form: one document per hypothesis
        scripts/           # everything needed to rerun
        data/              # inputs and results needed to replicate
        logs/              # raw output and incidental detail

Name a topic after its subject, not the task that prompted it, and do not rename it. Continue in an existing topic folder; do not start a second one.

The documents are layered so that a reader stops at the first one that answers the question: the index, then the topic README, then the hypothesis documents, then the logs. The topic README must be readable on its own. State each finding as what is true, not as what was done, and say what was not verified. A refuted hypothesis is also a finding.

## Citing findings

A design that rests on a finding cites it, so that a search finds every dependent when the finding changes. Write `[<topic>#F2](path/to/experiments/<topic>/README.md)` in documents and `experiments/<topic>#F2` in code comments. Finding numbers are permanent: never renumber or reuse one. Find the dependents with:

    grep -rn '<topic>#F' .

## Reproducibility

Every finding must be reproducible from the experiment folder alone. Scripts print the versions they ran against.

Write a script in Bash when it is the commands under test, so that a reader sees the exact invocation. Write it in Python, standard library only, when it reasons about results. Run the command under test directly, never through Python, and test an artefact in the language it will ship in.

## Keeping findings current

When a tool is upgraded, or a design starts to rely on a finding under new conditions, rerun the scripts and update the record. Correct a wrong finding in place, then tell the owner which documents cite it.

## Lessons

`experiments/LESSONS.md` records what a session learned about the conditions for testing here, so that the next one does not rediscover it: the limits of the environment, how external services fail for unrelated reasons, and techniques that worked. Facts about the thing under test are findings, and go in a topic README.

- Add a lesson only if it will apply to another topic, and say what to do about it.
- Record lasting conditions, not incidents.
- A limit that someone chose is designed around or taken to the owner, never defeated.
- Keep the file to about a page. The main session maintains it.

A problem with this protocol itself goes to the owner, not into the repository.

## When to ask the owner

The owner is the person the experiment is for. Ask what only the owner can answer: intent, risk, privacy and spend. Never ask what an experiment could answer, what this skill already settles, or for permission to continue.

Ask when:

- The decision behind the question, or the environment it concerns, is unclear.
- A test would have effects outside the sandbox or cost money.
- The real environment cannot be tested, or it is unclear whether a detail is private.
- The work has outgrown the question.
- A result stays inconclusive, or contradicts an accepted design.

Ask early and in one round, because subagents cannot reach the owner. Keep working on whatever does not depend on the answer, and record the answer in the topic README.

## Delegation

In the full form, the main session designs and judges, and subagents run the tests. Judgement needs a capable model and little text; execution needs a cheap model and a lot of it.

| Step | Who does it |
|---|---|
| Design: hypothesis, refutation condition, control, plan | Main session |
| Execute a fully specified plan | Haiku subagent |
| Explore, or take over where an executor stopped | Sonnet subagent |
| Review the evidence, decide the verdict, write the findings | Main session |

- **Design first.** Write the hypothesis, conditions and plan into each hypothesis document before starting a subagent. A plan is fully specified when the executor needs no judgement about what to test.
- **Brief with the template.** A subagent cannot read this skill. Fill in `templates/subagent-brief.md` and send it whole, with one to three related hypotheses.
- **Executors stop instead of improvising.** On a failure or a surprise they record what happened and report back. An unexpected result needs a more capable reader.
- **Reports are claims.** Read the recorded evidence before writing a verdict, and check that the control could have failed.

If the main session runs on a smaller model, give the design and the review to an Opus subagent. If subagents are unavailable, do the same work in the main session and keep the same documents.
