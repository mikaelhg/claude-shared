#!/bin/sh
# A signed commit, made by git inside its own bubblewrap sandbox.
#
# Usage: commit-bwrap.sh <message>
# Run it from outside Claude Code's sandbox (it needs gpg-agent). The one
# argument is the whole commit message: subject, blank line, body. It reaches
# git as a single argument and is never interpreted by a shell.
#
# What git can see in there, and nothing else:
#   - /usr/bin/git, /usr/bin/gpg and the library directories, read-only.
#     No shell and no other program, so a hook, editor, pager or any other
#     repo-configured command has nothing to run.
#   - the working tree read-only, and .git read-write
#   - the git configuration of the system and the user, read-only
#   - ~/.gnupg read-only with the private key directories masked, and the
#     gpg-agent socket. The agent, outside, holds the key and does the signing.
#   - no network, no other processes, an empty environment, no capabilities
set -eu

# Fail early with a reason if Claude Code ran this inside its sandbox, where
# gpg-agent is out of reach and the error would be cryptic. Excluded commands
# run as children of Claude (CLAUDE_PID) in its PID namespace; sandboxed ones
# get their own, where that PID isn't visible.
case "${CLAUDE_PID:-}" in
  '' | *[!0-9]*) ;;  # not started by Claude Code, e.g. from your own terminal
  *)
    if [ "$(/usr/bin/readlink "/proc/$CLAUDE_PID/ns/pid" 2>/dev/null || :)" != "$(/usr/bin/readlink /proc/self/ns/pid)" ]; then
      /usr/bin/cat >&2 <<MSG
$0: running inside Claude Code's sandbox, so it would fail.
Its sandbox.excludedCommands entry in .claude/settings.json is missing, does not
match this command line exactly, or was added after this session started
(restart Claude Code to load it).
MSG
      exit 3
    fi ;;
esac

die() { echo "$0: $*" >&2; exit 1; }

[ "$#" -eq 1 ] || { echo "usage: $0 <message>" >&2; exit 2; }
MESSAGE=$1
# Git would reject these too, but only after gpg-agent has been started.
case "$MESSAGE" in
  *[![:space:]]*) ;;
  *) echo "$0: empty commit message" >&2; exit 2 ;;
esac

# The repo is the nearest directory above this script that holds .git, so the
# script works from scripts/ and from .claude/scripts/ alike. A linked
# worktree keeps its git directory elsewhere; this script doesn't follow it.
REPO=$(/usr/bin/realpath "$(/usr/bin/dirname "$0")")
while [ ! -e "$REPO/.git" ]; do
  [ "$REPO" != / ] || die "no git repository above $0"
  REPO=$(/usr/bin/dirname "$REPO")
done
[ -d "$REPO/.git" ] && [ ! -L "$REPO/.git" ] || die "$REPO/.git is not a directory"

USER_ID=$(/usr/bin/id -u)
USER_HOME=$(/usr/bin/getent passwd "$USER_ID" | /usr/bin/cut -d: -f6)
[ -n "$USER_HOME" ] && [ -d "$USER_HOME" ] || die "no home directory for uid $USER_ID"

# gpg-agent must already run: the sandbox has neither the program nor the
# private keys to start one. Then ask where its socket is.
gpgconf() { /usr/bin/env -i HOME="$USER_HOME" PATH=/usr/bin:/bin /usr/bin/gpgconf "$@"; }
gpgconf --launch gpg-agent
GNUPG_HOME=$(gpgconf --list-dirs homedir)
AGENT_SOCK=$(gpgconf --list-dirs agent-socket)
[ -d "$GNUPG_HOME" ] || die "no GnuPG home at $GNUPG_HOME"
[ -S "$AGENT_SOCK" ] || die "no gpg-agent socket at $AGENT_SOCK"
SOCK_DIR=$(/usr/bin/dirname "$AGENT_SOCK")

set -- \
  --unshare-all --die-with-parent --new-session --cap-drop ALL --clearenv \
  --setenv HOME "$USER_HOME" --setenv PATH /usr/bin --setenv LANG C.UTF-8 \
  --proc /proc --dev /dev --tmpfs /tmp \
  --ro-bind /usr/bin/git /usr/bin/git \
  --ro-bind /usr/bin/gpg /usr/bin/gpg \
  --ro-bind /usr/lib /usr/lib \
  --ro-bind-try /usr/lib64 /usr/lib64 \
  --ro-bind-try /usr/libexec/git-core /usr/libexec/git-core \
  --symlink usr/lib /lib \
  --symlink usr/lib64 /lib64 \
  --ro-bind-try /etc/ld.so.cache /etc/ld.so.cache \
  --ro-bind-try /etc/localtime /etc/localtime \
  --ro-bind-try /etc/gitconfig /etc/gitconfig \
  --dir "$USER_HOME" \
  --ro-bind-try "$USER_HOME/.gitconfig" "$USER_HOME/.gitconfig" \
  --ro-bind-try "$USER_HOME/.config/git" "$USER_HOME/.config/git" \
  --ro-bind "$GNUPG_HOME" "$GNUPG_HOME"

# Hide the private keys; signing goes through the agent.
for d in private-keys-v1.d openpgp-revocs.d; do
  [ -d "$GNUPG_HOME/$d" ] && set -- "$@" --tmpfs "$GNUPG_HOME/$d"
done

# gpg looks for the socket where it is outside, usually /run/user/<uid>/gnupg,
# and wants that directory private. Only the agent's main socket goes in, and
# keyboxd's when gpg is set up to use it.
case "$SOCK_DIR" in
  "$GNUPG_HOME" | "$GNUPG_HOME"/*) ;;
  *)
    set -- "$@" --perms 0700 --dir "$SOCK_DIR" \
      --ro-bind "$AGENT_SOCK" "$AGENT_SOCK" \
      --ro-bind-try "$SOCK_DIR/S.keyboxd" "$SOCK_DIR/S.keyboxd"
    ;;
esac

set -- "$@" \
  --ro-bind "$REPO" "$REPO" \
  --bind "$REPO/.git" "$REPO/.git" \
  --chdir "$REPO"

exec /usr/bin/env -i /usr/bin/bwrap "$@" \
  /usr/bin/git \
    -c core.hooksPath=/dev/null \
    -c core.fsmonitor=false \
    -c gpg.format=openpgp \
    -c gpg.program=/usr/bin/gpg \
    commit -m "$MESSAGE"
