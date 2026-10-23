# Question

Solve this question on: `terminal`

**Time:** about 20 minutes · **Topic:** signing Git commits with gitsign

## Scenario

The team behind `inventory-app` wants every commit to be signed, and the signatures to come from the private Sigstore stack in the cluster, never from the public instance. The workstation pod has a clone of the repository at `/root/inventory-app`, but the clone signs nothing yet.

Open a shell in the workstation pod; it runs as the service account `developer`:

```sh
kubectl -n workstation exec -it deploy/workstation -- sh
```

Fulcio is at `http://fulcio-server.fulcio-system.svc` and Rekor at `http://rekor-server.rekor-system.svc`; the shell has them in `$FULCIO_URL` and `$REKOR_URL`. The service account token is at `/var/run/sigstore/cosign/oidc-token`.

## Your task

In the repository `/root/inventory-app`:

1. Configure Git, for this repository only, to sign every commit with gitsign, without the `-S` flag.
2. Configure gitsign, for this repository only, to use the private Fulcio and Rekor and to read the identity token from the file.
3. Create the branch `feature/signed` from `main`, make at least two commits on it, and push it to Gitea.

## Constraints

- Use repository-local settings (`git config --local`), not global ones.
- Every commit on `feature/signed` after `main` must be signed by the service account `developer`.
- Do not change `main`.

## Done when

- The repository-local settings of `/root/inventory-app` are: `gpg.format` `x509`, `gpg.x509.program` `gitsign`, `commit.gpgsign` `true`, `gitsign.fulcio` the Fulcio address above, `gitsign.rekor` the Rekor address above, and `gitsign.tokenProvider` `filesystem`.
- `feature/signed` in Gitea has at least two commits after `main`, and `gitsign verify` with the identity `https://kubernetes.io/namespaces/workstation/serviceaccounts/developer` and the cluster's issuer passes for each of them.
