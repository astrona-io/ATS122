# Pin A GitHub Workflow In The Release Policy

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** a verification policy for a GitHub Actions workflow

## Scenario

The release of the `inventory-app` is signed by two kinds of signer: the GitHub Actions workflow `release.yml` of the repository `acme/inventory-app`, which signs release tags, and the service account `ci-bot`, which signs nightly builds. A colleague wrote `/work/policy_check.py` in the `py-runner` pod (namespace `workstation`) to build one policy from the list of signers in `/work/signers.json` and to verify a release folder with it. The policy is wrong in three ways: the identity it builds for the GitHub signer is not a workflow reference, the issuer it uses for the GitHub signer is not the GitHub Actions issuer, and the policy demands that every signer signed every file.

`py-runner` has sigstore-python 4.5.1. The client trust configuration of the private Sigstore stack is `/trust/trust_config.json`, and the cluster's token issuer is in `/trust/issuer`. No GitHub job signs in this cluster, so the folders hold only files signed by service accounts. The task is about the policy, which you can read with `print-policy`.

| Folder | Content |
| --- | --- |
| `/work/release-good` | `app.tar.gz` and `c-ci.tar.gz`, both signed by `ci-bot` |
| `/work/release-bad` | `a-changed.tar.gz` (changed after signing), `b-intruder.tar.gz` (signed by `intruder`) and `c-ci.tar.gz` (valid, signed by `ci-bot`) |

```sh
kubectl -n workstation exec -it deploy/py-runner -- sh
```

## Your task

Fix `/work/policy_check.py` so that:

1. `python /work/policy_check.py print-policy` prints, for the GitHub signer, a line whose second field is the full workflow reference `https://github.com/acme/inventory-app/.github/workflows/release.yml@refs/tags/v1.0.0`. The reference is built from the `repository`, `workflow` and `ref` fields of the signer.
2. The third field of that line is the GitHub Actions issuer, `https://token.actions.githubusercontent.com`.
3. The `ref` of the signer is part of the identity: with `refs/heads/main` in the signers file the identity ends with `@refs/heads/main`. The script reads the file named in the environment variable `SIGNERS_FILE`.
4. `python /work/policy_check.py verify /work/release-good` exits with code `0`, and `verify /work/release-bad` exits with a non-zero code and names `a-changed.tar.gz` and `b-intruder.tar.gz`.

## Constraints

- Use the sigstore-python library.
- Do not use `UnsafeNoOp` or any other policy that accepts every signer.
- Do not change `/work/signers.json` or the files and bundles in the two folders.

## Done when

- The `print-policy` line for the GitHub signer shows the full workflow reference and the GitHub Actions issuer.
- The ref in the identity follows the ref in the signers file.
- The good folder is accepted, and the bad folder is refused with both bad files named.
