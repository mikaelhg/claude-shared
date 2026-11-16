---
name: "experiments"
description: "Protocol for verifying by experiment how an API, a tool, an OS mechanism or similar actually behaves, and recording the findings so later sessions can look them up instead of re-testing. Records are kept in each repo and written to be safe to publish. Covers test design, a light and a full form, folder layout, findings index, citing findings, a lessons file for obstacles that recur across experiments, and which model does which step. Includes templates and a privacy check script. Use only when the user or the project's CLAUDE.md asks for it, not for ordinary quick checks."
---

# Experiments

An experiment here answers a factual question about something we do not control: how an API, a tool, an OS mechanism, a file format or a protocol actually behaves. It has two products:

- **A verified answer**, obtained by observation and not from recall or documentation.
- **A record** that lets a later reader find the answer, judge whether it still applies, and rerun the test, without repeating the work.

Follow this protocol only when the user asks for a documented experiment, or the project's CLAUDE.md directs you to this skill. Do not apply it to ordinary verification: a quick check, a one-off script, a test run or a docs lookup needs no folder and no documents.

## Files in this skill

These are in the skill's own folder, next to this file. Copy the templates; do not rewrite them from memory.

| File | Use |
|---|---|
| `templates/index.md` | Start `experiments/README.md` in a repository that has none. |
| `templates/lessons.md` | Start `experiments/LESSONS.md` in a repository that has none. |
| `templates/topic-readme.md` | Start `experiments/<topic>/README.md`. |
| `templates/hypothesis.md` | Start each hypothesis document. |
| `templates/subagent-brief.md` | Brief an executor subagent. |
| `tools/privacy-check.py` | Search the records for private detail before every commit. |

## Before you start

1. Read `experiments/README.md`, the index of earlier findings. If the question is already answered for the versions and environment in use, cite that finding and stop. Read `experiments/LESSONS.md` too; it lists the obstacles earlier experiments ran into.
2. If an earlier finding covers the question but for a different version or environment, rerun its scripts and update the existing record. Do not start a new topic.
3. Otherwise, write down the question and the decision that depends on it. A question nobody's decision depends on does not need an experiment.
4. Choose the form.

## Two forms

Choose the smaller form that fits. The rules for test design, public records, the index and citing apply to both.

| | Light | Full |
|---|---|---|
| Use when | One hypothesis, a plan of a few commands, and no exploration expected. | Several hypotheses, or a plan that needs scripts, iteration or exploration. |
| Documents | The topic README only. Hypothesis, conditions, commands, output and verdict go in its "Evidence" section. | The topic README, plus one hypothesis document per major hypothesis. |
| Who runs it | The main session. Starting a subagent would cost more than the test. | Subagents, as "Delegation" describes. |
| Folders | `scripts/`, `data/` and `logs/` only if there is something to put in them. | All three. |

Grow a light experiment into a full one as soon as a second hypothesis appears or the plan needs iterating: move the "Evidence" section into `h1-<slug>.md` and continue there. Finding numbers do not change.

## Designing the test

- **State the hypothesis first.** Write the prediction, and the observation that would refute it, before running anything. A result interpreted only afterwards proves little.
- **Test the real thing.** Use the same version, platform and environment that the decision concerns: the same sandbox, the same user, the same configuration. A result from a different environment is a lead, not a finding.
- **Isolate.** Use the smallest setup that shows the behaviour, with unrelated configuration disabled or pinned, so the result has one explanation.
- **Show that the test can fail.** Include a control whose outcome differs: a negative case, a tampered input, the mechanism switched off. A test that cannot fail verifies nothing.
- **Separate the environment from the substance.** A test can fail for reasons that have nothing to do with the question: a host is down, the sandbox blocks a call, a service turns automated requests away. Such a failure is not evidence either way. Record the result as inconclusive, never as refuted, and record the obstacle as a lesson.
- **Observe, do not infer.** Evidence is the exact command and its output, exit status or resulting state. Documentation, source code and recall tell you what to test; they are not evidence. If you rely on them anyway, say so and mark the claim as not verified.
- **Record the conditions.** Tool and library versions, OS and kernel release, the relevant configuration and the date, within the limits of "Records may be public" below. A finding is only known to hold under the conditions it was observed in.

