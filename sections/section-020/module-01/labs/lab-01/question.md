# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** verifying Sigstore bundles with sigstore-go

## Scenario

A colleague wrote `verify-blob`, a Go program with sigstore-go that a release step will use to decide whether a file may ship. In a quick test it said `VERIFIED` for every file, so it looked fine. It is not: it accepts a file signed by anyone, and it never fails.

The program is `/work/verify-blob/main.go` in the `go-runner` pod (namespace `workstation`). The test files are in `/work/data` there, and the trusted root of the private Sigstore stack is `/trust/trusted_root.json`. The cluster's token issuer is in `/trust/issuer`.

```sh
kubectl -n workstation exec -it deploy/go-runner -- sh
```

## Your task

Fix `/work/verify-blob/main.go` so that, when it is built with `go build` in `/work/verify-blob` and run with the flags `--trusted-root`, `--bundle`, `--artifact`, `--identity` and `--issuer`:

1. It accepts `release.txt` with `release.txt.sigstore.json` when `--identity` is `https://kubernetes.io/namespaces/workstation/serviceaccounts/developer`, and exits with code `0`.
2. It refuses `other.txt` with `other.txt.sigstore.json` for the same identity, because another service account signed it, and exits with a non-zero code.
3. It refuses `release-tampered.txt` with `release.txt.sigstore.json`, because the file changed after signing, and exits with a non-zero code.

## Constraints

- Keep the program's flags as they are.
- Do not use `verify.WithoutIdentitiesUnsafe()`.
- Do not change the files in `/work/data` or the trust material.

## Done when

- `/work/verify-blob` builds with `go build`.
- The program exits with code `0` for the good file and with a non-zero code for the wrong signer and the changed file.
