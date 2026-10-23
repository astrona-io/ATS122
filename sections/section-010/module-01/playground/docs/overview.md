# Overview: Sign And Verify Git Commits With Gitsign (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with a private Sigstore stack, a Git server and a workstation pod, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- A **private Sigstore stack**: Fulcio, Sigstore's certificate authority, at `http://fulcio-server.fulcio-system.svc`; Rekor, Sigstore's transparency log, at `http://rekor-server.rekor-system.svc`; and a certificate transparency log. Fulcio accepts this cluster's Kubernetes service account tokens, with the audience `sigstore`, as identity tokens.
- The **workstation** pod in the namespace `workstation`. It runs as the service account `developer` and has `gitsign` v0.18.0, `cosign` v3.1.4, `rekor-cli`, `git`, `curl` and `jq`. Its identity token is at `/var/run/sigstore/cosign/oidc-token`, and the trust material of the private stack is in `/trust`. It sets `GITSIGN_REKOR_MODE=offline` and the trust variables `GITSIGN_FULCIO_ROOT`, `SIGSTORE_REKOR_PUBLIC_KEY` and `SIGSTORE_CT_LOG_PUBLIC_KEY_FILE`.
- **Gitea** in the namespace `gitea`, with the repository `gitops/inventory-app` at `http://gitea.localtest.me:3000/gitops/inventory-app.git`. The lab-only user is `gitops` with the password `gitops-password`.
- A clone at `/root/inventory-app` in the workstation, with the branch `demo/signed` that holds one commit signed by `developer`. The clone has no signing settings yet.

## Helpers

Open a shell in the workstation; every helper and task below runs there:

```sh
kubectl -n workstation exec -it deploy/workstation -- sh
```

Paste these once in the shell. `verify_as` runs `gitsign verify` for one commit with an expected service account. `show_token` prints the claims of the workstation's identity token.

```sh
ISSUER="$(cat /trust/issuer)"
verify_as() {
  gitsign verify --certificate-identity="https://kubernetes.io/namespaces/workstation/serviceaccounts/$1" \
    --certificate-oidc-issuer="$ISSUER" "$2"
}
show_token() {
  jq -R 'split(".")[1] | @base64d | fromjson' /var/run/sigstore/cosign/oidc-token
}
```

Use them like this: `verify_as developer origin/demo/signed`, `show_token`.

## Practice tasks

- Print `git cat-file commit origin/demo/signed` and `git cat-file commit origin/main` and find the `gpgsig` header.
- Run `verify_as developer origin/demo/signed`, then `verify_as ci-bot origin/demo/signed`, and compare the results and the exit codes.
- Configure the clone to sign with gitsign against the private stack, make a commit, and check it with `gitsign --version` and `verify_as`.
- Set `GITSIGN_REKOR_MODE=online` for one commit and compare the `gpgsig` header with an offline-mode commit.
- Make one commit with `git -c commit.gpgsign=false commit` and check it in a loop over `git rev-list origin/main..HEAD`.
