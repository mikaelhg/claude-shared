# `sq` calling manual (socket-less signing)

Quick reference for the `sq` (Sequoia PGP) commands used by the signing
wrapper described in [PLAN_SEQUOIA.md](../PLAN_SEQUOIA.md).

- **Tested against:** `sq` 1.3.1 (sequoia-openpgp 2.1.0, Nettle backend).
- **How it was tested:** commands were run inside the sandbox with a
  throwaway key in a scratch directory. Flags were read from `sq <command> --help`. The key-generation,
  signing, verification and subkey-stripping commands in sections 2 to 5 were
  run successfully. Passphrase-protected keys and Git integration were
  **not** tested.
- Flags can change between versions. Re-check with `sq <command> --help`
  after upgrading, or pin the CLI with `--cli-version` (see section 1).

## 1. Global options for socket-less use

Global options go before the subcommand.

| Option | Meaning |
|---|---|
| `--home none` | Do not use a home directory. Also reads `SEQUOIA_HOME`. |
| `--key-store none` | Do not use a key store (the key-store server is the component that normally runs as a background process). Also reads `SEQUOIA_KEY_STORE`. |
| `--cert-store none` | Do not use a certificate store. Also reads `SEQUOIA_CERT_STORE`. |
| `--overwrite` | Overwrite existing output files. Without it `sq` refuses. |
| `--time <TIME>` | Set the reference time (ISO 8601). Affects signature creation time and key validity checks. |
| `--cli-version <X.Y.Z>` | Fail if the installed CLI is not compatible with this version. Must be the first option. |

Default for all commands in this manual: use `--home=none`. Add
`--key-store=none --cert-store=none` for commands that would otherwise touch
the stores (key generation, key editing).

## 2. Generate a key into a file

```bash
sq --home=none --key-store=none --cert-store=none key generate \
  --userid 'Name <you@example.org>' --own-key --without-password \
  --cannot-authenticate --cannot-encrypt --expiration 6m \
  --output key.pgp --rev-cert rev.pgp
```

| Option | Meaning |
|---|---|
| `--userid`, `--name`, `--email` | User ID(s). The email must match the Forgejo account email. One of these (or `--no-userids`) is required. |
| `--own-key` / `--shared-key` | Required; marks trust metadata. Use `--own-key` for a personal key. |
| `--without-password` | Leave secret key material unencrypted. |
| `--new-password-file <FILE>` | Encrypt secrets with the password in FILE (the whole file is the password, including a trailing newline). |
| `--can-sign` / `--cannot-sign` | Include a signing subkey. Default: yes. |
| `--cannot-authenticate`, `--cannot-encrypt` | Omit the authentication and encryption subkeys. Not needed for commit signing. |
| `--expiration <D>` | Expiry as `N[ymwds]`, an ISO 8601 date, or `never`. Default: `3y`. |
| `--cipher-suite` | `cv25519` (default), `rsa2k`, `rsa3k`, `rsa4k`. |
| `--profile` | `rfc4880` (v4, default in 1.3.1) or `rfc9580` (v6). Use `rfc4880` for broad compatibility, including Forgejo. |
| `--output <FILE>` | Write the key to FILE instead of the key store. |
| `--rev-cert <FILE>` | Write the emergency revocation certificate to FILE. Required alongside `--output`, and must differ from it. |

Result: `key.pgp` holds secret key material for the **primary key
(certification)** and the **signing subkey**. `rev.pgp` is the revocation
certificate; store it offline.

## 3. Prepare the files

### 3.1 Strip the primary key's secret (keep the signing subkey only)

```bash
sq --home=none --key-store=none key subkey delete \
  --cert-file key.pgp --key <PRIMARY-FINGERPRINT> --output signkey.pgp
```

Keep `signkey.pgp` on the machine that signs. Store `key.pgp` offline.
Find fingerprints with `sq --home=none inspect key.pgp`.

### 3.2 Extract the public certificate (for Forgejo)

```bash
sq --home=none key delete --cert-file=key.pgp --output=key.cert
```

This removes all secret key material and writes the certificate. Upload
`key.cert` (armored) to Forgejo.

### 3.3 Inspect a key file

```bash
sq --home=none inspect signkey.pgp
```

Check that only the signing subkey shows `Secret key: Unencrypted` (or
`Encrypted`), and that the key flags are as expected.

## 4. Sign (what the wrapper runs)

```bash
sq --home=none sign --signer-file signkey.pgp --signature-file=- \
  < payload > sig.asc
```

| Option | Meaning |
|---|---|
| `--signer-file <PATH>` | Read the signing key from PATH. |
| `--signature-file <SIG>` | Create a **detached** signature. `-` means stdout. This is the mode Git needs. |
| `--message` / `--cleartext` | Inline-signed or cleartext-signed output. Not used for Git. |
| `[FILE]` | Positional input. Default `-` (stdin). |
| `--binary` | Emit binary instead of armored output. Git needs armored, so do **not** use it. |
| `--mode binary\|text` | Signature mode. Default `binary`; keep it for Git. |
| `--signer <FPR\|KEYID>` | Select a key from the key store. Not applicable with `--signer-file` and no store. |
| `--output <FILE>` | Output file for message modes. Detached signatures use `--signature-file`. |
| `--signature-notation <NAME> <VALUE>` | Add a signature notation. Not needed. |

Exit status 0 means success. On failure `sq` exits non-zero and writes
diagnostics to stderr. The wrapper must print `[GNUPG:] SIG_CREATED ` only
after exit 0.

Observed output: an armored v4 detached signature
(`-----BEGIN PGP SIGNATURE-----`) whose Issuer Fingerprint is the signing
subkey.

## 5. Verify (what the wrapper's `--verify` path runs)

```bash
sq --home=none verify --signer-file key.cert --signature-file sig.asc payload
```

| Result | Output | Exit |
|---|---|---|
| Valid | `1 authenticated signature.` | 0 |
| Payload changed | `Verification failed: could not authenticate any signatures` | 1 |

`--signer-file` here takes the **certificate** (public). Other signer
selectors exist (`--signer`, `--signer-userid`, `--signer-email`,
`--signer-domain`) but need a certificate store.

## 6. Key lifecycle (key store required)

These commands work on keys in the key store, so they are not socket-less.
Run them on the offline or admin machine, not inside the sandbox.

| Task | Command |
|---|---|
| Add a signing subkey to an existing cert | `sq key subkey add --cert <FPR> --can-sign --expiration 6m` |
| Export one subkey's secret | `sq key subkey export --cert <FPR> --key <SUBKEY-FPR> --output signkey.pgp` |
| Change a subkey's expiry | `sq key subkey expire --cert <FPR> --key <SUBKEY-FPR> --expiration 6m` (check `--help`) |
| Revoke a subkey | `sq key subkey revoke ...` (check `--help`) |
| Delete a subkey's secret | `sq key subkey delete --cert <FPR> --key <SUBKEY-FPR>` |
| Change a key's password | `sq key password ...` (check `--help`) |

The expire, revoke and password rows are listed in `sq key --help` and
`sq key subkey --help`, but their flags were not read in detail; confirm them
with `--help` before use.

## 7. Known gaps

- Passphrases: out of scope. Signing keys here are passphrase-less
  (`--without-password`), which is the only mode tested.
- Git integration: no test of the wrapper with `git commit -S`.

## 8. Socket-freedom

The commands in sections 2 to 5 were run inside the bubblewrap sandbox, which
does not allow Unix sockets, and they succeeded with `--home=none`. They
therefore do not need sockets. No `strace` trace was taken, and none is
needed: working inside the sandbox is the measure that matters here.
