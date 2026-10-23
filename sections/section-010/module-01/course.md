# Sign And Verify Git Commits With Gitsign

Git records an author and a committer on every commit, but it never checks them. You can set `user.email` to any address, commit, and push. So a commit that claims to come from a release engineer proves nothing on its own. A **commit signature** is a cryptographic signature over the commit's content that a reviewer can check later.

gitsign is a Git signing program from the Sigstore project. It signs **keylessly**: instead of a long-lived private key on your laptop, it creates a key for one signing, asks Fulcio (Sigstore's certificate authority) for a short-lived certificate that names you, and records the signing in Rekor (Sigstore's transparency log). Keep one sentence in mind: **the signature proves the content, and the certificate proves the signer.**

The module has three parts. **How Gitsign Signs A Commit** follows one signing from the identity token to the Rekor entry and shows where the signature sits in a commit. **Configuring Git To Sign With Gitsign** sets up a repository to sign every commit against a Sigstore instance; a graded lab follows it. **Verifying Who Signed A Commit** checks a signature and the signer's identity with `gitsign verify`.

## Learning objectives

After this module you can:

- Explain what a commit signature covers and where Git stores it.
- Describe the keyless signing flow: identity token, Fulcio certificate, signature, Rekor entry.
- Tell gitsign's online and offline Rekor modes apart.
- Configure Git and gitsign to sign every commit of one repository against a Sigstore instance.
- Verify a commit with `gitsign verify` and an expected identity and issuer.
- Explain why `git verify-commit` does not check who signed, and why GitHub shows gitsign commits as unverified.

## Before you start

You need Git basics (branch, commit, push, `git log`), Kubernetes basics (namespaces, service accounts, `kubectl exec`) and an idea of what an X.509 certificate is. You do not need to know Sigstore well.

Your playground is a single-node `kind` cluster with a **private Sigstore stack**: Fulcio, Rekor and a certificate transparency (CT) log, a log of every certificate Fulcio issues. In this stack, Fulcio accepts the cluster's own **service account tokens** as identity tokens, so every signer is a Kubernetes service account. Nothing you sign leaves your machine.

| Workload | What it is |
| --- | --- |
| `workstation` (namespace `workstation`) | The pod you work in. It runs as the service account `developer` and has `gitsign` v0.18.0, `cosign`, `git`, `curl` and `jq` |
| Gitea (namespace `gitea`) | A Git server with the repository `gitops/inventory-app` |
| `/root/inventory-app` | A clone of `gitops/inventory-app` in the workstation, with a branch `demo/signed` that holds one signed commit |

Open a shell in the workstation for the hands-on steps; every command in the parts runs there unless the page says otherwise:

```sh
kubectl -n workstation exec -it deploy/workstation -- sh
```

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
