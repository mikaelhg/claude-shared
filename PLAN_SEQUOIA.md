# Plan: Socket-less Git commit signing with Sequoia (`sq`)

| | |
|---|---|
| **Status** | Draft. Design only; nothing implemented or tested. |
| **Scope** | Signing Git commits from inside the sandbox; Forgejo verification. |
| **Unconfirmed items** | Listed in [Assumptions to verify](#assumptions-to-verify). |

## 1. Summary

Git commits will be signed with an OpenPGP signing subkey, using a small
wrapper script around Sequoia's `sq` command-line tool. The wrapper reads the
subkey from a plain file and needs no `gpg-agent`, no key store and no
sockets. Forgejo verifies the signatures and shows a "Verified" badge.

### Motivation

The bubblewrap sandbox does not allow Unix sockets. `gpg` signs through
`gpg-agent`, which it reaches over a Unix socket, so `gpg` cannot sign
commits inside the sandbox.

There are two ways to get signed commits:

1. **Pierce the sandbox** for the commit, for example by allowing the
   `gpg-agent` socket or running `git commit` outside the sandbox. This
   weakens the isolation the sandbox exists to provide.
2. **Use a signing process that needs no sockets.** The sandbox stays intact
   and the problem does not arise.

This plan takes option 2.

## 2. Goals and non-goals

### Goals

- Sign commits without `gpg-agent` or any other socket, so signing works
  inside the sandbox, which denies reads of `~/.gnupg`.
- Limit the damage if the signing key leaks: the key must not grant
  repository access and must be revocable without replacing the primary key.
- Show the "Verified" badge on Forgejo for signed commits.

### Non-goals

- Local signature verification (`git verify-commit`, `git log
  --show-signature`). Forgejo's badge is the verification of record. A
  `sq verify`-based path is a possible later extension (see
  [Future work](#9-future-work)).
- A general-purpose replacement for `gpg`.

## 3. Background and decisions

### 3.1 Why OpenPGP instead of SSH signing

Git can sign with SSH keys (`gpg.format=ssh`), and that needs no agent.
However, Forgejo does not distinguish SSH keys used for signing from SSH keys
used for repository access. A passphrase-less SSH signing key stored on disk
would therefore also be a push credential.

An OpenPGP signing subkey can only sign. If it leaks, an attacker can forge
signatures but cannot push, and the subkey can be revoked using the primary
key.

### 3.2 Why not `gpg-sq`

`gpg-sq` (from sequoia-chameleon-gnupg) is a `gpg`-compatible shim that could
be set directly as `gpg.program`. It is reported to use `gpg-agent` for
secret-key operations, which defeats the purpose of this plan. This report is
unconfirmed; see assumption A1.

### 3.3 Decision

Write a thin wrapper script that implements the subset of the `gpg`
command-line interface that Git uses for signing, and delegates signing to
`sq` with the secret subkey supplied as a file.

## 4. Requirements

### 4.1 The interface Git expects from `gpg.program`

Git invokes the configured program in two modes.

| Mode | Invocation | Stdin | Expected result |
|---|---|---|---|
| Sign | `gpg --status-fd=2 -bsau <keyid>` | Payload to sign | Armored detached signature on stdout; status line on the status fd; exit 0 |
| Verify | `gpg --keyid-format=long --status-fd=1 --verify <sigfile> -` | Signed payload | Status lines (`GOODSIG`, `VALIDSIG`, …) on the status fd |

Details for signing:

- The flags `-b`, `-s`, `-a` and `-u` arrive as one cluster, `-bsau`. The
  key ID is the next argument.
- The wrapper must print `[GNUPG:] SIG_CREATED ` (including the trailing
  space) on the status fd. Git treats the signature as valid only if this
  line is present and the exit status is 0.

### 4.2 Wrapper requirements

| ID | Requirement |
|---|---|
| R1 | Parse the `-bsau <keyid>` cluster, `-u`/`--local-user`, `--status-fd=N` (do not hardcode fd 2) and `--verify`. |
| R2 | Fail cleanly, without an unbound-variable error, if `-u` is the last argument. |
| R3 | Map the configured `user.signingkey` (a fingerprint, not a path) to a key file. |
| R4 | Sign with `sq`, writing an armored detached signature to stdout. |
| R5 | Print `SIG_CREATED` on the status fd only after `sq` exits 0. Do not use `exec sq`, which would leave the line printed on failure. |
| R6 | On `--verify`, exit non-zero with no output. The wrapper must never reach the signing path in verify mode, or it would sign stdin. |
| R7 | On any failure, return a non-zero exit status and write diagnostics to stderr. |
| R8 | Make no network, socket or key-store access. |

## 5. Design

### 5.1 Control flow

1. Parse arguments (R1, R2).
2. If `--verify` was given, exit non-zero (R6).
3. Resolve the key file from the key ID (R3). Exit non-zero if the file is
   missing or unreadable.
4. Run `sq --home=none sign --signer-file <file>` with options for detached,
   armored output (R4, R8). Exact flags: assumption A2.
5. If `sq` exits 0, print `[GNUPG:] SIG_CREATED ` on the status fd (R5). A
   realistic status line has the form
   `SIG_CREATED D 22 8 00 <unix-timestamp> <fingerprint>`.
6. Otherwise, propagate `sq`'s exit status (R7).

### 5.2 Key file resolution

Two options:

- **Single fixed file**, for example `~/.config/sq/git-signing.pgp`. Simplest;
  the key ID argument is ignored.
- **Fingerprint-to-file mapping**, for example
  `~/.config/sq/git-signing-<fingerprint>.pgp`. Supports several identities.

Recommendation: start with the fixed file and move to the mapping only when a
second identity is needed. In both cases the file must contain only the
signing subkey, so the wrapper does not need to honour the `!` fingerprint
selector that Git users append to force a specific subkey.

### 5.3 Git configuration

```ini
[gpg]
    program = <path to wrapper>
[user]
    signingkey = <subkey fingerprint>
[commit]
    gpgsign = true
```

## 6. Key management

1. Keep the primary certification key offline.
2. Generate a dedicated signing-capable subkey with a short expiry
   (6–12 months). Rotate it before expiry.
3. Export the **secret subkey only** to a file outside the sandbox-denied
   paths (not under `~/.gnupg`, `~/.ssh` and similar), with mode `0600`.
4. Leave the subkey without a passphrase. Git runs the wrapper with stdin
   piped, so an encrypted key would require a terminal prompt. This is
   acceptable because the key is signing-only and short-lived. See assumption
   A3 for the encrypted alternative.
5. Upload the public certificate, including the subkey, to Forgejo. The
   commit author email must match a user ID on the certificate and be a
   verified email on the Forgejo account; otherwise the commit shows as
   unverified.

## 7. Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Any process that can read the key file can sign as the user, including agent sessions. | Commits made by an agent appear signed by the user. | Use a separate signing identity or subkey for agent sessions if this is unacceptable. |
| Subkey leaks. | Forged signatures. No repository access. | Short expiry; revoke with the offline primary key. |
| A Git upgrade changes how it invokes `gpg.program`. | Signing breaks, possibly silently. | Add a hook or CI check that fails on unsigned commits. |
| The wrapper is invoked in an unexpected mode. | Wrong output, or signing when verification was requested. | R6; fail closed on unrecognized arguments. |

## 8. Test plan

Run all tests on a scratch repository with a throwaway key.

| # | Test | Pass criteria |
|---|---|---|
| T1 | Run the wrapper with Git's exact arguments and a sample payload. | Stdout is a valid detached signature (check with `sq verify` against the certificate); `SIG_CREATED` appears on the status fd; exit 0. |
| T2 | Point the wrapper at a missing or invalid key file. | Non-zero exit; no `SIG_CREATED`. |
| T3 | Run the wrapper with `--verify`. | Non-zero exit; no output; no signing. |
| T4 | `git commit -S`, then `git cat-file -p HEAD`. | The commit object contains a `gpgsig` header. |
| T5 | Repeat T4 inside the sandbox. | Succeeds with no sandbox violations. |
| T6 | Push the commit to Forgejo. | Forgejo shows the "Verified" badge. |

## 9. Future work

- Add a `sq verify`-based `--verify` path that emits `GOODSIG` and `VALIDSIG`
  status lines, enabling local `git verify-commit`.
- Add a pre-push hook or CI job that rejects unsigned commits.

## Assumptions to verify

These come from memory and must be checked against the installed versions
of `sq` and Git before implementation.

| ID | Assumption | How to check |
|---|---|---|
| A1 | `gpg-sq` requires `gpg-agent` for signing. | Read its documentation or source; run it with the agent socket unavailable. |
| A2 | `sq sign` can produce an armored detached signature on stdout; the exact flags differ between versions. | `sq sign --help`; run T1. |
| A3 | `sq --home=none` avoids the key store and any socket; encrypted key files can be unlocked non-interactively or via a terminal prompt. | Run `sq` under `strace -f -e trace=network,connect` or the sandbox; read `sq --help`. |
| A4 | Git accepts a signature when stderr/status contains `[GNUPG:] SIG_CREATED ` and the exit status is 0. | Run T4 against the installed Git version. |

## Links

- <https://sequoia-pgp.org/>
- <https://gitlab.com/sequoia-pgp/sequoia>
- <https://github.com/google/go-jsonnet>
- <https://github.com/anthropics/sandbox-runtime/blob/main/README.md>
- <https://raw.githubusercontent.com/anthropics/sandbox-runtime/refs/heads/main/README.md>
- <https://github.com/containers/bubblewrap>
