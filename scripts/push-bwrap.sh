#!/bin/sh
# Push one local branch to the same-named branch on origin, nothing else, with
# git and ssh inside their own bubblewrap sandbox.
#
# Usage: push-bwrap.sh <branch>
# Run it from outside Claude Code's sandbox (it needs the network and your ssh
# setup). The caller picks only the branch name, never the remote, refspec or
# flags. Fast-forward or new branch only (no '+' in the refspec, no --force,
# no delete), no tags, no submodules, no hooks. Refuses if repo or user config
# could redirect the push.
#
# origin must be exactly the URL you allowed for this repository, once, in
# your global git config (outside anything Claude Code can write):
#   git config --global push-bwrap.<repo path>.url <url>
# e.g. git config --global push-bwrap./home/me/src/foo.url git@example.com:me/foo.git
#
# What git and ssh can see in there, and nothing else:
#   - /usr/bin/git, /usr/bin/ssh and the library directories, read-only.
#     No shell and no other program, so a hook, credential helper,
#     ProxyCommand or any other configured command has nothing to run.
#   - the working tree read-only, and .git read-write
#   - the git configuration of the system and the user, read-only
#   - a passwd file holding only your own entry
#   - for the push itself, and not for the checks before it:
#       - the network, and the resolver configuration
#       - the contents of ~/.ssh read-only, behind a generated ~/.ssh/config
#         that pins the safety options and then includes your own
#       - the system known hosts, read-only; not the system ssh
#         configuration, which ssh would refuse in there
#       - your ssh agent's socket, if SSH_AUTH_SOCK is your own socket under
#         /run/user/<uid>/, which Claude Code's sandbox can't write to
#   - no other processes, an empty environment, no capabilities
#
# A host that your ssh config reaches through ProxyJump or ProxyCommand won't
# work: both need a shell.
set -eu

# Fail early with a reason if Claude Code ran this inside its sandbox, where
# the network and ssh setup are out of reach and the error would be cryptic.
# Excluded commands run as children of Claude (CLAUDE_PID) in its PID
# namespace; sandboxed ones get their own, where that PID isn't visible.
case "${CLAUDE_PID:-}" in
  '' | *[!0-9]*) ;;  # not started by Claude Code, e.g. from your own terminal
  *)
    if [ "$(/usr/bin/readlink "/proc/$CLAUDE_PID/ns/pid" 2>/dev/null || :)" != "$(/usr/bin/readlink /proc/self/ns/pid)" ]; then
      /usr/bin/cat >&2 <<MSG
$0: running inside Claude Code's sandbox, so it would fail.
Its sandbox.excludedCommands entry in .claude/settings.json is missing, does not
match this command line (arguments need a "<command> *" entry), or was added
after this session started (restart Claude Code to load it).
MSG
      exit 3
    fi ;;
esac

die() { echo "$0: $*" >&2; exit 1; }

[ "$#" -eq 1 ] || { echo "usage: $0 <branch>" >&2; exit 2; }
BRANCH=$1
# Plain branch names only: no leading '-', ':', '+', '*', '..', or ref prefixes.
case "$BRANCH" in
  -* | *:* | *+* | *'*'* | *..* | refs/* | HEAD | */ | /* | '')
    echo "refusing branch name: $BRANCH" >&2; exit 2 ;;
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
USER_ENTRY=$(/usr/bin/getent passwd "$USER_ID")
USER_HOME=$(printf '%s\n' "$USER_ENTRY" | /usr/bin/cut -d: -f6)
[ -n "$USER_HOME" ] && [ -d "$USER_HOME" ] || die "no home directory for uid $USER_ID"

AGENT=
case "${SSH_AUTH_SOCK:-}" in
  "/run/user/$USER_ID/"*)
    if [ -S "$SSH_AUTH_SOCK" ] && [ "$(/usr/bin/stat -c %u "$SSH_AUTH_SOCK")" = "$USER_ID" ]; then AGENT=$SSH_AUTH_SOCK; fi ;;
esac

# Generated files and the two bwrap argument lists live here until exit.
# bwrap reads a list with --args <fd>, one NUL-terminated argument each.
TMP=$(/usr/bin/mktemp -d /tmp/push-bwrap.XXXXXX)
trap '/usr/bin/rm -rf "$TMP"' EXIT
trap 'exit 1' HUP INT TERM
base() { printf '%s\0' "$@" >>"$TMP/base.args"; }
net() { printf '%s\0' "$@" >>"$TMP/net.args"; }

printf '%s\n' "$USER_ENTRY" >"$TMP/passwd"

# The sandbox every git call gets: enough for the local checks.
base \
  --unshare-all --die-with-parent --new-session --cap-drop ALL --clearenv \
  --setenv HOME "$USER_HOME" --setenv PATH /usr/bin --setenv LANG C.UTF-8 \
  --proc /proc --dev /dev --tmpfs /tmp \
  --ro-bind /usr/bin/git /usr/bin/git \
  --ro-bind /usr/lib /usr/lib \
  --ro-bind-try /usr/lib64 /usr/lib64 \
  --ro-bind-try /usr/libexec/git-core /usr/libexec/git-core \
  --symlink usr/lib /lib \
  --symlink usr/lib64 /lib64 \
  --ro-bind-try /etc/ld.so.cache /etc/ld.so.cache \
  --ro-bind-try /etc/gitconfig /etc/gitconfig \
  --ro-bind "$TMP/passwd" /etc/passwd \
  --dir "$USER_HOME" \
  --ro-bind-try "$USER_HOME/.gitconfig" "$USER_HOME/.gitconfig" \
  --ro-bind-try "$USER_HOME/.config/git" "$USER_HOME/.config/git" \
  --ro-bind "$REPO" "$REPO" \
  --bind "$REPO/.git" "$REPO/.git" \
  --chdir "$REPO"

# What the push gets on top: the network, name resolution and ssh.
# The system ssh configuration stays out: in the sandbox's user namespace
# root's files belong to "nobody", and ssh refuses a config file with that
# owner. ssh then runs on its built-in defaults plus the user's config.
net \
  --share-net \
  --ro-bind /usr/bin/ssh /usr/bin/ssh \
  --ro-bind-try /etc/resolv.conf /etc/resolv.conf \
  --ro-bind-try /etc/hosts /etc/hosts \
  --ro-bind-try /etc/nsswitch.conf /etc/nsswitch.conf \
  --ro-bind-try /etc/gai.conf /etc/gai.conf \
  --ro-bind-try /etc/ssh/ssh_known_hosts /etc/ssh/ssh_known_hosts \
  --perms 0700 --dir "$USER_HOME/.ssh"

# ssh takes the first value it sees for an option, so these win over the
# user's own config, which follows under another name. No shell is needed to
# pass them, as "ssh -o ..." in core.sshCommand would.
/usr/bin/cat >"$TMP/ssh_config" <<'EOF'
BatchMode yes
StrictHostKeyChecking yes
UpdateHostKeys no
ControlMaster no
ControlPath none
PermitLocalCommand no
ForwardAgent no
ForwardX11 no
ClearAllForwardings yes
EOF
USER_SSH_CONFIG=config.push-bwrap-user
for f in "$USER_HOME"/.ssh/* "$USER_HOME"/.ssh/.[!.]*; do
  # Regular files and directories only: no control sockets, no unmatched glob.
  [ -f "$f" ] || [ -d "$f" ] || continue
  name=${f##*/}
  case "$name" in
    "$USER_SSH_CONFIG") die "unexpected file $f" ;;
    config)
      echo "Include $USER_SSH_CONFIG" >>"$TMP/ssh_config"
      net --ro-bind "$f" "$USER_HOME/.ssh/$USER_SSH_CONFIG" ;;
    *) net --ro-bind "$f" "$f" ;;
  esac
