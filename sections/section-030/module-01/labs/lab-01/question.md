# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** signing and verifying with sigstore-python

## Scenario

The build of `inventory-app` produces `/work/dist/app.tar.gz` in the `py-runner` pod (namespace `workstation`). The release team wants the build to sign its output with the service account `ci-bot`, and the deploy step to accept only files that `ci-bot` signed. Both steps are Python scripts, and neither exists yet.

`py-runner` runs as `ci-bot`, has sigstore-python 4.5.1, and has the token at `/var/run/sigstore/cosign/oidc-token` (audience `sigstore`). The client trust configuration of the private Sigstore stack is `/trust/trust_config.json`, and the cluster's token issuer is in `/trust/issuer`. `/work/dist/other.tar.gz` and its bundle were signed by the service account `intruder`.

```sh
kubectl -n workstation exec -it deploy/py-runner -- sh
```

## Your task

1. Write `/work/sign.py`. `python /work/sign.py FILE` signs `FILE` with the token of `ci-bot` and writes the bundle to `FILE.sigstore.json`.
2. Write `/work/verify.py`. `python /work/verify.py FILE BUNDLE` exits with code `0` only when `BUNDLE` is a valid signature of `FILE` by `https://kubernetes.io/namespaces/workstation/serviceaccounts/ci-bot` with the cluster's issuer, and with a non-zero code otherwise.

## Constraints

- Use the sigstore-python library or its `sigstore` command; sign against the private stack described by `/trust/trust_config.json`.
- Do not sign as any other service account.
- Do not change the files in `/work/dist` other than writing bundles.

## Done when

- `python /work/sign.py /work/dist/app.tar.gz` writes `/work/dist/app.tar.gz.sigstore.json`, and `cosign verify-blob` accepts it as `ci-bot` with the cluster's issuer.
- `python /work/verify.py /work/dist/app.tar.gz /work/dist/app.tar.gz.sigstore.json` exits with code `0`.
- `verify.py` exits with a non-zero code for a changed copy of `app.tar.gz` and for `other.tar.gz` with its bundle.