## Records may be public

The records live in the repository the experiment is for, under `experiments/` at its root, and are committed with it. Assume that repository is or will become public. The records must describe the thing under test, not the person or the machine that ran the test.

Record only what bears on the result. Tool versions, the OS and kernel release, and the configuration under test belong in the record. These do not:

- Identity: the user's real name, account name, email addresses, and the hostname.
- Location on disk: home directory and other absolute paths, and the names of other projects or directories on the machine.
- Secrets and real keys: tokens, passwords, private keys, and also the fingerprints and public parts of the user's real keys.
- Network and hardware identifiers: IP and MAC addresses, network names, serial numbers, machine IDs.
- Machine inventory: environment dumps, process lists, installed-package lists, shell history, and the user's personal configuration files.

To keep them out:

- **Run in a neutral place.** Work in a scratch directory and refer to paths relative to the experiment folder, or through `$HOME` and `$PWD`. Scripts contain no absolute paths.
- **Use throwaway inputs.** Generate test keys and credentials for the experiment, label them as such, and use placeholder identities such as `Test User <test@example.invalid>`. Never feed the user's real credentials, keys or data into an experiment.
- **Isolate from personal configuration.** Point the tool at an empty or generated configuration instead of the user's own. This also serves the isolation rule above.
- **Capture narrowly.** Run the command that shows the one fact, not one that dumps everything: `uname -sr`, not `uname -a`; one variable, not `env`.
- **Redact before saving.** Raw output is where private detail leaks, and `logs/` holds the most of it. Replace private values with placeholders such as `<user>`, `<home>` and `<host>` before writing the file, and say in the document that the output is redacted. Do not save unredacted output anywhere in the repository, even temporarily.

If a finding depends on a private detail, describe that detail generically ("a key with a passphrase", "a home directory on a separate filesystem"). If the result cannot be stated without revealing it, stop and ask the owner.

### The privacy check

Run the check from the repository root when the experiment is finished, and again before every commit that includes experiment files:

    python3 <skill folder>/tools/privacy-check.py experiments

It reads the account name, real name, home directory, hostname and git identity from the machine and searches every file and file name for them.

- **`FOUND`** lines are those values. Fix every one and run the check again. It exits with status 1 while any remain.
- **`REVIEW`** lines have the shape of something private: an email address, an IP or MAC address, a home directory path, a private key block. Read each one and decide. A generated test key is expected here; a real address is not.

The check's output quotes the private values, so never save it in the repository. The check finds only what it knows to look for. It is a backstop for the rules above, not a replacement for them.

A commit is permanent in a public history: correcting the file later does not remove the value. If a private value has already been committed, tell the owner; rewriting history is their decision.

## Layout

All paths are relative to the root of the repository the experiment is for. Each repository keeps its own records; do not write them to a shared or user-level location.

    experiments/
      README.md            # index: every topic, its question and its answer
      LESSONS.md           # obstacles and techniques that apply across topics
      <topic>/
        README.md          # findings first, then how they were reached
        h1-<slug>.md       # full form: one document per major hypothesis
        h2-<slug>.md
        scripts/           # everything needed to rerun
        data/              # inputs and results needed to replicate
        logs/              # raw output, dead ends, incidental detail

Name a topic after its subject, not the task that prompted it: `git-gpg-program-interface`, not `signing-fix`. Topic names are used in citations, so do not rename one. If a folder for the topic already exists, continue in it; do not start a second one.

## What goes where

The documents are layered so that a reader stops at the first one that answers their question. Each layer links to the next. The templates give the exact structure; this section says what each layer is for.

