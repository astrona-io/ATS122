# Prerequisites

Before starting this lab you should be able to:

- Write and run a short Python script.
- Explain what an identity token, a trust configuration and a bundle are.
- Copy files into a pod with `kubectl exec -i`.

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
- The **py-runner** pod in the namespace `workstation`: Python 3.13 with
  sigstore-python 4.5.1, running as the service account `ci-bot`. Its token is
  at `/var/run/sigstore/cosign/oidc-token`, the trust material is in `/trust`,
  and `/work` is a persistent volume with the build output in `/work/dist`.

## Working rules

- Everything is graded on the **final state**, so check your result at the end
  and leave it in place.
- Change one thing at a time and check again.
- The identity in a certificate comes from the token that signed it. A token of
  another service account gives another identity.
