# Signer Policies And Verification Results

A verifier that checks the signature but not the signer protects nothing, and a verifier that checks the signer too strictly breaks the release pipeline. Real systems have more than one trusted signer: a developer signs a hotfix, a CI service account signs the nightly build, and an auditor signs nothing. This module is about the policy half of sigstore-go: how to say which signers you accept, how to read what the verifier proved, which trust material it used, and how the verifier knows which file the bundle belongs to.

Keep one sentence in mind: **a verifier proves only what its policy asks for, so the policy is the security decision.**

The module has four parts. **Matching Signers With Regular Expressions** builds a policy that accepts a group of signers and nobody else; a graded lab follows it. **Reading The Verification Result** shows what the verifier returns after it accepts a file. **Trusted Roots And Validity Windows** explains what the trusted root holds and why a bundle can stop verifying. **Artifact Policies** covers the three ways to tell the verifier which file the bundle is about.

## Learning objectives

After this module you can:

- Write a certificate identity policy with exact values and with regular expressions.
- Anchor a regular expression so it matches exactly the signers you intend.
- Read the signer, the issuer and the trusted times from a verification result.
- Describe the parts of a trusted root and how validity windows affect a verification.
- Choose between verifying a file, verifying a digest and skipping the artifact check.

## Before you start

You need to read a short Go program that loads a trusted root and a bundle and verifies them against a policy, as in the earlier module of this section, and to read simple regular expressions. The first part gives you the full program.

Your playground is the same single-node `kind` cluster with a private Sigstore stack. The Go pod `go-runner` has the module `/work/verify-blob` (sigstore-go v1.3.0), and the example files are in `/work/data` there and in `/tmp/data` in the `workstation` pod.

| File | Signed by |
| --- | --- |
| `release.txt` | The service account `developer` |
| `ci-build.txt` | The service account `ci-bot` |
| `other.txt` | The service account `intruder` |
| `release-tampered.txt` | Nobody; it is a changed copy of `release.txt`, and it has no bundle of its own |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