- **`experiments/README.md`, the index.** One row per topic with its question, its answer and what it was verified on, so a single read shows whether a question is already answered. Update the row whenever the topic's findings change.
- **`<topic>/README.md`, the findings.** Readable on its own, without implementation detail. It leads with a numbered table of findings, then says what was not verified, so that a reader does not conclude more than was shown. State each finding as what is true, not as what was done: "`git` treats exit 0 plus a `SIG_CREATED` status line as a successful signature", not "tested the wrapper". A refuted hypothesis is also a finding; state what happens instead.
- **Hypothesis document** (full form). The hypothesis and what would refute it, the conditions, the plan, the actions and results, and the verdict. It is updated as the work happens, not afterwards, and includes every detail that bears on the result. Surprises that are off the hypothesis but true and useful become findings of their own in the README.
- **`logs/`.** Detail that does not bear on the result: full raw output, environment noise, failed setup attempts. Link to it from the evidence where relevant.

## Citing findings

A design that rests on a finding cites it, so that when the finding is corrected, a search shows every decision that depended on it.

- **Form.** Write the citation as a link to the topic README, with the topic name and finding number as the link text: `[git-gpg-program-interface#F2](experiments/git-gpg-program-interface/README.md)`. Adjust the path to the citing document's location. In code comments, write `experiments/<topic>#F2`.
- **Where.** Cite at the statement that depends on the finding, in design documents, plans and code comments. Do not restate the finding's conditions there; the reader follows the link.
- **Stable numbers.** A finding keeps its number for good. Never renumber or reuse one. Mark a dropped finding "withdrawn" and keep its row.
- **Back-links.** List the citing documents under "Consequences" in the topic README.
- **Finding the dependents.** Search the repository for the topic name followed by `#F`:

      grep -rn '<topic>#F' .

## Reproducibility

Every finding must be reproducible from the experiment folder: from `scripts/` and `data/`, or in the light form from the commands under "How to rerun". Scripts take no input from outside the experiment folder other than the tools under test, and print the versions they ran against.

### Choosing a script language

Choose by what the script is, not only by its size.

- **Bash when the script is the commands under test.** The script is part of the evidence: a reader should see the exact invocation that produced the result and be able to paste it into a shell. Keep it a linear sequence of commands, starting with `set -euo pipefail`.
- **Python when the script reasons about results**: parsing output, comparing against expected values, looping over a matrix of cases, calling an API. Once a Bash script needs arrays, string parsing, functions or nested conditionals, write it in Python.

Three limits apply:

- **Standard library only by default.** A third-party dependency makes the experiment harder to rerun and adds versions to record. If one is needed, pin it in the experiment folder and record the Python version as a condition.
- **Keep Python out of the path to the mechanism.** `subprocess` changes inherited file descriptors, the environment, signal handling and quoting. When the thing under test is process-level or shell-level behaviour, run the command that exercises it directly from Bash, save the output, and use Python only to analyse it.
- **An artefact under test stays in its deployment language.** A wrapper that will ship as a shell script is tested as a shell script, whatever its size.

## Keeping findings current

A finding is tied to its conditions. When a tool is upgraded, or a design starts to depend on a finding in a new environment, rerun the scripts. Then update the "Holds for" column and the index row, or correct the finding.

When a finding changes:

1. Correct it in place and note the correction in "Path taken". Do not leave a contradicting newer record beside it.
2. Search for its citations, as "Citing findings" describes.
3. Report the change and the documents that cite it to the owner. Whether those designs change is the owner's decision.

## Lessons

`experiments/LESSONS.md` records what a session learned about the conditions for testing here, so that the next one does not rediscover it: the limits of the environment, how external services fail for unrelated reasons, and techniques that worked. Facts about the thing under test are findings, and go in a topic README.

- Add a lesson only if it will apply to another topic, and say what to do about it.
- Record lasting conditions, not incidents.
- A limit that someone chose is designed around or taken to the owner, never defeated.
- Keep the file to about a page. The main session maintains it.

A problem with this protocol itself goes to the owner, not into the repository.

## When to ask the owner

The owner is the person the experiment is for, normally the user of the main session. Ask when the answer is the owner's to give: intent, risk, privacy and spend. Never ask what an experiment could answer; finding that out is the work.

Ask in these cases:

