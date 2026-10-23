# Question

Solve this question on: `terminal`

**Time:** about 35 minutes · **Topic:** a release gate with sigstore-go

## Scenario

Before a release ships, a Go program called `verify-release` checks a release folder. Every file must have a Sigstore bundle next to it (`<file>.sigstore.json`), signed by the service account `developer`. The program prints one line per file and exits with code `1` when any file fails.

The release candidate in `/work/release-candidate` passed the check, but it should not have. Three of its files are bad: one has no bundle at all, one changed after it was signed, and one was signed by another service account.

The program is `/work/verify-release/main.go` in the `go-runner` pod (namespace `workstation`). A second folder, `/work/release-clean`, holds only good files. The trusted root is `/trust/trusted_root.json` and the cluster's token issuer is in `/trust/issuer`.

```sh
kubectl -n workstation exec -it deploy/go-runner -- sh
```

## Your task

Fix `/work/verify-release/main.go` so that, built with `go build` in `/work/verify-release` and run with `--trusted-root`, `--dir`, `--identity` and `--issuer`, with `--identity https://kubernetes.io/namespaces/workstation/serviceaccounts/developer`:

1. On `/work/release-candidate` it prints `FAIL <file>: <reason>` for each bad file and `OK <file>` for each good file, and exits with code `1`.
2. On `/work/release-clean` it prints `OK` for every file and exits with code `0`.

## Constraints

- Keep the program's flags and its output format (`OK <file>`, `FAIL <file>: <reason>`).
- A file without a bundle is a failure, not a file to skip.
- Do not change the release folders, the bundles or the trust material.

## Done when

- `/work/verify-release` builds with `go build`.
- On `/work/release-candidate` the program exits with code `1`, prints `FAIL` lines for exactly `docs.txt`, `notes.txt` and `plugin.bin`, and `OK` lines for `app.bin` and `config.json`.
- On `/work/release-clean` the program exits with code `0`.
