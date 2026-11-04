# GitHub Workflow Policies And Other Clients

Most signatures that a team verifies in practice do not come from a person. They come from a workflow that runs on a CI system, and the name in the certificate is the code that ran. This module shows what the certificate of a GitHub Actions workflow holds, how to write a policy that accepts exactly the workflows you trust, how to pin the Git reference and the repository so a pull request cannot sign a release, and how the same policy looks in the other Sigstore language clients.

Keep one sentence in mind: **a workflow policy names a workflow file, a Git reference and the GitHub issuer, and anything looser accepts code nobody reviewed.**

The module has five parts. **The GitHub Actions Certificate** reads the identity and the extensions that Fulcio puts in a certificate for a workflow. **Writing A Workflow Policy** builds the policy in sigstore-python; a graded lab follows it. **Pinning Workflows And References** covers tags, branches, reusable workflows and pull requests. **Clients For JavaScript And Java** shows the verification call of sigstore-js and sigstore-java. **Clients For Rust And Ruby** covers the last two clients and the tests that keep all clients compatible.

## Learning objectives

After this module you can:

- Name the OIDC issuer, the identity and the extensions of a GitHub Actions certificate.
- Write a policy that accepts one workflow at one Git reference, and a set of such workflows.
- Choose between a branch, a tag and a reusable workflow when you pin a signer, and explain what a pull request can sign.
- Write the same verification in sigstore-js and sigstore-java, and say what the Rust and Ruby clients offer.
- Check one bundle with two tools to find out whether a failure comes from the bundle or from the policy.

## Before you start

You need to read and run a short Python script and use `kubectl exec`. You should know what a Sigstore bundle, a certificate identity and an OIDC issuer are, and have verified a file with `sigstore verify identity`.

Your playground is a single-node `kind` cluster with a **private Sigstore stack** and two pods in the namespace `workstation`: `py-runner`, with Python 3.13 and sigstore-python 4.5.1, and `workstation`, with `cosign`, `jq` and `openssl`. Both have the trust material of the stack in `/trust`.

No GitHub Actions job signs in this cluster, so no file in the playground has a GitHub certificate. The playground holds what you need to practise the policy: `/work/policy_check.py`, which builds a policy from `/work/signers.json` (one GitHub workflow and the service account `ci-bot`), and two release folders signed by service accounts.

| Folder | Content |
| --- | --- |
| `/work/release-good` | `app.tar.gz` and `c-ci.tar.gz`, signed by `ci-bot` |
| `/work/release-bad` | `a-changed.tar.gz` changed after signing, `b-intruder.tar.gz` signed by `intruder`, and one valid file `c-ci.tar.gz` |

Each file has a bundle next to it, named like the file with `.sigstore.json` added.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
