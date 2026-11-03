# Question

Solve this question on: `terminal`

**Time:** about 20 minutes · **Topic:** signing and verifying release tags with gitsign

## Scenario

The `inventory-app` team is ready to ship version 1.0.0 and wants the release tag to be signed, so that a deploy step can prove who cut the release. The repository `/root/inventory-app` in the workstation pod already signs commits with gitsign against the private Sigstore stack. Tags are not signed yet: the existing tag `v0.9.0` is an unsigned annotated tag, and nothing makes new tags signed.

Open a shell in the workstation pod; it runs as the service account `developer`:

```sh
kubectl -n workstation exec -it deploy/workstation -- sh
```

Fulcio is at `http://fulcio-server.fulcio-system.svc` and Rekor at `http://rekor-server.rekor-system.svc`. The service account token is at `/var/run/sigstore/cosign/oidc-token`, and the cluster's token issuer is in `/trust/issuer`.

## Your task

In the repository `/root/inventory-app`:

1. Make Git sign every new tag in this repository, without the `-s` flag.
2. Create the annotated tag `v1.0.0` on the tip of `main`, signed by the service account `developer`.
3. Push the tag `v1.0.0` to Gitea.

## Constraints

- Use repository-local settings (`git config --local`), not global ones.
- Do not change, delete or re-create the tag `v0.9.0`.
- Do not change `main`.

## Done when

- `tag.gpgsign` is `true` in the local configuration of `/root/inventory-app`.
- Gitea has an annotated tag `v1.0.0` that points at the tip of `main`, and `gitsign verify-tag` with the identity `https://kubernetes.io/namespaces/workstation/serviceaccounts/developer` and the cluster's issuer accepts it.
- The tag `v0.9.0` in Gitea is the same unsigned tag as before.
