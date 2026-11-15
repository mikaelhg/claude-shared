# Experiment: socket-less Git commit signing with `sq`

Evidence for [PLAN_SEQUOIA.md](../../PLAN_SEQUOIA.md). Date: 2026-11-15.
Environment: inside the bubblewrap sandbox (no Unix sockets), `sq` 1.3.1
(see `sq-version.txt`), git 2.53.0 (see `git-version.txt`).

## Result

A commit was signed through a wrapper around `sq` using a plain key file,
without `gpg-agent`, a key store or any socket. The same wrapper verifies
signatures, so `git verify-commit` and `git log --show-signature` work
locally: good signatures report `G`, a tampered commit `B`, and an unknown
signer `E`. Not tested: Forgejo's "Verified" badge.

## Files

| File | What it is |
|---|---|
| `sq-gpg` | The `gpg.program` wrapper under test (signing and verification). |
| `verify-tests.txt` | Transcript of the verification, tamper, unknown-signer and failure tests (section "Observations", item 3 onward). |
| `certs/` | Trusted certificate directory (`SQ_GIT_CERTDIR`): the test key's public cert. |
| `stranger-certs/`, `stranger-keys/`, `keys/stranger*.pgp` | A second, unrelated throwaway key, used for the unknown-signer and impostor tests. |
| `keys/full.pgp` | Throwaway key: secrets for primary and signing subkey. |
| `keys/signing/<subkey-fpr>.pgp` | Signing subkey only (primary secret stripped). This is the file the wrapper reads. |
| `keys/pub.cert` | Public certificate. |
| `keys/rev.pgp` | Revocation certificate. |
| `keys/primary.fpr`, `keys/subkey.fpr` | Fingerprints. |
| `repo-config.txt` | Repo-local git configuration used. |
| `commit-object.txt` | `git cat-file -p HEAD`: the signed commit, with `gpgsig`. |
| `repo-log.txt` | `git log --format='%H %G?' -1` for the signed commit: `G`. |
| `payload.txt`, `sig.asc` | Signed payload and signature extracted from the commit. |
| `sq-version.txt`, `git-version.txt` | Tool versions. |

**The keys are throwaway test keys with no passphrase. Never use them for
anything real.** The scratch repository itself is not included, only its
commit object.

## Procedure

Run from this directory. `SQ_GIT_SIGNING_KEYDIR` tells the wrapper where
key files live; the global and system git configs are disabled so the test
is isolated.

```bash
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export SQ_GIT_SIGNING_KEYDIR="$PWD/keys/signing"

# 1. Generate a key into a file (no home, key store or cert store).
sq --home=none --key-store=none --cert-store=none key generate \
  --userid 'Scratch Tester <scratch@example.invalid>' --own-key \
  --without-password --cannot-authenticate --cannot-encrypt \
  --expiration 6m --output keys/full.pgp --rev-cert keys/rev.pgp

# 2. Strip the primary key's secret; keep only the signing subkey.
sq --home=none --key-store=none key subkey delete \
  --cert-file keys/full.pgp --key <PRIMARY-FPR> \
  --output keys/signing/<SUBKEY-FPR>.pgp

# 3. Extract the public certificate.
sq --home=none key delete --cert-file=keys/full.pgp --output=keys/pub.cert

# 4. Create and configure a repository.
git init repo && cd repo
git config user.name  'Scratch Tester'
git config user.email 'scratch@example.invalid'
git config gpg.program "$OLDPWD/sq-gpg"
git config user.signingkey <SUBKEY-FPR>
git config commit.gpgsign true

# 5. Commit.
echo hello > f.txt && git add f.txt
git commit -m 'signed test commit'
git cat-file -p HEAD
```

## Observations

1. **Commit succeeded.** Exit 0; the commit object contains a `gpgsig`
   header (see `commit-object.txt`). This confirms git accepts the
   `[GNUPG:] SIG_CREATED ` status line plus exit 0 (assumption A4).
2. **Independent verification passed.** The signature extracted from the
   commit verified against `keys/pub.cert`:
   ```bash
   sq --home=none verify --signer-file keys/pub.cert \
     --signature-file sig.asc payload.txt
   ```
   Output: `Authenticated signature made by EDC7C2D0FF2BFA3E518FF378002F2E2A6FBEADBD`
   (the certificate), `1 authenticated signature.`, exit 0. The signature's
   issuer is the signing subkey (`4639DF91…41C3`).
3. **Missing key file fails cleanly.** With `SQ_GIT_SIGNING_KEYDIR` pointing
   at a nonexistent path: wrapper error `no readable key file`, git
   `fatal: failed to write commit object`, exit 128, no commit created.
4. **Local verification works** (wrapper `--verify`, using the certificates in
   `SQ_GIT_CERTDIR`; see `verify-tests.txt`):

   | Case | Git result |
   |---|---|
   | Commit signed by the trusted key | `gpg: Good signature from "Scratch Tester …"`, exit 0, `%G?` = `G`, with signer, key, fingerprint, primary fingerprint and trust (`ultimate`) populated |
   | Same commit with the message edited, `gpgsig` kept | `BAD signature`, exit 1, `%G?` = `B` |
   | Signer's cert not in the cert directory (only a stranger's cert, or none) | `Can't check signature: No public key`, exit 1, `%G?` = `E` |
   | Commit signed by the stranger, only the test cert trusted | `No public key`, exit 1, `%G?` = `E` |
   | Same stranger commit, stranger's cert trusted | `Good signature from "Stranger …"`, exit 0 |

5. **Signing still works with the verify code present.** A second and third
   signed commit were created and verified (`verify-tests.txt`).
6. **Fail-closed behaviour.** Unsupported invocations exit 2 with a message
   and sign nothing.
7. **No sockets needed.** All commands ran inside the sandbox, which does
   not allow Unix sockets.

## Trust model

Every certificate in `SQ_GIT_CERTDIR` is treated as ultimately trusted and
reported as `TRUST_ULTIMATE`. The directory is the allow-list: put only
certificates you accept there. There is no web of trust and no expiry-based
trust decision beyond what `sq verify` applies when checking the signature.

## Limits

- Forgejo verification (the "Verified" badge) was not tested.
- Run with isolated git configuration, not the user's real one.
- Passphrase-protected keys are out of scope.
- The `VALIDSIG` line carries placeholder dates and expiry (`1970-01-01 0 0`);
  git does not use them. Tools that read those fields would see wrong values.
- `BADSIG` reports the signer as `[unknown]`.
