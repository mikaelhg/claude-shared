# Shared Claude Code settings

The sandboxed commit and push scripts, the sandbox settings, and the skills
for using them, for every repository I develop with Claude Code, kept in one
place.

**Status: plan only. Nothing below is implemented yet.** Today the scripts in
`scripts/` have to be copied into each repo's `.claude/scripts/`, and
`conf/project-settings.json` has to be copied or linked as each repo's
`.claude/settings.json`.

## Goal

Set up once per machine, then every repo works:

- nothing copied into, or committed to, the repos I develop in;
- fixing a script or a setting fixes it everywhere;
- a new machine is: clone this repo, run `install.sh`, add the marketplace.

Carried over from the current scripts, and not to be weakened:

- Claude can't modify the scripts or choose where a push goes.
- The caller chooses only the commit message or the branch name.
- The scripts are safe because of their own bwrap sandbox and checks, not
  because of how Claude Code runs them.

## Design

### Parts

| Part | Where it lives | How it gets there |
|---|---|---|
| Scripts | `~/.local/lib/claude-shared/` | `install.sh`, run by me |
| Sandbox settings, `excludedCommands` | `~/.claude/settings.json` | `install.sh`, run by me |
| Skills and the reminder hook | a plugin in this repo, which is also a marketplace | `/plugin marketplace add`, then install the plugin |

The installed scripts are a copy, separate from this checkout. When Claude
works on this repo the checkout is writable, so a session could otherwise
change code that runs outside its sandbox. Changes go live only when I review
the diff and run `install.sh` myself. For the same reason the scripts are not
shipped inside the plugin: a plugin update would replace them unreviewed.

### Repo layout

```
install.sh                    copies scripts, merges settings
scripts/commit-bwrap.sh
scripts/push-bwrap.sh
conf/user-settings.json       today's conf/project-settings.json, renamed
.claude-plugin/marketplace.json
plugins/git-sandbox/
  .claude-plugin/plugin.json
  skills/commit/SKILL.md
  skills/push/SKILL.md
  hooks/hooks.json
```

### Scripts: the repo is the current directory

The scripts stop looking for the repo above their own location and walk up
from the current directory to the nearest `.git` instead.

