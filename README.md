# Shared Claude Code settings

The sandbox settings, the commit-signing wrapper and the skills for every
repository I develop with Claude Code, kept in one place.

**Status: plan only. Nothing below is implemented yet.** Today
`conf/project-settings.json` has to be copied or linked as each repo's
`.claude/settings.json`, and commits and pushes go through the scripts in
`scripts/`, copied into each repo's `.claude/scripts/` and run outside the
sandbox.

## Goal

Set up once per machine, then every repo works:

- nothing copied into, or committed to, the repos I develop in;
- fixing a setting or the wrapper fixes it everywhere;
- a new machine is: clone this repo, run `install.sh`, install the signing
  key, add the marketplace.

And one rule for Git: **no Git command runs outside Claude Code's sandbox.**

- Claude commits with plain `git commit`, inside the sandbox. Commits are
  signed with a dedicated Claude signing key through a wrapper that needs
  no `gpg-agent`. The design is in [PLAN_SEQUOIA.md](PLAN_SEQUOIA.md).
- Claude does not push. I push by hand.
- `scripts/commit-bwrap.sh` and `scripts/push-bwrap.sh` are deleted, along
  with their `excludedCommands` entries.

## Design

### Parts

| Part | Where it lives | How it gets there |
|---|---|---|
| Signing wrapper (`sq-gpg`) | `~/.local/lib/claude-shared/` | `install.sh`, run by me |
| Sandbox settings | `~/.claude/settings.json` | `install.sh`, run by me |
| Signing key and trusted certificates | `~/.config/sq/git-signing/` | By hand, once per machine ([PLAN_SEQUOIA.md, section 6](PLAN_SEQUOIA.md#6-key-management)) |
| Commit skill | a plugin in this repo, which is also a marketplace | `/plugin marketplace add`, then install the plugin |

The installed wrapper is a copy, separate from this checkout. When Claude
works on this repo the checkout is writable, and Git runs the wrapper
whenever it signs or verifies, including when I run Git by hand outside the
sandbox. A session could otherwise change code that runs outside its
sandbox. Changes go live only when I review the diff and run `install.sh`
myself. For the same reason the wrapper is not shipped inside the plugin: a
plugin update would replace it unreviewed.

### Repo layout

```
install.sh                    copies the wrapper, merges settings
bin/sq-gpg                    the wrapper, moved from experiments/sq-signing-e2e/
conf/user-settings.json       today's conf/project-settings.json, renamed
.claude-plugin/marketplace.json
plugins/git-sandbox/
  .claude-plugin/plugin.json
  skills/commit/SKILL.md
docs/sq-manual.md
experiments/
```

### Commit: plain Git, signed inside the sandbox

Git is configured to sign every commit with the wrapper as `gpg.program`.
The wrapper reads the signing subkey from a plain file and calls `sq`; it
uses no socket and no key store, so it works inside the sandbox. Signing and
local verification were run end to end in the sandbox; see the
[experiment evidence](experiments/sq-signing-e2e/README.md).

A sandboxed session can read the key file and can therefore sign anything.
That is accepted: the key is a separate, signing-only identity whose
signature means "made in a Claude Code session on my machine". The reasoning
is in [PLAN_SEQUOIA.md](PLAN_SEQUOIA.md#accepted-trade-off).

Where the Git configuration lives, so that only Claude Code sessions sign
with the Claude key, is not decided yet
([PLAN_SEQUOIA.md, open item O3](PLAN_SEQUOIA.md#10-open-items)).

### Push: by hand

No push credential is readable inside the sandbox (`~/.ssh`, `~/.netrc` and
`~/.config/gh` are in `denyRead`), so a push from a session fails. I push
from my own terminal.

A push by hand trusts the repo's configuration, so Claude must not be able
to change it. Claude Code's sandbox already ensures that, and documents it:
sandbox-runtime's README lists `.git/hooks/` and `.git/config` under
[Mandatory Deny Paths](https://github.com/anthropics/sandbox-runtime/blob/main/README.md#mandatory-deny-paths-auto-protected-files),
always blocked from writes even inside an allowed write path, with no
`denyWrite` entry needed. Measured on Claude Code 2.1.321, these are
read-only inside the sandbox: `.git/config`, `.git/config.lock`,
`.git/config.worktree`, `.git/hooks`, `.git/remotes`, `.git/branches` and
`.git/objects/info/alternates`.

That protection does not cover a repo Claude creates itself, with any
`origin` and hooks it likes: `git init` plus `git remote add` in a
subdirectory did work in a test on 2.1.321. I therefore run Git by hand
only in repos I created or cloned myself, not in a nested repo a session
made.

### Settings

`conf/user-settings.json` is merged into `~/.claude/settings.json` by
`install.sh`, which keeps every other key in that file and shows the diff
before writing. It holds:

- the `denyRead` and `denyWrite` lists and the permission deny rules, with
  the install directory and `~/.config/sq` added to `denyWrite`;
- one network allowlist and one set of cache directories for all stacks.
  Every repo can reach every stack's hosts; that is the price of having no
  per-repo settings.

Compared with today's `conf/project-settings.json`, the two
`excludedCommands` entries for the scripts and the `.claude/scripts` deny
rules are removed.

### Plugin

One skill, for committing, says:

- commit with plain `git commit`; signing happens by itself;
- never push; tell me when there is something to push;
- what the wrapper's errors mean and what to tell me.

There is no hook. The earlier design had one to redirect plain `git commit`
and `git push` to the scripts; plain `git commit` is now the right command,
and `git push` fails by itself.

## To verify before building

1. The open items in [PLAN_SEQUOIA.md](PLAN_SEQUOIA.md#10-open-items):
   Forgejo accepts the signatures, how Forgejo treats a rotated key, and
   where the Git configuration lives.
2. `git push` from inside the sandbox fails for every remote I use, over
   both SSH and HTTPS.
3. `~/.config/sq` and the install directory are read-only inside the
   sandbox once the settings are merged.

## Build order

1. Verify the points above.
2. Move the wrapper to `bin/sq-gpg`.
3. Write `install.sh` and rename the settings file, without the script
   entries.
4. Generate and install the Claude signing key; upload the certificate to
   Forgejo.
5. Add the marketplace, the plugin and the commit skill.
6. Add a short check list for use after Claude Code or `sq` upgrades:
   confirm `.git/config` and `.git/hooks` are still read-only in the
   sandbox, and rerun the [PLAN_SEQUOIA.md](PLAN_SEQUOIA.md#9-test-plan)
   test plan.
7. Migrate: delete `scripts/`, and each repo's copied `.claude/scripts/`
   and settings.

## Later, if wanted

- **Per-stack network profiles**, if the single allowlist turns out too
  wide. This needs per-repo settings files again.
