# Verify Sigstore Bundles From Go

A Sigstore signature of a file comes as a **bundle**: one JSON file with the signature, the certificate that names the signer, and the proof that the signing is in the transparency log. Any program that consumes signed files has to check that bundle before it trusts the file. Doing that check right takes several steps, and skipping one of them is the most common way a "verified" pipeline lets bad files through.

sigstore-go is the Sigstore project's Go library for signing and verifying bundles. Keep one sentence in mind: **a verifier answers two questions, "is this signature valid?" and "is the signer the one I expect?", and it must refuse the file when either answer is no.**

The module has two parts. **What A Verifier Checks** takes a bundle and a trusted root apart and lists every check a verifier makes, using `cosign verify-blob` as the reference. **Writing A Verifier With sigstore-go** builds a small Go program that makes the same checks; a graded lab follows it.

## Learning objectives

After this module you can:

- Name the parts of a Sigstore bundle and of a trusted root.
- List the checks a verifier makes, and say which component's key or certificate each one uses.
- Load a trusted root and a bundle with sigstore-go.
- Build a sigstore-go verifier with thresholds for certificate transparency, the transparency log and timestamps.
- Write a policy that requires both the artifact and the expected signer identity.
- Make a verifier fail with a non-zero exit code when any check fails.

## Before you start

You need to read a short Go program and know what `go build` does. You also need Kubernetes basics (`kubectl exec`) and an idea of what an X.509 certificate is. You do not need to have written Go with sigstore-go before.

Your playground is a single-node `kind` cluster with a **private Sigstore stack**: Fulcio (the certificate authority), Rekor (the transparency log) and a certificate transparency log. Fulcio accepts this cluster's Kubernetes service account tokens as identity tokens, so every signer is a service account.

| Workload | What it is |
| --- | --- |
| `workstation` (namespace `workstation`) | `cosign`, `jq` and `openssl`; the example files and their bundles are in `/tmp/data` |
| `go-runner` (namespace `workstation`) | Go 1.25 with the module `/work/verify-blob` (sigstore-go v1.3.0) and the same files in `/work/data` |
| `/trust` (in both pods) | The trust material of the private stack, including `trusted_root.json`, and the issuer in `issuer` |

The example files are `release.txt` (signed by the service account `developer`), `release-tampered.txt` (a changed copy that has no bundle of its own) and `other.txt` (signed by the service account `intruder`).

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
