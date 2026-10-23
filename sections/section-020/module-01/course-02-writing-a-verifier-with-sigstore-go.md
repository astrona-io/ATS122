# Writing A Verifier With sigstore-go

`cosign verify-blob` is the right tool in a shell, but a release gate, an admission controller or a package installer has to verify inside its own process. This part writes a small Go program with sigstore-go that makes the same checks as cosign: it loads the trusted root and the bundle, builds a verifier, and verifies the file against a policy that names the expected signer. Then it runs the program against the three example files.

## The four building blocks

sigstore-go splits verification into four pieces, and each one lives in its own package:

| Piece | Package and function | What it does |
| --- | --- | --- |
| Trusted root | `root.NewTrustedRootFromPath` | Loads `trusted_root.json`: the Fulcio chains and the log keys you trust |
| Bundle | `bundle.LoadJSONFromPath` | Loads and parses the Sigstore bundle of one file |
| Verifier | `verify.NewVerifier` | Checks a bundle against the trusted root, with thresholds for the evidence it needs |
| Policy | `verify.NewPolicy` | Says what the bundle must be about: which artifact, and which signer |

The verifier's options are thresholds. `verify.WithSignedCertificateTimestamps(1)` requires one signed certificate timestamp from a CT log in the trusted root. `verify.WithTransparencyLog(1)` requires one entry in a transparency log in the trusted root. `verify.WithObserverTimestamps(1)` requires one trusted time, from the log entry or from a timestamp authority, at which the certificate is checked.

The policy has two parts. `verify.WithArtifact` hands over the file, so the verifier can compare its digest with the bundle. `verify.WithCertificateIdentity` names the expected signer, built with `verify.NewShortCertificateIdentity(issuer, issuerRegex, san, sanRegex)`: you give the issuer and the subject alternative name (SAN) either as exact values or as regular expressions. sigstore-go also has `verify.WithoutIdentitiesUnsafe()`, which skips the identity check. As its name says, it is unsafe: it accepts any signer.

## The program

The program takes the trusted root, the bundle, the file, the expected identity and the issuer as flags. It prints `VERIFIED` and exits with code `0` when every check passes, and prints `FAILED` and exits with code `1` otherwise. Save this as `main.go` on your machine:

<!-- astrona:playground:renew -->

```go
// verify-blob checks a Sigstore bundle for a file against a trusted root and
// an expected signer identity, using sigstore-go.
package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/sigstore/sigstore-go/pkg/bundle"
	"github.com/sigstore/sigstore-go/pkg/root"
	"github.com/sigstore/sigstore-go/pkg/verify"
)

func main() {
	trustedRootPath := flag.String("trusted-root", "trusted_root.json", "path to the trusted root JSON")
	bundlePath := flag.String("bundle", "", "path to the Sigstore bundle")
	artifactPath := flag.String("artifact", "", "path to the signed file")
	identity := flag.String("identity", "", "expected subject alternative name of the signer")
	issuer := flag.String("issuer", "", "expected OIDC issuer of the signer")
	flag.Parse()

	if err := run(*trustedRootPath, *bundlePath, *artifactPath, *identity, *issuer); err != nil {
		fmt.Fprintf(os.Stderr, "FAILED: %v\n", err)
		os.Exit(1)
	}
}

func run(trustedRootPath, bundlePath, artifactPath, identity, issuer string) error {
	trustedRoot, err := root.NewTrustedRootFromPath(trustedRootPath)
	if err != nil {
		return fmt.Errorf("loading trusted root: %w", err)
	}

	signedBundle, err := bundle.LoadJSONFromPath(bundlePath)
	if err != nil {
		return fmt.Errorf("loading bundle: %w", err)
	}

	// The verifier checks the certificate chain, one signed certificate
	// timestamp from the CT log, and one entry in the transparency log.
	verifier, err := verify.NewVerifier(trustedRoot,
		verify.WithSignedCertificateTimestamps(1),
		verify.WithTransparencyLog(1),
		verify.WithObserverTimestamps(1),
	)
	if err != nil {
		return fmt.Errorf("creating verifier: %w", err)
	}

	certID, err := verify.NewShortCertificateIdentity(issuer, "", identity, "")
	if err != nil {
		return fmt.Errorf("building identity: %w", err)
	}

	artifact, err := os.Open(artifactPath)
	if err != nil {
		return fmt.Errorf("opening artifact: %w", err)
	}
	defer artifact.Close()

	result, err := verifier.Verify(signedBundle,
		verify.NewPolicy(verify.WithArtifact(artifact), verify.WithCertificateIdentity(certID)))
	if err != nil {
		return err
	}

	fmt.Printf("VERIFIED %s (issuer %s)\n",
		result.Signature.Certificate.SubjectAlternativeName,
		result.Signature.Certificate.Issuer)
	return nil
}
```

