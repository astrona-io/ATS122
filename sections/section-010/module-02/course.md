# Run Gitsign In Pipelines And Fix Signing Problems

Signing on a laptop works because a person can log in. A pipeline, a bot or a server has no browser and no person, so gitsign needs another way to get an identity token. It also needs a way to sign release tags, a way to check a whole history on every change, and a way to find the cause when a signing fails. This module covers those four jobs.

Keep one sentence in mind: **gitsign signs as whoever owns the identity token, so the token source decides the signer.**

The module has four parts. **Identity Token Providers** shows how gitsign gets a token without a browser and which settings control it. **Signing And Verifying Tags** signs a release tag and checks it with `gitsign verify-tag`; a graded lab follows it. **Verifying History In A Pipeline** turns the verification into a script that a pipeline can run and fail on. **Troubleshooting Gitsign** reads gitsign's log and finds the cause of the most common signing failures.

## Learning objectives

After this module you can:

- Name the gitsign token providers and say when each one fits.
- Sign a commit as a given service account by passing its token in an environment variable.
- Explain the identity a GitHub Actions workflow gets in its certificate.
- Sign an annotated tag, push it, and verify it with `gitsign verify-tag` and an expected identity.
- Write a pipeline script that verifies every commit in a range against an allowed identity pattern.
- Explain why commits made by a hosting service's merge button fail gitsign verification.
- Use `GITSIGN_LOG` to find why a signing failed.

## Before you start

You need to be able to configure Git for gitsign, make a signed commit and verify it with `gitsign verify`, and know what an identity token and a Fulcio certificate are. You also need Kubernetes basics (namespaces, service accounts, `kubectl exec`).

Your playground is a single-node `kind` cluster with a **private Sigstore stack**: Fulcio, Rekor and a certificate transparency (CT) log. In this stack, Fulcio accepts the cluster's own **service account tokens** as identity tokens, so every signer is a Kubernetes service account.

| Workload | What it is |
| --- | --- |
| `workstation` (namespace `workstation`) | The pod you work in. It runs as the service account `developer` and has `gitsign` v0.18.0, `cosign`, `rekor-cli`, `git`, `curl` and `jq` |
| Gitea (namespace `gitea`) | A Git server with the repository `gitops/inventory-app` |
| `/root/inventory-app` | A clone of `gitops/inventory-app` in the workstation, with a branch `demo/signed` that holds one signed commit |
| Service accounts `developer`, `ci-bot`, `intruder` | The identities you can sign as, by creating a token for each from your machine |

Open a shell in the workstation for the commands that say so; every command in the parts runs there unless the page says it runs on your machine:

```sh
kubectl -n workstation exec -it deploy/workstation -- sh
```

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
