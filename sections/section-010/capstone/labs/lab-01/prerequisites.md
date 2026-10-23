# Prerequisites

Before starting this lab you should be able to:

- Configure git to sign commits with gitsign.
- Verify commits with `gitsign verify` and an expected identity.
- Rewrite the commits of a branch with `git rebase` and push it with `--force`.

## What the environment gives you

The environment builds itself before the task begins. It takes ten minutes or
more, because it starts a whole private Sigstore stack:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- A **private Sigstore stack** installed with the `scaffold` Helm chart 0.6.117:
  Fulcio at `http://fulcio-server.fulcio-system.svc`, Rekor (version 1) at
  `http://rekor-server.rekor-system.svc` and a certificate transparency log.
  Fulcio accepts this cluster's Kubernetes service account tokens as OIDC
  identity tokens.
- The **workstation** pod in the namespace `workstation`, running as the
  service account `developer`, with `cosign` v3.1.4, `gitsign` v0.18.0,
  `rekor-cli`, `git`, `curl` and `jq`. Its service account token is at
  `/var/run/sigstore/cosign/oidc-token`, and the trust material of the private
  stack is in `/trust`.
- **Gitea** in the namespace `gitea`, with the repository `gitops/inventory-app`
  at `http://gitea.localtest.me:3000/gitops/inventory-app.git` (lab-only user
  `gitops`, password `gitops-password`). A clone is at `/root/inventory-app` in
  the workstation pod, and git already has the credentials.
- The service account `intruder` in the namespace `workstation`. Its token is
  not mounted in any pod you use.

## Working rules

- Everything is graded on the **final state**, so check your result at the end
  and leave it in place.
- Change one thing at a time and check again.
- The identity in a certificate comes from the token that signed it. A token of
  another service account gives another identity.