The current directory can be trusted for this because Claude Code keeps a
call inside its sandbox, where the scripts refuse to run, whenever the call
is anything but the bare command. From the
[settings reference](https://code.claude.com/docs/en/settings-reference#sandbox-excludedcommands),
a call stays sandboxed if it contains a `cd`, a command substitution, a
subshell, a redirection other than `2>&1`, or a heredoc. Measured on Claude
Code 2.1.321 with the commit script:

| Call | Result |
|---|---|
| `script a b` | outside the sandbox |
| `true && script a b` | sandboxed, refused |
| `FOO=1 script a b` | sandboxed, refused |
| `other; script a b` | sandboxed, refused |

So Claude can't change directory or environment in the same call. A `cd` in
an earlier call does persist, but only inside the session's working
directories. The repo the script finds is therefore the project, a nested
repo or submodule inside it, or a directory I added to the session: all
places the session was given anyway.

That is why there is no per-repo registration and no hook that tells the
scripts where the repo is.

### Push: trust `origin`, refuse nested repos

The push goes to the repo's `origin`, with no separate list of allowed URLs.
A tampered remote would be just as much a problem for a push I make by hand,
where nobody checks the remotes first, so the protection belongs at the
source: Claude must not be able to change them. Claude Code's sandbox
already does that, and documents it: sandbox-runtime's README lists
`.git/hooks/` and `.git/config` under
[Mandatory Deny Paths](https://github.com/anthropics/sandbox-runtime/blob/main/README.md#mandatory-deny-paths-auto-protected-files),
always blocked from writes even inside an allowed write path, with no
`denyWrite` entry needed. Measured on 2.1.321, these
are read-only inside the sandbox: `.git/config`, `.git/config.lock`,
`.git/config.worktree`, `.git/hooks`, `.git/remotes`, `.git/branches` and
`.git/objects/info/alternates`.

The `push-bwrap.<repo path>.url` check in the working copy of
`push-bwrap.sh` is removed again. The checks for `pushurl`, `url.*` rewrites
and includes stay.

What that protection doesn't cover is a repo Claude creates itself, with any
`origin` it likes: the same README says a protected directory below the
working directory that doesn't exist yet can be filled, and `git init` plus
`git remote add` in a subdirectory did work in a test on 2.1.321. Such a
repo can only be somewhere Claude can write and `cd` to, which means inside
the project. So the push script refuses a repo that has another `.git` above
it. This also refuses legitimate nested clones; submodules and linked
worktrees are refused already.

Probably closed, but to verify: a session started in a directory that isn't
a git repo, where Claude runs `git init` at the top. On Linux a mandatory
deny path that doesn't exist yet is blocked too, and paths in the working
directory itself are always protected, so `.git/config` there should not be
creatable.

### Settings

`conf/user-settings.json` is merged into `~/.claude/settings.json` by
`install.sh`, which keeps every other key in that file and shows the diff
before writing. It holds:

- `excludedCommands` for the two installed scripts. User-level entries
  combine with project ones, and still apply if the sandbox is ever
  admin-required, when project-level entries are ignored.
- the `denyRead` and `denyWrite` lists and the permission deny rules, with
  the install directory added to both;
- one network allowlist and one set of cache directories for all stacks.
  Every repo can reach every stack's hosts; that is the price of having no
  per-repo settings.
- a permission allow rule for the commit script, so it runs unprompted.
  Push has none, so each push still asks me. Excluded commands go through
  the normal permission flow.

### Plugin

Skills, one each for commit and push, say:

- use the script, never plain `git commit` or `git push`;
- call it as the bare command and nothing else: no `cd`, no `&&`, no
  variable prefix, no redirection except `2>&1`;
- pass the commit message as one literal quoted argument with the newlines
  inside the quotes. The usual `"$(cat <<'EOF' ... EOF)"` form is a command
  substitution and a heredoc, so the call would stay sandboxed and be
  refused;
- what each refusal from the scripts means and what to tell me.

A `PreToolUse` hook rejects plain `git commit` and `git push` with a pointer
to the scripts. A skill is advisory and may be read only after the first
failure; the hook makes the redirect immediate. It is a convenience, not a
protection, so it can live in the plugin.

## To verify before building

1. An `excludedCommands` entry with an absolute path matches, and whether
   `~` is expanded in it. If not: put the install directory on `PATH` and
   exclude by bare name.
2. A plugin hook can reject a Bash call with a message Claude sees.
3. In a project directory that isn't a git repo, `git init` at the top
   fails inside the sandbox.

## Build order

1. Verify the three points above.
2. Change the scripts to find the repo from the current directory, and
   update their error messages and header comments. In the push script,
   drop the allowed-URL check and add the nested-repo refusal.
3. Write `install.sh` and rename the settings file.
4. Add the marketplace, the plugin, the two skills and the hook.
5. Add a short check list for use after Claude Code upgrades, since the
   scripts can't detect a change in either behaviour they rely on: rerun
   the table above, and confirm `.git/config` is still read-only in the
   sandbox.
6. Migrate: delete each repo's copied `.claude/scripts/` and settings.

## Later, if wanted

- **Linked worktrees.** The scripts still refuse them. Supporting them means
  validating the worktree's `.git` pointer against the main repo and binding
  the main `.git`. On Linux the sandbox blocks writes to the `.git` file of
  a session started in a worktree, which helps. A worktree kept inside its
  main repo's directory would trip the nested-repo refusal, so that rule
  needs an exception for a validated worktree.
- **Per-stack network profiles**, if the single allowlist turns out too
  wide. This needs per-repo settings files again.
