# Question

Solve this question on: `terminal`

**Time:** about 30 minutes · **Topic:** verifying and re-signing Git commits

## Scenario

The branch `release/1.0` of `inventory-app` has four commits after `main`. Before the release, the team checks that every commit on it is signed by the service account `developer`. The check fails. Someone made one commit without a signature, and one commit was signed by the service account `intruder`. On top of that, the clone in the workstation lost its signing settings.

Open a shell in the workstation pod; it runs as the service account `developer`:

```sh
kubectl -n workstation exec -it deploy/workstation -- sh
```

The clone is at `/root/inventory-app`, Fulcio is at `$FULCIO_URL`, Rekor at `$REKOR_URL`, and the cluster's issuer is in `/trust/issuer`.

## Your task

1. Find which commits on `release/1.0` after `main` are not signed by `https://kubernetes.io/namespaces/workstation/serviceaccounts/developer`.
2. Configure `/root/inventory-app`, for this repository only, to sign every commit with gitsign against the private Fulcio and Rekor, with the token from the file.
3. Make every commit on `release/1.0` signed by `developer`, and push the branch to Gitea.

## Constraints

- Keep the four commits: the same number, the same messages in the same order, and the same files at the end of the branch.
- Do not change `main`.
- Do not sign as any other service account.

## Done when

- `gitsign verify` with the `developer` identity and the cluster's issuer passes for every commit on `release/1.0` after `main` in Gitea.
- `release/1.0` in Gitea has four commits after `main`, with the original messages in the original order and the original final files.
- The repository-local settings of `/root/inventory-app` sign with gitsign: `gpg.format` `x509`, `gpg.x509.program` `gitsign`, `commit.gpgsign` `true`, `gitsign.fulcio`, `gitsign.rekor` and `gitsign.tokenProvider` `filesystem`.