Two details matter most. The policy uses `verify.WithCertificateIdentity`, so a valid signature from another signer fails. And every error is returned from `run`, so `main` exits with code `1`; a verifier that only prints a warning and carries on would let every file through.

## Build and run it

The Go module is in `/work/verify-blob` in the `go-runner` pod, with `go.mod` and `go.sum` for sigstore-go v1.3.0. Define two helpers on your machine: `gorun` runs a command in `go-runner`, and `put_file` copies a file from your machine into a pod:

```sh
gorun() { kubectl -n workstation exec -i deploy/go-runner -- "$@"; }
put_file() { kubectl -n workstation exec -i "deploy/$1" -- sh -c "cat > '$3'" < "$2"; }
```

Copy the program into the module and build it:

```sh
put_file go-runner main.go /work/verify-blob/main.go
gorun sh -c 'cd /work/verify-blob && go build -o verify-blob .'
```

The first build compiles sigstore-go and its dependencies, so it takes a minute or two; the environment downloaded the modules at start. Now run the program on the three test cases. The issuer comes from `/trust/issuer` in the pod:

```sh
gorun sh -c '/work/verify-blob/verify-blob --trusted-root /trust/trusted_root.json \
  --bundle /work/data/release.txt.sigstore.json --artifact /work/data/release.txt \
  --identity https://kubernetes.io/namespaces/workstation/serviceaccounts/developer \
  --issuer "$(cat /trust/issuer)"; echo "exit code $?"'
```

The program prints `VERIFIED` with the developer's identity and the issuer, and exit code `0`. Run it again with `--artifact /work/data/release-tampered.txt`, and then with `--bundle /work/data/other.txt.sigstore.json --artifact /work/data/other.txt`:

```sh
gorun sh -c '/work/verify-blob/verify-blob --trusted-root /trust/trusted_root.json \
  --bundle /work/data/release.txt.sigstore.json --artifact /work/data/release-tampered.txt \
  --identity https://kubernetes.io/namespaces/workstation/serviceaccounts/developer \
  --issuer "$(cat /trust/issuer)"; echo "exit code $?"'
gorun sh -c '/work/verify-blob/verify-blob --trusted-root /trust/trusted_root.json \
  --bundle /work/data/other.txt.sigstore.json --artifact /work/data/other.txt \
  --identity https://kubernetes.io/namespaces/workstation/serviceaccounts/developer \
  --issuer "$(cat /trust/issuer)"; echo "exit code $?"'
```

Both print `FAILED` with the reason and exit code `1`: the first because the digest does not match the changed file, the second because no certificate identity matched the developer. These are the same three answers `cosign verify-blob` gives, which is the test that your verifier is complete.

You can now verify a Sigstore bundle from Go, with the evidence thresholds, the artifact and the signer identity, and make the program fail when any check fails. That is the core of every release gate and admission check that uses Sigstore.

## Common pitfalls

> [!WARNING]
> - **`verify.WithoutIdentitiesUnsafe()` in production code.** It accepts any signer with a valid certificate. Use it only to inspect a bundle, never to decide.
> - **Logging an error and returning success.** A verifier that prints a warning and exits with code `0` passes every file to the next step.
> - **A regular expression that matches too much.** A SAN pattern like `.*` is the same as no identity check. Prefer exact values, and anchor patterns with `^` and `$`.
> - **Testing only the good case.** A verifier is tested by what it refuses. Always run it against a changed file and a wrong signer too.

## Your mission: Make A Go Verifier Check Who Signed

You can now write a sigstore-go verifier that checks the signer and fails on any error. The graded lab gives you a colleague's verifier that accepts every signer and never fails, and asks you to fix it so it refuses a changed file and the wrong signer.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-122-playground-020-01
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS122.git -c sections/section-020/module-01/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/module-01/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-122-lab-020-01
astrona start ats-122-playground-020-01
```
