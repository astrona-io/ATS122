# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** matching signers with a regular expression in sigstore-go

## Scenario

A release step verifies files that two service accounts may sign: `developer` for hotfixes and `ci-bot` for nightly builds. A colleague wrote `verify-blob`, a Go program that takes the allowed signers as a pattern in the flag `--identity-regexp`. In testing it behaved strangely: with a pattern it refused every file, and without a pattern it accepted every file.

The program is `/work/verify-blob/main.go` in the `go-runner` pod (namespace `workstation`). The test files are in `/work/data` there: `release.txt` (signed by `developer`), `ci-build.txt` (signed by `ci-bot`), `other.txt` (signed by `intruder`) and `release-tampered.txt` (a changed copy of `release.txt`). Each signed file has a bundle named like the file with `.sigstore.json` added. The trusted root of the private Sigstore stack is `/trust/trusted_root.json`, and the cluster's token issuer is in `/trust/issuer`.

```sh
kubectl -n workstation exec -it deploy/go-runner -- sh
```

## Your task

Fix `/work/verify-blob/main.go` so that, when it is built with `go build` in `/work/verify-blob` and run with the flags `--trusted-root`, `--bundle`, `--artifact`, `--identity-regexp` and `--issuer`:

1. With the pattern `^https://kubernetes\.io/namespaces/workstation/serviceaccounts/(developer|ci-bot)$` it accepts `release.txt` and `ci-build.txt` with their bundles, and exits with code `0`.
2. With the same pattern it refuses `other.txt`, and refuses `release-tampered.txt` used with the bundle of `release.txt`, and exits with a non-zero code.
3. It follows the pattern it is given: with a pattern that names only `ci-bot`, it refuses the developer's file.
4. Without `--identity-regexp` it exits with a non-zero code.

## Constraints

- Keep the program's flags as they are.
- Do not use `verify.WithoutIdentitiesUnsafe()`.
- Do not change the files in `/work/data` or the trust material.

## Done when

- `/work/verify-blob` builds with `go build`.
- The program gives the exit codes above for all four cases.
