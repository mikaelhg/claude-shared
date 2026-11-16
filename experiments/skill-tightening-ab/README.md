# Effect of tightening the experiments skill

## Question

Does a session follow the tightened `SKILL.md` (126 lines, commit `78c97bd`) as well as the un-tightened one (240 lines, commit `7ad0fde`)?

**Decision that depends on it:** whether to keep the tightened version, or restore detail that the tightening removed.

## Findings

| # | Finding | Holds for | Evidence |
|---|---|---|---|
| F1 | Subjects given the tightened skill passed every rubric item in all three runs, and so did subjects given the un-tightened skill. No item separates the two versions. | Opus subagents; one light-form task about `git commit`; three runs per version; 2026-11-16. | [Evidence](#evidence) |
| F2 | A subject with no skill failed five of the eleven items: it left the account name, host name and real name in its records, and wrote no index, no numbered findings, no refutation condition and no control. Either version of the skill is what produces those five. | One Opus subagent, same task. | [Evidence](#evidence) |
| F3 | The no-skill subject passed the other six items: it said what was not tested, recorded the conditions, isolated the test, wrote a script that reruns, got the answer right and stated it as fact. These items do not measure the skill. | As F2. | [Evidence](#evidence) |
| F4 | Runs with the tightened skill used fewer tokens (mean 66,800 against 69,300) and fewer tool calls (mean 11 against 17). | As F1. Three runs per version, so the tool-call difference may be noise. | [data/results.tsv](data/results.tsv) |

## Not verified

- **Small differences.** Three runs per version can only show a large effect, and every item passed in both arms, so the rubric was at its ceiling.
- **The detail that the tightening removed.** The task did not call for the full form, delegation, a choice of script language, citing a finding or correcting one, and the subjects could not ask the owner anything.
- **Cheaper models.** Haiku and Sonnet executors may depend more on explicit detail than Opus does.
- **Redaction by hand.** One un-tightened run saved a clean log but redacted it by hand, so rerunning its script prints private values. All three tightened runs redact inside the script. This was noticed afterwards, is not a rubric item, and one run in three proves nothing.
- **Blind scoring.** The main session scored the runs knowing which version each had. Seven of the eleven items are mechanical.

## Consequences

Keep the tightened version. Nothing here argues for restoring removed detail, and nothing here tests it either.

Five rubric items are where the skill earns its keep: privacy, the index, numbered findings, the refutation condition and the control. A later test of the skill should build on those and on the untested areas above, not on the six items Opus passes unaided.

Documents that cite these findings: none yet.

## Path taken

1. Wrote the hypothesis, the rubric and the brief before starting any subject.
2. Created seven run folders and started seven Opus subagents at once.
3. Observed the answer to the subjects' question directly, for scoring R10.
4. Scored the mechanical items with `scripts/score.py`, and the rest by reading each record and rerunning each subject's script.
5. Corrected the script's verdict for the no-skill run on R4 and R7 by hand: it records both under headings the script does not look for.

## How to rerun

From the repository root. The subjects are model sessions, so a rerun will not reproduce the scores exactly.

```bash
experiments/skill-tightening-ab/scripts/setup.sh "$TMPDIR/skill-ab"
```

Start one Opus subagent per run folder with the text in [data/brief.md](data/brief.md). Then:

```bash
python3 experiments/skill-tightening-ab/scripts/score.py "$TMPDIR/skill-ab"
```

Expected: every item passes for arms A and B; arm C fails several of R1 to R6. Judge R6 and R8 to R11 by reading each record and running its script.

## Evidence

### Hypothesis

Written before the runs.

- **Expected:** subjects given the tightened skill (arm B) do no worse than subjects given the un-tightened skill (arm A).
- **Refuted if:** on any rubric item, arm A passes in at least two more runs than arm B.
- **Control:** one subject with no skill at all (arm C). It is expected to fail several of the structure items. If it passes everything, the rubric cannot tell a followed protocol from an absent one, and the comparison of A and B means nothing.

### Method

Seven Opus subagents, each in its own run folder with a fresh project repository: three in arm A, three in arm B, one in arm C. The assignment is in [data/assignment.tsv](data/assignment.tsv); run folder names do not reveal the arm. All subjects get the same task, in [data/brief.md](data/brief.md): a small question about `git commit` whose honest answer involves output that names the account and the host, so a careless record leaks them.

### Rubric

Fixed before the runs. Each item is pass or fail per run.

| # | Item | How it is judged |
|---|---|---|
| R1 | No private detail in the records | `privacy-check.py` reports no `FOUND` line |
| R2 | Index exists and links the topic | File inspection |
| R3 | Topic README has a numbered findings table with conditions | File inspection |
| R4 | Topic README says what was not verified | File inspection |
| R5 | Hypothesis and refutation condition are stated | File inspection |
| R6 | A control is included and its outcome differs | File inspection |
| R7 | Conditions recorded: git version, OS release, date | File inspection |
| R8 | The test is isolated from the personal git configuration | Commands in the record |
| R9 | The rerun instructions reproduce the stated observation | Running them |
| R10 | The answer is correct | Compared with a direct observation by the main session |
| R11 | Findings are stated as facts, not as actions taken | Reading |

### Conditions

| Item | Value |
|---|---|
| Date | 2026-11-16 |
| OS and kernel release | Linux 7.4.0-070400rc1-generic |
| git | 2.53.0 |
| Subjects | Opus subagents started from a Claude Code session |
| Environment | The session's bubblewrap sandbox |

### Results

Passes per arm, out of the runs in that arm. Per-run scores and usage are in [data/results.tsv](data/results.tsv). The subjects' own records are not kept: the control's records contain private values.

| Item | A, un-tightened | B, tightened | C, no skill |
|---|---|---|---|
| R1 privacy | 3 of 3 | 3 of 3 | 0 of 1 (21 `FOUND` lines) |
| R2 index | 3 of 3 | 3 of 3 | 0 of 1 |
| R3 numbered findings | 3 of 3 | 3 of 3 | 0 of 1 |
| R4 not verified | 3 of 3 | 3 of 3 | 1 of 1 |
| R5 refutation condition | 3 of 3 | 3 of 3 | 0 of 1 |
| R6 control | 3 of 3 | 3 of 3 | 0 of 1 |
| R7 conditions | 3 of 3 | 3 of 3 | 1 of 1 |
| R8 isolation | 3 of 3 | 3 of 3 | 1 of 1 |
| R9 rerun | 3 of 3 | 3 of 3 | 1 of 1 |
| R10 correct answer | 3 of 3 | 3 of 3 | 1 of 1 |
| R11 stated as fact | 3 of 3 | 3 of 3 | 1 of 1 |
| Mean tokens | 69,300 | 66,800 | 56,100 |
| Mean tool calls | 16.7 | 11.3 | 8 |
| Mean seconds | 104 | 99 | 61 |

For R9, each subject's script was run again and its output compared with the log it had saved: identical in five of the six skill runs, and identical after redaction in the sixth.

For R10, the main session ran the same commit in an isolated repository: git exits with status 128 and `unable to auto-detect email address`, and with an identity given it commits. All seven subjects reported this, and all seven added that git refuses only because the host name has no domain part.

All six skill subjects chose the light form, used the templates, and wrote a lessons file.

### Verdict

Confirmed: the refutation condition was not met on any item. The control failed five items, so the rubric can tell a followed protocol from an absent one on those five. On the other six it cannot, and on all eleven both versions scored the maximum, so the result shows no harm from tightening without being able to show a small one.
