# Plan: socket-less git commit signing with Sequoia (`sq`)

Status: plan only, nothing implemented or tested. Items marked **(verify)** are
from memory and must be checked against the installed `sq` / `git` versions.

## Goal

Sign git commits with an OpenPGP key without gpg-agent or any other socket,
so signing works inside the sandbox (which denies reads of `~/.gnupg`), and
have Forgejo show the "Verified" badge.

## Why OpenPGP and not SSH signing

Forgejo does not separate SSH keys for signing from SSH keys for repo access.
A passphrase-less SSH signing key on disk would therefore also be a push
credential. An OpenPGP signing subkey can only sign, so leaking it does not
grant repo access, and it can be revoked without touching the primary key.

## Why not `gpg-sq` (sequoia-chameleon-gnupg)

It was the first candidate (a gpg-compatible shim usable as `gpg.program`).
It reportedly uses gpg-agent for secret-key operations, which defeats the
purpose. **(verify)** against its docs/source before ruling it out for good.

## Approach: thin wrapper around `sq`

Set `gpg.program` to a small wrapper script that reads the secret subkey from
a plain file and signs with `sq`, never touching an agent or key store.

### The contract git expects from `gpg.program`

Signing: `gpg --status-fd=2 -bsau <keyid>` with the payload on stdin.
- Flags arrive as one cluster `-bsau`; the key id is the *next* argument.
- Wrapper must write an armored detached signature to stdout.
- Wrapper must print `[GNUPG:] SIG_CREATED ` (trailing space matters) on the
  status fd, only after signing succeeded, and exit 0.

Verification (same `gpg.program`): `gpg --keyid-format=long --status-fd=1
--verify <sigfile> -`.
- The wrapper must dispatch on `--verify`. It must never fall through to the
  signing path, or it would sign stdin instead.
- Initial behaviour: exit non-zero with no output, so git reports the
  signature as unverified. Local verification is out of scope (see below).

### Wrapper design

1. Parse args: handle the `-bsau` cluster, `--status-fd=N` (do not hardcode 2),
   `-u`/`--local-user`, and `--verify`. Tolerate `-u` as the last argument
   without crashing under `set -u`.
2. Resolve the key: `user.signingkey` is a fingerprint, not a path. Map it to
   a key file (e.g. `~/.config/sq/git-signing-<fpr>.pgp`), or use a single
   fixed file. Keep the file subkey-only so the wrapper does not need to honour
   the `!` fingerprint selector.
3. Sign: `sq --home=none sign --signer-file <file> ...` producing an armored
   detached signature on stdout. **(verify)** exact flags: detached/armor
   options in current `sq sign --help`, and that `--home=none` really avoids
   the key store and any socket.
4. Only if `sq` exits 0, print `[GNUPG:] SIG_CREATED ` on the status fd (do not
   `exec sq`, or a failure leaves a fake success line). Ideally include a
   realistic payload: `SIG_CREATED D 22 8 00 <unix-ts> <fingerprint>`.
5. Propagate `sq`'s exit status on failure; print diagnostics to stderr.

### Key setup

- Keep the primary certification key offline.
- Generate a dedicated signing-capable subkey with a short expiry
  (6-12 months), and rotate it.
- Export the **secret subkey only** to a file outside the sandbox-denied paths
  (not under `~/.gnupg`, `~/.ssh`, etc.), mode 0600.
- Passphrase: git pipes stdin, so an encrypted key would need a tty/pinentry
  prompt. Unencrypted is acceptable here because the key is signing-only and
  short-lived. **(verify)** how `sq` prompts for encrypted keys if you prefer
  encryption.
- Upload the public cert (with the subkey) to Forgejo. The commit author email
  must match a UID on the cert and be a verified email on the Forgejo account,
  otherwise the commit shows as unverified.

### Git config

```
gpg.program    = <path to wrapper>
user.signingkey = <subkey fingerprint>
commit.gpgsign = true
```

## Threat model notes

- Anything the agent can read, it can sign with. Commits made in agent
  sessions will be signed as you. If that is unwanted, use a separate signing
  identity/subkey for agent sessions.
- Revocation: keep a revocation path for the subkey (the offline primary).
- Compatibility drift: a git upgrade that changes how it invokes `gpg.program`
  could silently break signing. Guard with a hook or CI check that fails on
  unsigned commits.

## Test plan

On a scratch repo with a throwaway key:

1. Wrapper unit checks: feed it a payload with git's exact argv; confirm
   stdout is a valid detached signature (`sq verify` / `gpg --verify` against
   the cert) and the status line appears only on success.
2. Failure path: point it at a missing/bad key file; confirm non-zero exit and
   no `SIG_CREATED`.
3. `--verify` path: confirm it exits non-zero and never signs.
4. `git commit -S` end to end, then `git cat-file -p HEAD` shows a `gpgsig`.
5. Sandbox: run the commit from inside the sandbox; confirm no socket access
   is attempted (check for sandbox violations).
6. Push to Forgejo; confirm the "Verified" badge.

## Out of scope

- Local signature verification (`git verify-commit`, `--show-signature`). Rely
  on Forgejo's badge. Could later add a `sq verify` based path emitting
  `GOODSIG`/`VALIDSIG` status lines.
- Reimplementing a general gpg replacement.

## Open questions

- Does `gpg-sq` really require gpg-agent for signing?
- Exact `sq sign` flags for detached armored output on the installed version.
- Does `--home=none` fully avoid sequoia-keystore sockets?
- Single fixed key file vs. fingerprint-to-file mapping.

## Links

https://sequoia-pgp.org/

https://gitlab.com/sequoia-pgp/sequoia

https://github.com/google/go-jsonnet

https://github.com/anthropics/sandbox-runtime/blob/main/README.md

https://raw.githubusercontent.com/anthropics/sandbox-runtime/refs/heads/main/README.md

https://github.com/containers/bubblewrap