| When | Ask if |
|---|---|
| Before designing | It is unclear whether the question warrants a record at all. Choosing between the light and the full form is not a question for the owner. |
| | The decision that depends on the question cannot be read from the repository or the conversation. The decision determines what counts as an answer. |
| | The target environment is unclear: which versions and platforms matter, this machine only or others too. |
| Before running | The test reaches outside the sandbox or has side effects: installing software, changing system settings, calling an external service, using a real account, or spending money. |
| | The real environment cannot be tested. Ask whether a stand-in is acceptable, or whether to record the claim as not verified. |
| | It is unclear whether a detail is private. Ask before recording it, not after. |
| While running | The work has outgrown the question: it needs many more hypotheses or subagents than first planned. |
| Afterwards | A result is inconclusive after a reasonable effort. Accepting the risk, investing more or changing the design is the owner's decision. |
| | A finding contradicts an accepted design or an earlier recorded finding. Report it at once; what to do about it is the owner's decision. |

Do not ask about:

- Layout, naming, form, script language or model choice. This skill settles them.
- Whether to record a negative result or a dead end. Always record it.
- Permission to move on to the next hypothesis.

How to ask:

- **Early and in one round.** Settle the questions before delegating the design. Subagents cannot reach the owner; they stop and report to the main session, which decides whether the owner needs to be asked.
- **Keep working** on whatever does not depend on the answer.
- **Record the answer** in the topic README, next to the question, so a later reader sees why the experiment was scoped as it was. The public-records rules apply to the answer too.

## Delegation

This section applies to the full form. A light experiment runs in the main session.

A full experiment has a few small steps that need judgement and one large step that is mechanical. Spend capable-model tokens on the first kind and cheap-model tokens on the second. The main session's tokens cost the most, so it designs and judges, and does not run the tests itself.

| Step | Who does it |
|---|---|
| Design: hypothesis, refutation condition, controls, plan | Main session |
| Execute a fully specified plan | Haiku subagent |
| Explore: the tool is unfamiliar, the plan needs iterating, or a result was unexpected | Sonnet subagent |
| Review the evidence, decide the verdict, write the findings | Main session |
| Privacy check | The script, no model |

If the main session itself runs on a smaller model, use an Opus subagent for the design and for reviewing the evidence. These steps are small, so the more capable model costs little there and a design error costs a great deal.

### Design before delegating

The main session writes parts 1 to 3 of each hypothesis document (hypothesis, conditions, plan) before starting any subagent. A plan is fully specified when it gives the exact commands or the script to write, where the output is saved, and the observation expected under the hypothesis. The executor should need no judgement about what to test.

### Choosing the subagent model

- **Haiku by default**, when the plan is fully specified. A failed Haiku run costs a small fraction of a Sonnet run, so trying Haiku first is nearly free.
- **Sonnet** when the plan cannot be fully specified in advance, or when a Haiku executor stopped and reported a problem. Give it the Haiku executor's record so it does not repeat the work. For exploration, add to the brief what the subagent may vary and what question it must answer.
- Give each subagent one to three related hypotheses. More than three mixes unrelated context; splitting related hypotheses across subagents pays the start-up cost repeatedly.

### Briefing a subagent

A subagent starts without this context and cannot read this skill. Fill in `templates/subagent-brief.md`, including the lessons that bear on its plan, and send it whole. It carries the rules for recording, scripts and public records, and two rules that matter most with a cheap executor:

- **Stop instead of improvising.** On a failure or an unexpected result, the subagent records what happened and reports back. It does not change the plan, reinterpret the hypothesis or decide the verdict. An unexpected result is often the most valuable one, and it needs a more capable reader.
- **Return a short report.** Raw output stays in the experiment folder, out of the main session's context.

### Accepting results

- The main session reads the recorded commands and the output that bears on each result, then writes the verdict. A subagent's report is a claim until the evidence in the hypothesis document supports it.
- Check that the control behaved as a control: if the test could not have failed, the result does not count, whichever model ran it.
- The main session then writes the topic README, updates the index, adds any lessons, and runs the privacy check.

If subagents are unavailable, do the same work in the main session and keep the same documents.
