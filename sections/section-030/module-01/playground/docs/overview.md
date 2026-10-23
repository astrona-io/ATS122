# Overview: Sign And Verify From Python (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with a private Sigstore stack, a workstation pod and a Python pod, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- A **private Sigstore stack**: Fulcio (the certificate authority), Rekor (the transparency log) and a certificate transparency log. Fulcio accepts this cluster's Kubernetes service account tokens with the audience `sigstore` as identity tokens.
- The **py-runner** pod in the namespace `workstation`: Python 3.13 with sigstore-python 4.5.1 and its `sigstore` command. It runs as the service account `ci-bot`, and its token is at `/var/run/sigstore/cosign/oidc-token`. `/work` is a persistent volume; the build output to sign is `/work/dist/app.tar.gz`.
- The **workstation** pod, with `cosign` v3.1.4 and `jq`, to check bundles with a second tool.
- The trust material in `/trust` in both pods: `trusted_root.json`, `signing_config.json`, `trust_config.json` and the issuer in `issuer`.

## Helpers

Paste these once in each new terminal on your machine. `pyrun` runs a command in py-runner. `ws` runs a command in the workstation. `put_file` copies a file from your machine into a pod.

```sh
pyrun() { kubectl -n workstation exec -i deploy/py-runner -- "$@"; }
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
put_file() { kubectl -n workstation exec -i "deploy/$1" -- sh -c "cat > '$3'" < "$2"; }
```

Use them like this: `pyrun sigstore --version`, `put_file py-runner sign.py /work/sign.py`.

## Practice tasks

- Sign `/work/dist/app.tar.gz` with `sigstore sign` and verify it with `sigstore verify identity` as `ci-bot`, then as `developer`.
- Copy the file and its bundle to the workstation with `pyrun cat ... | ws sh -c 'cat > ...'` and verify them with `cosign verify-blob --trusted-root /trust/trusted_root.json`.
- Sign once with the `--identity-token` option left out and read the error.
- Write a script that signs every file in a folder inside one `signer` block, and count how many certificates the signing needed.
- In a verification script, change the `Identity` issuer to `https://oauth2.sigstore.dev/auth` and see what the error says.
