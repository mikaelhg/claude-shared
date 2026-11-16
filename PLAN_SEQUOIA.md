# Plan: Socket-less Git commit signing with Sequoia (`sq`)

| | |
|---|---|
| **Status** | Design validated by experiment; not yet installed. |
| **Tested** | Signing and local verification inside the sandbox (`sq` 1.3.1, Git 2.53.0). See [experiment evidence](experiments/sq-signing-e2e/README.md). |
| **Not tested** | Forgejo verification and key rotation. See [Open items](#10-open-items). |
| **Scope** | Signing Git commits from inside the sandbox; Forgejo verification. |

## 1. Summary

Git commits made by Claude Code will be signed with a dedicated "Claude
signing key": an OpenPGP signing subkey stored in a plain file. A small
wrapper script around Sequoia's `sq` command-line tool acts as Git's
`gpg.program`. It needs no `gpg-agent`, no key store and no sockets, so
`git commit` runs inside the sandbox like any other command. Forgejo verifies
the signatures and shows a "Verified" badge.

### Motivation

The bubblewrap sandbox does not allow Unix sockets and denies reads of
`~/.gnupg`. `gpg` signs through `gpg-agent`, which it reaches over a Unix
socket, so `gpg` cannot sign commits inside the sandbox.

Today this is worked around by [`scripts/commit-bwrap.sh`](scripts/commit-bwrap.sh),
which Claude Code runs outside its sandbox (through
`sandbox.excludedCommands`) so that it can reach `gpg-agent`. The script
builds its own sandbox and checks its input, but it remains a hole in Claude
Code's sandbox that has to be defended.

**The purpose of this plan is to remove that hole.** With a signing process
that needs no sockets, committing needs no excluded command and
`commit-bwrap.sh` can be deleted.

The other excluded Git command, [`scripts/push-bwrap.sh`](scripts/push-bwrap.sh),
is removed as well: pushing will be done by hand. After this plan no Git
command runs outside the sandbox.

### Accepted trade-off

Moving the key into a file the sandbox can read changes what a sandboxed
session can do with it:

| | `commit-bwrap.sh` (today) | This plan |
|---|---|---|
| Sandbox | Pierced for every commit | Intact |
| Key location | In `gpg-agent`, outside the sandbox | A plain file readable inside the sandbox |
| What a session can sign | The working tree, with a message it chooses | Anything: any commit, author, date or tag |
| Key can be copied out | No | Yes; usable elsewhere until revoked or expired |

This is accepted. The current GnuPG key has no passphrase, so any process
that reaches the agent can already sign with it. The Claude signing key is
a separate, signing-only key whose signature means "made in a Claude Code
session on my machine", not "reviewed by me".

## 2. Goals and non-goals

### Goals

- Sign commits without `gpg-agent` or any other socket, so that signing
  works inside the sandbox.
- Remove every Git script that runs outside the sandbox:
  `commit-bwrap.sh`, `push-bwrap.sh` and their `excludedCommands` entries.
- Limit the damage if the signing key leaks: the key must not grant
  repository access and must be revocable.
- Show the "Verified" badge on Forgejo for signed commits.
- Verify signatures locally (`git verify-commit`, `git log
  --show-signature`) with the same wrapper.

### Non-goals

- Protecting the signing key from sandboxed sessions (see
  [Accepted trade-off](#accepted-trade-off)).
- Passphrase-protected keys.
- A web of trust or any trust model beyond an allow-list of certificates
  (see R6).
- A general-purpose replacement for `gpg`.
- Pushing from a Claude Code session. Pushing needs a repository
  credential, so it is done by hand, outside Claude Code.

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
be set directly as `gpg.program`. Its documentation states that it requires
`gpg-agent`, which defeats the purpose of this plan. It is therefore ruled
out.

### 3.3 Decision

Use a thin wrapper script that implements the subset of the `gpg`
command-line interface that Git uses, and delegates signing and verification
to `sq` with keys and certificates supplied as files. The wrapper tested in
the experiment is
[`experiments/sq-signing-e2e/sq-gpg`](experiments/sq-signing-e2e/sq-gpg).

## 4. Requirements

### 4.1 The interface Git expects from `gpg.program`

Git invokes the configured program in two modes.

| Mode | Invocation | Stdin | Expected result |
|---|---|---|---|
| Sign | `gpg --status-fd=2 -bsau <keyid>` | Payload to sign | Armored detached signature on stdout; status line on the status fd; exit 0 |
| Verify | `gpg --keyid-format=long --status-fd=1 --verify <sigfile> -` | Signed payload | Status lines (`GOODSIG`, `VALIDSIG`, …) on the status fd |

Details for signing:

- The flags `-b`, `-s`, `-a` and `-u` arrive as one cluster, `-bsau`. The
  key ID is the next argument. Git passes `user.signingkey` through
  unchanged, including a trailing `!` if the user added one.
- The wrapper must print a line starting with `[GNUPG:] SIG_CREATED ` on the
  status fd. Git treats the signature as valid only if this line is present
  and the exit status is 0. Confirmed with Git 2.53.0.

### 4.2 Wrapper requirements

| ID | Requirement |
|---|---|
| R1 | Parse the `-bsau <keyid>` cluster, `-u`/`--local-user`, `--status-fd=N` (do not hardcode fd 2) and `--verify`. |
| R2 | Fail cleanly, without an unbound-variable error, if `-u` is the last argument. |
| R3 | Map the configured `user.signingkey` (a fingerprint, not a path) to a key file. Accept and strip a trailing `!`. |
| R4 | Sign with `sq`, writing an armored detached signature to stdout. |
| R5 | Print `SIG_CREATED` on the status fd only after `sq` exits 0. Do not use `exec sq`, which would leave the line printed on failure. |
| R6 | On `--verify`, verify with `sq verify` against the certificates in a cert directory, and emit `GOODSIG`/`VALIDSIG`/`TRUST_ULTIMATE` (good), `BADSIG` (known signer, verification failed) or `ERRSIG`/`NO_PUBKEY` (unknown signer) status lines. Every certificate in the directory is treated as ultimately trusted; the directory is the allow-list. The wrapper must never reach the signing path in verify mode. |
| R7 | On any failure, return a non-zero exit status and write diagnostics to stderr. |
| R8 | Make no network, socket or key-store access. |
| R9 | Exit non-zero without signing when the invocation is neither a sign nor a verify request. Unknown options within a sign or verify request are ignored. |

## 5. Design

### 5.1 Control flow

1. Parse arguments (R1, R2).
2. If `--verify` was given, run the verification path (R6) and stop.
3. If no sign flag was given, fail (R9).
4. Resolve the key file from the key ID (R3). Exit non-zero if the file is
   missing or unreadable.
5. Run `sq --home=none sign --signer-file <file> --signature-file=-` and
   capture the output (R4, R8).
6. If `sq` exits 0 and produced output, print the status line and then the
   signature (R5). Otherwise fail (R7).

The status line has the form
`[GNUPG:] SIG_CREATED D 22 10 00 <unix-timestamp> <fingerprint>`. The
algorithm numbers (`22` EdDSA, `10` SHA-512) are hard-coded. Git checks only
the `SIG_CREATED` prefix, so they matter only to other tools reading the
status output.

### 5.2 File locations

| What | Path | Override |
|---|---|---|
| Signing key | `~/.config/sq/git-signing/<FINGERPRINT>.pgp` | `SQ_GIT_SIGNING_KEYDIR` |
| Trusted certificates | `~/.config/sq/git-signing/certs/*.cert` | `SQ_GIT_CERTDIR` |

The key file is looked up by the upper-cased fingerprint from
`user.signingkey`. This supports several identities without changing the
wrapper. The file must contain the secret for the signing subkey only.

Both directories are readable but not writable inside the sandbox. A session
can therefore sign, but cannot add a certificate to the allow-list.

The wrapper itself must also be outside the sandbox's writable paths, like
the other scripts in this repository: installed as a reviewed copy, not run
from the checkout.

### 5.3 Git configuration

```ini
[gpg]
    program = <path to wrapper>
[user]
    signingkey = <subkey fingerprint>
[commit]
    gpgsign = true
```

Where this configuration lives is an [open item](#10-open-items): in the
global Git configuration it would also apply to commits made by hand.

## 6. Key management

The Claude signing key is a dedicated certificate, separate from the
personal GnuPG key, generated with `sq` as described in the
[`sq` calling manual](docs/sq-manual.md).

1. Generate a certificate with a signing subkey and no encryption or
   authentication subkeys. Give it a short expiry (6–12 months) and rotate
   it before expiry.
2. Store the full key (with the primary secret) and the revocation
   certificate offline.
3. Strip the primary secret and install the **signing subkey only** at the
   path in section 5.2, with mode `0600`.
4. Leave the subkey without a passphrase (`--without-password`). Git runs
   the wrapper with stdin piped, so a prompt would not work, and the
   accepted trade-off makes a passphrase pointless.
5. Install the public certificate in the cert directory.
6. Upload the public certificate to Forgejo. The commit author email must
   match a user ID on the certificate and be a verified email on the Forgejo
   account; otherwise the commit shows as unverified.

## 7. Migration

1. Install the wrapper, key and certificate; configure Git (section 5.3).
2. Run T5 and T6 with the real key in a real repository.
3. Remove `commit-bwrap.sh` and `push-bwrap.sh`, their `excludedCommands`
   entries and the skill text that refers to them.
4. Update [README.md](README.md), whose design is built around installing
   those two scripts.

## 8. Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Any process that can read the key file can sign, including every agent session. | Arbitrary content signed with the Claude key. | Accepted. The key is a separate identity that claims only "made in a Claude Code session". |
| Subkey leaks. | Forged signatures. No repository access. | Short expiry; revoke with the offline primary key. |
| A Git upgrade changes how it invokes `gpg.program`. | Signing breaks, possibly silently. | Add a hook or CI check that fails on unsigned commits. |
| An `sq` upgrade changes flags or output. The verify path parses `sq`'s human-readable output (`Authenticated signature made by`, `Issuer Fingerprint:`). | Verification misreports; signing fails. | Pin with `sq --cli-version`; re-run the test plan after upgrading. |
| The wrapper is invoked in an unexpected mode. | Wrong output, or signing when verification was requested. | R6, R9. |
| Rotating or revoking the key on Forgejo affects existing commits. | Old commits lose the "Verified" badge. | Unknown; test before the first rotation (T9). |

### Known limits

- A signature from an expired or revoked key in the cert directory is
  reported as `BADSIG` (`%G?` = `B`), where `gpg` would report `X`, `Y` or
  `R`.
- `VALIDSIG` carries placeholder dates and expiry; `BADSIG` reports the
  signer as `[unknown]`.
- The `SIG_CREATED` algorithm numbers are hard-coded (section 5.1).

## 9. Test plan

Run tests on a scratch repository with a throwaway key, except where noted.

| # | Test | Pass criteria | Status |
|---|---|---|---|
| T1 | Run the wrapper with Git's exact arguments and a sample payload. | Stdout is a valid detached signature (check with `sq verify` against the certificate); `SIG_CREATED` appears on the status fd; exit 0. | Passed |
| T2 | Point the wrapper at a missing key file. | Non-zero exit; no `SIG_CREATED`. | Passed |
| T3 | `git verify-commit` on a good commit, a tampered commit, and a commit whose signer's certificate is not in the cert directory. | Good: exit 0, `%G?` = `G`. Tampered: non-zero, `B`. Unknown signer: non-zero, `E`. No signing happens in any case. | Passed |
| T4 | `git commit -S`, then `git cat-file -p HEAD`. | The commit object contains a `gpgsig` header. | Passed |
| T5 | Repeat T4 inside the sandbox. | Succeeds with no sandbox violations. | Passed with isolated Git configuration; repeat with the real configuration and key |
| T6 | Push the commit to Forgejo. | Forgejo shows the "Verified" badge. | Open |
| T7 | Edge cases in argument handling: `-u` as the last argument; `user.signingkey` with a trailing `!`. | First: clean non-zero exit. Second: commit is signed. | Open |
| T8 | `git tag -s` and `git verify-tag`. | Tag is signed and verifies. | Open |
| T9 | Verify a commit signed by a subkey that has since expired, and one that has been revoked; check the same on Forgejo after uploading the updated certificate. | Behaviour is recorded and the rotation procedure is written down. | Open |

## 10. Open items

| ID | Item | How to resolve |
|---|---|---|
| O1 | Forgejo accepts signatures from the `sq`-generated certificate. | T6. |
| O2 | How Forgejo treats an updated, expired or revoked certificate, and what that does to badges on existing commits. | T9. |
| O3 | Where the Git configuration lives, so that only Claude Code sessions sign with the Claude key. | Decide, then verify by experiment. |

## 11. Future work

- Emit real dates and expiry in `VALIDSIG` and the signer's user ID in
  `BADSIG`; report expired and revoked keys with their own status lines.
- Add a pre-push hook or CI job that rejects unsigned commits.

## Links

- [`sq` calling manual](docs/sq-manual.md) (local reference for the commands above)
- [Experiment evidence](experiments/sq-signing-e2e/README.md) (signing and verification run end to end in the sandbox)
- <https://sequoia-pgp.org/>
- <https://gitlab.com/sequoia-pgp/sequoia>
- <https://github.com/anthropics/sandbox-runtime/blob/main/README.md>
- <https://github.com/containers/bubblewrap>
