# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** a release check with sigstore-python

## Scenario

A release is allowed to ship only when every file in its folder is signed by the service account `ci-bot` (application builds) or by `developer` (tools). A colleague wrote `/work/check_release.py` in the `py-runner` pod (namespace `workstation`) to check a folder. It is wrong in three ways: it refuses the developer's files, it stops at the first failure so later bad files are never reported, and it exits with code `0` even when files failed.

`py-runner` has sigstore-python 4.5.1. The client trust configuration of the private Sigstore stack is `/trust/trust_config.json`, and the cluster's token issuer is in `/trust/issuer`. There are two folders to try it on. Each file in them has a bundle next to it, named like the file with `.sigstore.json` added.

| Folder | Content |
| --- | --- |
| `/work/release-good` | `app.tar.gz` signed by `ci-bot`, and `tools.tar.gz` signed by `developer` |
| `/work/release-bad` | `a-changed.tar.gz` and `d-changed.tar.gz` (changed after signing), `b-intruder.tar.gz` (signed by `intruder`) and `c-ci.tar.gz` (valid, signed by `ci-bot`) |

```sh
kubectl -n workstation exec -it deploy/py-runner -- sh
```

## Your task

Fix `/work/check_release.py` so that `python /work/check_release.py FOLDER`:

1. Accepts files signed by `https://kubernetes.io/namespaces/workstation/serviceaccounts/ci-bot` and by `https://kubernetes.io/namespaces/workstation/serviceaccounts/developer`, with the cluster's issuer, and exits with code `0` for `/work/release-good`.
2. Checks every file of the folder and prints the name of every file that fails, so the output for `/work/release-bad` names all three bad files.
3. Exits with a non-zero code when any file fails, as it does for `/work/release-bad`.
4. Still refuses a file signed by any other service account.

## Constraints

- Use the sigstore-python library.
- Do not use `UnsafeNoOp` or any other policy that accepts every signer.
- Do not change the files or the bundles in `/work/release-good` and `/work/release-bad`.

## Done when

- The check exits with code `0` for `/work/release-good`.
- The check exits with a non-zero code for `/work/release-bad`, and its output names `a-changed.tar.gz`, `b-intruder.tar.gz` and `d-changed.tar.gz`.
- A folder that holds only `b-intruder.tar.gz` with its bundle is refused.
