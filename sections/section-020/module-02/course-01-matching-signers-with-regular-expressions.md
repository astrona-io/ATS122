# Matching Signers With Regular Expressions

An exact identity policy names one signer. That is right for a file that one person must sign, and wrong for a pipeline where the developer, the CI service account and a release manager may all sign. This part shows how the certificate identity in a policy matches several signers with a regular expression, why an unanchored pattern is the same as no check, and how to build a pattern that is as narrow as the rule it implements.

## What the policy compares

A Fulcio certificate holds two values that identify the signer. The **issuer** is the identity provider that vouched for the signer, for example the cluster that issued the service account token. The **subject alternative name** (SAN) is the identity inside that provider. In the private Sigstore stack of this playground the SAN of a service account is:

```text
https://kubernetes.io/namespaces/workstation/serviceaccounts/developer
```

sigstore-go compares both values with the policy. `verify.NewShortCertificateIdentity(issuer, issuerRegex, san, sanRegex)` takes four arguments: the issuer as an exact value or a regular expression, and the SAN as an exact value or a regular expression. For each pair you fill in one and leave the other empty:

```go
// Exact issuer, SAN matched by a regular expression.
certID, err := verify.NewShortCertificateIdentity(
	issuer, "",
	"", `^https://kubernetes\.io/namespaces/workstation/serviceaccounts/(developer|ci-bot)$`)
```

The verifier accepts the file only when the certificate matches every value you supply. The identity then goes into the policy with `verify.WithCertificateIdentity(certID)`.

## How a pattern matches

The pattern is a Go regular expression, and the match is a search: the pattern matches when it occurs anywhere in the SAN. That is why anchors matter. Compare these patterns against the three service accounts of the playground:

| Pattern | developer | ci-bot | intruder | Verdict |
| --- | --- | --- | --- | --- |
| `serviceaccounts/developer` | match | no match | no match | Matches by accident of the names |
| `serviceaccounts/(developer\|ci-bot)` | match | match | no match | Looks right, but is not anchored |
| `^https://kubernetes\.io/namespaces/workstation/serviceaccounts/(developer\|ci-bot)$` | match | match | no match | Correct and anchored |
| `.*` | match | match | match | The same as no check |

The third pattern is the one to write. `^` and `$` pin the pattern to the whole SAN, the escaped dots match literal dots, and the parentheses limit the alternatives to the two names. The second pattern still accepts a service account named `developer-temp`, or any SAN that contains `serviceaccounts/developer` after other text. Always anchor, and always escape the dots in host names.

## Match the issuer as well

Two clusters can both have a service account named `developer` in a namespace named `workstation`. The SAN of both would be the same string, so the SAN alone does not say which cluster signed. The issuer tells them apart. Supply the issuer of your own cluster as an exact value:

<!-- astrona:playground:renew -->

```sh
gorun() { kubectl -n workstation exec -i deploy/go-runner -- "$@"; }
gorun cat /trust/issuer
```

Use the value this prints as the issuer argument. A policy with a loose SAN and no issuer accepts the same name from any provider that Fulcio trusts.

## A verifier with a pattern flag

The verifier below takes the signer as a pattern instead of an exact value. It refuses to run without a pattern. That is deliberate: a verifier whose identity flag can be left empty would fall back to accepting everyone, and a missing option should stop the pipeline, not widen it. Save this as `main.go` on your machine:

```go
// verify-blob checks a Sigstore bundle for a file against a trusted root and
// a pattern for the signer's identity, using sigstore-go.
package main

import (
	"errors"
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
	identityRegexp := flag.String("identity-regexp", "", "regular expression that the signer's SAN must match")
	issuer := flag.String("issuer", "", "expected OIDC issuer of the signer")
	flag.Parse()

	if err := run(*trustedRootPath, *bundlePath, *artifactPath, *identityRegexp, *issuer); err != nil {
		fmt.Fprintf(os.Stderr, "FAILED: %v\n", err)
		os.Exit(1)
	}
}

func run(trustedRootPath, bundlePath, artifactPath, identityRegexp, issuer string) error {
	if identityRegexp == "" {
		return errors.New("--identity-regexp is required")
	}

	trustedRoot, err := root.NewTrustedRootFromPath(trustedRootPath)
	if err != nil {
		return fmt.Errorf("loading trusted root: %w", err)
	}

	signedBundle, err := bundle.LoadJSONFromPath(bundlePath)
	if err != nil {
		return fmt.Errorf("loading bundle: %w", err)
	}

	verifier, err := verify.NewVerifier(trustedRoot,
		verify.WithSignedCertificateTimestamps(1),
		verify.WithTransparencyLog(1),
		verify.WithObserverTimestamps(1),
	)
	if err != nil {
		return fmt.Errorf("creating verifier: %w", err)
	}

	certID, err := verify.NewShortCertificateIdentity(issuer, "", "", identityRegexp)
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

Copy it into the Go module and build it:

```sh
put_file() { kubectl -n workstation exec -i "deploy/$1" -- sh -c "cat > '$3'" < "$2"; }
put_file go-runner main.go /work/verify-blob/main.go
gorun sh -c 'cd /work/verify-blob && go build -o verify-blob .'
```

Run it on the developer's file, the CI file and the intruder's file with the same pattern:

```sh
for file in release.txt ci-build.txt other.txt; do
  gorun sh -c "/work/verify-blob/verify-blob --trusted-root /trust/trusted_root.json \
    --bundle /work/data/$file.sigstore.json --artifact /work/data/$file \
    --identity-regexp '^https://kubernetes\.io/namespaces/workstation/serviceaccounts/(developer|ci-bot)\$' \
    --issuer \"\$(cat /trust/issuer)\"; echo \"$file: exit code \$?\""
done
```

The first two files exit with `0` and print `VERIFIED`. `other.txt` exits with `1`, because the SAN of the `intruder` service account does not match the pattern, even though its signature is valid.

## Common pitfalls

> [!WARNING]
> - **No anchors.** A pattern without `^` and `$` matches anywhere in the SAN. A signer named `developer-temp` or a SAN that merely contains the text passes.
> - **Unescaped dots.** In a regular expression `.` matches any character, so `kubernetes.io` also matches `kubernetesXio`. Write `kubernetes\.io`.
> - **An empty pattern that means "any".** If your code treats a missing pattern as no identity check, a forgotten flag lets every signer through. Return an error instead.
> - **A pattern for the SAN and nothing for the issuer.** The same SAN can come from another identity provider. Pin the issuer too.

## Your mission: Accept Two Signers With A Pattern

You can now write a policy that accepts a group of signers with an anchored pattern and refuses everyone else. The graded lab gives you a verifier whose pattern flag is ignored in one case and misused in another, and asks you to make it accept the developer and the CI service account only.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-122-playground-020-02
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS122.git -c sections/section-020/module-02/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/module-02/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-122-lab-020-02
astrona start ats-122-playground-020-02
```
