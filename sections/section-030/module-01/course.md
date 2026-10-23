# Sign And Verify From Python

A release pipeline written in Python needs to sign what it builds and check what it consumes. sigstore-python does both, from its `sigstore` command or from Python code. It needs three things to sign: an **identity token** that says who is signing, a **signing configuration** that names the Fulcio and Rekor to use, and a **trusted root** to check the results. To verify, it needs the trusted root and the identity you expect.

Keep one sentence in mind: **the token decides who signs, the trust configuration decides where, and the policy decides whom you accept.**

The module has three parts. **The sigstore-python Command Line** signs and verifies a file with the `sigstore` command against the private stack. **Signing And Verifying In Python Code** does the same from a script with the library; a graded lab follows it. **The Other Language Clients** covers the Sigstore clients for Java, JavaScript, Rust and Ruby, and what to check before you choose one.

## Learning objectives

After this module you can:

- Sign a file with `sigstore sign` and verify it with `sigstore verify identity`.
- Explain what a client trust configuration holds and use it with `--trust-config`.
- Explain why Fulcio needs the token audience `sigstore`.
- Sign a file from Python with `SigningContext`, `IdentityToken` and `sign_artifact`.
- Verify a file from Python with `Verifier`, `Bundle` and an `Identity` policy.
- Name the other Sigstore language clients and the checks to make before using one.

## Before you start

You need to read and run a short Python script, and know Kubernetes basics (service accounts, `kubectl exec`). You should know what a Sigstore bundle is: one JSON file with the signature, the signer's certificate and the transparency log proof.

Your playground is a single-node `kind` cluster with a **private Sigstore stack**: Fulcio (the certificate authority), Rekor (the transparency log) and a certificate transparency log. Fulcio accepts this cluster's Kubernetes service account tokens with the audience `sigstore` as identity tokens.

| Workload | What it is |
| --- | --- |
| `py-runner` (namespace `workstation`) | Python 3.13 with sigstore-python 4.5.1. It runs as the service account `ci-bot`; its token is at `/var/run/sigstore/cosign/oidc-token`. `/work` is a persistent volume with the build output `/work/dist/app.tar.gz` |
| `workstation` (namespace `workstation`) | `cosign` v3.1.4 and `jq`, to check bundles with a second tool |
| `/trust` (in both pods) | The trust material of the private stack: `trusted_root.json`, `signing_config.json`, `trust_config.json` and the issuer in `issuer` |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
