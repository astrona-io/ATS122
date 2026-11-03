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

	artifact, err := os.Open(artifactPath)
	if err != nil {
		return fmt.Errorf("opening artifact: %w", err)
	}
	defer artifact.Close()

	if identityRegexp == "" {
		return errors.New("--identity-regexp is required")
	}
	certID, err := verify.NewShortCertificateIdentity(issuer, "", "", identityRegexp)
	if err != nil {
		return fmt.Errorf("building identity: %w", err)
	}
	policy := verify.NewPolicy(verify.WithArtifact(artifact), verify.WithCertificateIdentity(certID))

	result, err := verifier.Verify(signedBundle, policy)
	if err != nil {
		return err
	}

	fmt.Printf("VERIFIED %s (issuer %s)\n",
		result.Signature.Certificate.SubjectAlternativeName,
		result.Signature.Certificate.Issuer)
	return nil
}
