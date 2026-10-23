# Question

Solve this question on: `terminal`

**Time:** about 35 minutes · **Topic:** a Python release signing step

## Scenario

The release step of `inventory-app` runs in the `py-runner` pod (namespace `workstation`), as the service account `ci-bot`. `python /work/sign_release.py /work/release` should sign every file in the release folder, and `python /work/verify_release.py /work/release` should pass the folder only when every file is signed by `ci-bot`.

It does not work. The signing script stops before it signs anything. A colleague who got past that says cosign then rejects the bundles, and the check rejects the folder anyway. They suspect more than one fault.

```sh
kubectl -n workstation exec -it deploy/py-runner -- sh
```

`/work` is a persistent volume, so files there survive a restart of the pod. After a restart, the pod installs sigstore-python again, which takes a minute. The client trust configuration is `/trust/trust_config.json`, and the cluster's token issuer is in `/trust/issuer`.

## Your task

1. Find why `sign_release.py` fails, and fix the cause.
2. Find why its bundles do not verify, and fix the script.
3. Find why `verify_release.py` rejects a correctly signed folder, and fix the script.
4. Sign `/work/release`.

## Constraints

- Keep the signer: the service account `ci-bot`, with its token mounted in `py-runner`.
- Do not change the content of the files in `/work/release`.
- Keep the scripts' command-line interface: one argument, the folder.

## Done when

- The service account token mounted in `py-runner` has the audience `sigstore`.
- `python /work/sign_release.py /work/release` writes a bundle for every file, and `cosign verify-blob` accepts each one as `https://kubernetes.io/namespaces/workstation/serviceaccounts/ci-bot` with the cluster's issuer.
- `python /work/verify_release.py /work/release` exits with code `0`, and exits with a non-zero code for a copy of the folder in which one file changed.
