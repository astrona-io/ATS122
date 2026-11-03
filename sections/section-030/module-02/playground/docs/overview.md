# Overview: Release Checks In Python (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with a private Sigstore stack, a workstation pod and a Python pod, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- A **private Sigstore stack**: Fulcio (the certificate authority), Rekor (the transparency log) and a certificate transparency log. Fulcio accepts this cluster's Kubernetes service account tokens with the audience `sigstore` as identity tokens.
- The **py-runner** pod in the namespace `workstation`: Python 3.13 with sigstore-python 4.5.1 and its `sigstore` command. It runs as the service account `ci-bot`, and its token is at `/var/run/sigstore/cosign/oidc-token`. `/work` is a persistent volume; the release folders to check are `/work/release-good` and `/work/release-bad`.
- The **workstation** pod, with `cosign` v3.1.4, `jq` and `openssl`, to read bundles and check them with a second tool.
- The trust material in `/trust` in both pods: `trusted_root.json`, `signing_config.json`, `trust_config.json` and the issuer in `issuer`.

## Helpers

Paste these once in each new terminal on your machine. `pyrun` runs a command in py-runner. `ws` runs a command in the workstation. `put_file` copies a file from your machine into a pod.

```sh
pyrun() { kubectl -n workstation exec -i deploy/py-runner -- "$@"; }
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
put_file() { kubectl -n workstation exec -i "deploy/$1" -- sh -c "cat > '$3'" < "$2"; }
```

Use them like this: `pyrun sigstore --version`, `put_file py-runner sign.py /work/sign.py`.

## The release folders

| Folder | Content |
| --- | --- |
| `/work/release-good` | `app.tar.gz` signed by `ci-bot`, and `tools.tar.gz` signed by `developer` |
| `/work/release-bad` | `a-changed.tar.gz` and `d-changed.tar.gz`, changed after signing; `b-intruder.tar.gz`, signed by `intruder`; and `c-ci.tar.gz`, a valid file signed by `ci-bot` |

Each file has a bundle next to it, named like the file with `.sigstore.json` added.

## Practice tasks

- Write a check that verifies every file of a folder with `AnyOf` for `developer` and `ci-bot`, and run it on both folders.
- Make the check fail on purpose in three ways: add `break` to the loop, return `0` at the end, and narrow the policy to `ci-bot`. Which folder shows each fault?
- Copy a bundle to the workstation and print the signer with `openssl x509 -inform DER -noout -ext subjectAltName`.
- Compare `integratedTime` of a bundle with the `notBefore` and `notAfter` dates of its certificate.
- Print the `exp` claim of the token in py-runner and watch the seconds left fall.
