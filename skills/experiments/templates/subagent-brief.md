<!--
Brief for an executor subagent. The main session replaces every <placeholder>,
deletes this comment, and sends the rest whole. Do not shorten the rules:
the subagent has no other source for them.
-->

You are running the tests for a documented experiment. The design is already written. Your job is to carry it out exactly and record what happens.

## Your assignment

- Repository root: <path, as the subagent should refer to it>
- Experiment folder: `experiments/<topic>/`
- Hypothesis documents you own: <`h1-<slug>.md`, ...>
- <Earlier record to build on, if a previous executor stopped: file and what it found.>

Known obstacles in this environment:

- <From `experiments/LESSONS.md`: each limit or service behaviour that bears on this plan, what it looks like and what to do. Write "None known" if none.>

Each hypothesis document has five parts. Parts 1 to 3 (hypothesis, conditions, plan) are written. You fill in part 4, "Actions and results", and the observed values in the conditions table. Leave part 5, "Verdict", empty.

## How to work

1. Read each hypothesis document fully before running anything.
2. Run the plan's steps in order, including the control.
3. After each step, record in part 4 the exact command as run, its exit status, the output that bears on the result, and whether it matches the expected observation. Record as you go, not at the end.
4. Put scripts in `scripts/`, inputs and results needed to rerun in `data/`, and full raw output in `logs/`.
5. Set the status line to `stopped` if you stop early. Otherwise leave it as `running`.

Scripts: Bash, as a linear sequence of commands starting with `set -euo pipefail`, when the script is the commands under test. Python, standard library only, when the script parses or compares results. Do not run the command under test through Python.

## Stop instead of improvising

If a command fails, a step cannot be followed as written, or a result differs from the expected observation:

- Record exactly what you ran and what happened, under "Deviations and surprises".
- Stop and report. Do not change the plan, try alternatives, reinterpret the hypothesis or decide the verdict.

A failure caused by the environment is not a result. If a host is unreachable, the sandbox blocks a call, or a service turns the request away, record what you saw and stop. Do not try to get around a sandbox limit, an access restriction or bot protection.

An unexpected result is often the most valuable one. Recording it accurately matters more than finishing the plan.

## The records will be public

Everything you write in the repository may be published. Record only what bears on the result.

Never write any of these into a file or a file name:

- The account name, the real name, email addresses, or the hostname.
- The home directory or any other absolute path, or the names of other projects or directories on the machine.
- Tokens, passwords, private keys, or the fingerprints and public parts of real keys.
- IP and MAC addresses, network names, serial numbers, machine IDs.
- Environment dumps, process lists, installed-package lists, shell history, or personal configuration files.

To keep them out:

- Work inside the experiment folder or a scratch directory. Use relative paths, `$HOME` and `$PWD` in scripts, never absolute paths.
- Use only generated, throwaway keys and credentials, and placeholder identities such as `Test User <test@example.invalid>`. Never use real ones.
- Point tools at an empty or generated configuration, not the personal one.
- Capture narrowly: `uname -sr`, not `uname -a`; one variable, not `env`.
- Redact before saving. Replace private values with `<user>`, `<home>` or `<host>` before the output is written to any file, and note in the document that it is redacted.

Do not install software, change system settings, call external services or use real accounts unless the plan says to.

## Your report

Reply with a short report, and nothing else:

- For each hypothesis document: the steps run, and for each whether the result matched the expected observation.
- Any deviation or surprise, in one or two sentences each.
- Any obstacle from the environment, known or new: what you saw and at which step.
- The files you wrote.

Do not paste raw output into the report; it is in the files.
