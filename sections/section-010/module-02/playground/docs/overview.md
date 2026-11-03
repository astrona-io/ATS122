# Overview: Run Gitsign In Pipelines And Fix Signing Problems (Playground)

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

Paste these once in the shell. `verify_as` runs `gitsign verify` for one commit with an expected service account. `verify_tag_as` does the same for a tag. `show_token` prints the claims of the workstation's identity token.

```sh
ISSUER="$(cat /trust/issuer)"
verify_as() {
  gitsign verify --certificate-identity="https://kubernetes.io/namespaces/workstation/serviceaccounts/$1" \
    --certificate-oidc-issuer="$ISSUER" "$2"
}
verify_tag_as() {
  gitsign verify-tag --certificate-identity="https://kubernetes.io/namespaces/workstation/serviceaccounts/$1" \
    --certificate-oidc-issuer="$ISSUER" "$2"
}
show_token() {
  jq -R 'split(".")[1] | @base64d | fromjson' /var/run/sigstore/cosign/oidc-token
}
```

Use them like this: `verify_as developer origin/demo/signed`, `show_token`.

## Practice tasks

- Make a signed annotated tag with `git tag -s`, print it with `git cat-file tag`, and check it with `verify_tag_as developer` and `verify_tag_as ci-bot`.
- Sign a commit as `ci-bot` from your machine: create a token with `kubectl -n workstation create token ci-bot --audience sigstore`, pass it to the workstation as `SIGSTORE_ID_TOKEN` with `GITSIGN_TOKEN_PROVIDER=envvar`, and verify the commit with `--certificate-identity-regexp` for both service accounts.
- Create a token without `--audience sigstore`, use it to sign, and read the reason in the file named by `GITSIGN_LOG`.
- Point `GITSIGN_FULCIO_URL` at an address that does not exist, run one commit with `GITSIGN_LOG` set, and read the log.
- Write a loop over `git rev-list --first-parent origin/main..HEAD` that counts the commits that fail `gitsign verify`.
