# Release Checks In Python

One signed file is easy to verify. A release has many files, signed by more than one identity, and the check that gates it runs unattended in a pipeline. This module builds that check with sigstore-python: a policy that accepts a set of signers, a way to look inside a bundle when something is refused, error handling that reports every failure and tells the pipeline, and an understanding of how long tokens and certificates live.

Keep one sentence in mind: **a release check must look at every file, accept only the signers you named, and tell the pipeline when anything failed.**

The module has four parts. **Policies For More Than One Signer** combines `Identity` policies with `AnyOf` and `AllOf`; a graded lab follows it. **Inspecting A Bundle With jq And openssl** reads the certificate and the log entry inside a bundle. **Errors And Exit Codes In Automation** turns verification failures into one clear result for the pipeline. **Token And Certificate Lifetime** explains the short lives of identity tokens and Fulcio certificates.

## Learning objectives

After this module you can:

- Build a verification policy for several signers with `Identity`, `AnyOf` and `AllOf`.
- Read the signer, the issuer, the validity and the log entry from a bundle with `jq` and `openssl`.
- Write a release check that verifies every file, reports every failure and exits with a non-zero code.
- Explain how long an identity token and a Fulcio certificate live, and why an old bundle still verifies.

## Before you start

You need to read and run a short Python script and use `kubectl exec`. You should know what a Sigstore bundle is, and have signed and verified a file with sigstore-python.

Your playground is a single-node `kind` cluster with a **private Sigstore stack** and two pods in the namespace `workstation`: `py-runner`, with Python 3.13 and sigstore-python 4.5.1, and `workstation`, with `cosign`, `jq` and `openssl`. Both have the trust material of the stack in `/trust`.

The playground holds two release folders in `py-runner`:

| Folder | Content |
| --- | --- |
| `/work/release-good` | `app.tar.gz` signed by `ci-bot`, and `tools.tar.gz` signed by `developer` |
| `/work/release-bad` | Four files that fail: `a-changed.tar.gz` and `d-changed.tar.gz` changed after signing, `b-intruder.tar.gz` signed by `intruder`, and one valid file `c-ci.tar.gz` |

Each file has a bundle next to it, named like the file with `.sigstore.json` added.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
