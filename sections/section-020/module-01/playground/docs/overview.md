# Overview: Verify Sigstore Bundles From Go (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with a private Sigstore stack, a workstation pod and a Go pod, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- A **private Sigstore stack**: Fulcio (the certificate authority), Rekor (the transparency log) and a certificate transparency log. Fulcio accepts this cluster's Kubernetes service account tokens as identity tokens.
- The **workstation** pod in the namespace `workstation`, with `cosign` v3.1.4, `jq` and `openssl`. The example files and their bundles are in `/tmp/data`.
- The **go-runner** pod in the namespace `workstation`: Go 1.25 with the module `/work/verify-blob` (`go.mod` and `go.sum` for sigstore-go v1.3.0, and a placeholder `main.go`). The example files are in `/work/data`.
- The trust material in `/trust` in both pods: `trusted_root.json`, `signing_config.json`, `trust_config.json`, the keys, and the issuer in `issuer`.

| File | What it is |
| --- | --- |
| `release.txt` and `release.txt.sigstore.json` | A file signed by the service account `developer`, and its bundle |
| `release-tampered.txt` | A changed copy of `release.txt`, with no bundle of its own |
| `other.txt` and `other.txt.sigstore.json` | A file signed by the service account `intruder`, and its bundle |

## Helpers

Paste these once in each new terminal on your machine. `gorun` runs a command in go-runner. `put_file` copies a file from your machine into a pod. `ws` runs a command in the workstation.

```sh
gorun() { kubectl -n workstation exec -i deploy/go-runner -- "$@"; }
put_file() { kubectl -n workstation exec -i "deploy/$1" -- sh -c "cat > '$3'" < "$2"; }
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
```

Use them like this: `gorun ls /work/data`, `put_file go-runner main.go /work/verify-blob/main.go`, `ws jq keys /tmp/data/release.txt.sigstore.json`.

## Practice tasks

- Compare `jq -r '.messageSignature.messageDigest.digest'` of a bundle with `openssl dgst -sha256 -binary <file> | base64` for each file.
- Run `cosign verify-blob` in the workstation on all three files with the developer's identity, then with `--certificate-identity-regexp '.*'`, and explain the difference.
- Build the verifier, then remove `verify.WithCertificateIdentity` from its policy and replace it with `verify.WithoutIdentitiesUnsafe()`. Which test case now passes that should not?
- Change the verifier's SAN to a regular expression that accepts any service account in the namespace `workstation`, and check which files pass.
- Print `result.VerifiedTimestamps` in the verifier and compare it with `jq '.verificationMaterial.tlogEntries[0].integratedTime'` of the bundle.
