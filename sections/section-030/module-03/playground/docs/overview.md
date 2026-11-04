# Overview: GitHub Workflow Policies And Other Clients (Playground)

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

## The policy script

`/work/policy_check.py` builds one policy from the signers in `/work/signers.json` and checks a release folder with it. `python /work/policy_check.py print-policy` prints one line per signer: the kind, the identity and the issuer. `python /work/policy_check.py verify FOLDER` verifies every `.tar.gz` file of a folder. The signers file lists a GitHub workflow, `acme/inventory-app` with `release.yml` on `refs/tags/v1.0.0`, and the service account `ci-bot`. Nothing in this cluster signs as a GitHub workflow, so the GitHub signer only shows how the policy is built.

## The release folders

| Folder | Content |
| --- | --- |
| `/work/release-good` | `app.tar.gz` and `c-ci.tar.gz`, signed by `ci-bot` |
| `/work/release-bad` | `a-changed.tar.gz`, changed after signing; `b-intruder.tar.gz`, signed by `intruder`; and `c-ci.tar.gz`, a valid file signed by `ci-bot` |

Each file has a bundle next to it, named like the file with `.sigstore.json` added.

## Practice tasks

- Run `print-policy` and compare the GitHub line with the subject alternative name of a certificate in a bundle from the folder.
- Set `SIGNERS_FILE` to a copy of the signers file with `refs/heads/main` and watch the identity change.
- Add a second GitHub signer for a different workflow file and check that the good folder is still accepted.
- Change `AnyOf` to `AllOf` in the script and find which folder breaks.
- Verify a file with `sigstore --trust-config /trust/trust_config.json verify identity` and with `cosign verify-blob`, and compare the results.
- Print `sigstore verify github --help` and list the options that have no counterpart in `verify identity`.
