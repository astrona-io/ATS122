// verify-release checks every file in a release folder. Each file must have a
// Sigstore bundle next to it (<file>.sigstore.json), signed by the expected
// identity. It prints one line per file and exits 1 when any file fails.
package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/sigstore/sigstore-go/pkg/bundle"
	"github.com/sigstore/sigstore-go/pkg/root"
	"github.com/sigstore/sigstore-go/pkg/verify"
)

const bundleSuffix = ".sigstore.json"

func main() {
	trustedRootPath := flag.String("trusted-root", "/trust/trusted_root.json", "path to the trusted root JSON")
	dir := flag.String("dir", "", "release folder to check")
	identity := flag.String("identity", "", "expected subject alternative name of the signer")
	issuer := flag.String("issuer", "", "expected OIDC issuer of the signer")
	flag.Parse()

	failed, err := run(*trustedRootPath, *dir, *identity, *issuer)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: %v\n", err)
		os.Exit(2)
	}
	if failed > 0 {
		fmt.Printf("%d file(s) failed verification\n", failed)
		os.Exit(1)
	}
	fmt.Println("all files verified")
}

func run(trustedRootPath, dir, identity, issuer string) (int, error) {
	trustedRoot, err := root.NewTrustedRootFromPath(trustedRootPath)
	if err != nil {
		return 0, fmt.Errorf("loading trusted root: %w", err)
	}
	verifier, err := verify.NewVerifier(trustedRoot,
		verify.WithSignedCertificateTimestamps(1),
		verify.WithTransparencyLog(1),
		verify.WithObserverTimestamps(1),
	)
	if err != nil {
		return 0, fmt.Errorf("creating verifier: %w", err)
	}
	certID, err := verify.NewShortCertificateIdentity(issuer, "", identity, "")
	if err != nil {
		return 0, fmt.Errorf("building identity: %w", err)
	}

	entries, err := os.ReadDir(dir)
	if err != nil {
		return 0, fmt.Errorf("reading %s: %w", dir, err)
	}
	var names []string
	for _, entry := range entries {
		if entry.IsDir() || strings.HasSuffix(entry.Name(), bundleSuffix) {
			continue
		}
		names = append(names, entry.Name())
	}
	sort.Strings(names)

	failed := 0
	for _, name := range names {
		if err := verifyFile(verifier, certID, filepath.Join(dir, name)); err != nil {
			fmt.Printf("FAIL %s: %v\n", name, err)
			failed++
			continue
		}
		fmt.Printf("OK %s\n", name)
	}
	return failed, nil
}

func verifyFile(verifier *verify.Verifier, certID verify.CertificateIdentity, path string) error {
	signedBundle, err := bundle.LoadJSONFromPath(path + bundleSuffix)
	if err != nil {
		return fmt.Errorf("no usable bundle: %w", err)
	}
	artifact, err := os.Open(path)
	if err != nil {
		return err
	}
	defer artifact.Close()
	_, err = verifier.Verify(signedBundle,
		verify.NewPolicy(verify.WithArtifact(artifact), verify.WithCertificateIdentity(certID)))
	return err
}