done
/usr/bin/chmod 600 "$TMP/ssh_config"
net --ro-bind "$TMP/ssh_config" "$USER_HOME/.ssh/config"

if [ -n "$AGENT" ]; then
  net --setenv SSH_AUTH_SOCK "$AGENT" --ro-bind "$AGENT" "$AGENT"
fi

# core.sshCommand has no spaces or shell characters, so git runs it directly
# and not through a shell, which the sandbox doesn't have.
# $1 is "local" or "net"; the rest is the git command.
sandboxed_git() {
  mode=$1
  shift
  set -- /usr/bin/git \
    -c core.hooksPath=/dev/null \
    -c core.fsmonitor=false \
    -c core.sshCommand=/usr/bin/ssh \
    -c credential.helper= \
    -c protocol.allow=never \
    -c protocol.ssh.allow=always \
    -c push.followTags=false \
    -c push.recurseSubmodules=no \
    -c push.gpgSign=false \
    -c push.autoSetupRemote=false \
    "$@"
  if [ "$mode" = net ]; then
    /usr/bin/env -i /usr/bin/bwrap --args 8 --args 9 "$@" 8<"$TMP/base.args" 9<"$TMP/net.args"
  else
    /usr/bin/env -i /usr/bin/bwrap --args 8 "$@" 8<"$TMP/base.args"
  fi
}
local_git() { sandboxed_git local "$@"; }
net_git() { sandboxed_git net "$@"; }

# The script must sit inside the work tree it found.
[ "$(local_git rev-parse --show-toplevel)" = "$REPO" ] || die "not the top of a git work tree: $REPO"

# The remote must be exactly the URL you allowed for this repository in your
# global git config, which Claude Code's sandbox can't write to (unlike
# .git/config), with no push URL, URL rewrites, includes, or custom
# receive-pack.
ALLOWED=$(local_git config --global --get-all "push-bwrap.$REPO.url" || :)
[ -n "$ALLOWED" ] && [ "$(printf '%s\n' "$ALLOWED" | /usr/bin/wc -l)" -eq 1 ] || die "no single allowed remote URL for $REPO in your global git config; set one with:
  git config --global push-bwrap.$REPO.url <url>"
ORIGIN=$(local_git config --get-all remote.origin.url || :)
[ "$ORIGIN" = "$ALLOWED" ] || die "remote.origin.url is not the allowed $ALLOWED: $ORIGIN"
CONFIG_RE='^(url\..*|include\..*|includeif\..*|remote\.origin\.(pushurl|receivepack|uploadpack|push|mirror|vcs|proxy))$'
if local_git config --get-regexp "$CONFIG_RE" >/dev/null; then
  echo "$0: refusing: repo or user config redirects or alters the push" >&2
  local_git config --show-origin --get-regexp "$CONFIG_RE" >&2
  exit 1
fi

# git's own rules for branch names, then the branch must exist locally.
local_git check-ref-format --branch "$BRANCH" >/dev/null
local_git rev-parse --verify --quiet "refs/heads/$BRANCH^{commit}" >/dev/null || die "no local branch: $BRANCH"

net_git push --no-verify --no-follow-tags --no-recurse-submodules --porcelain \
  origin "refs/heads/$BRANCH:refs/heads/$BRANCH"
