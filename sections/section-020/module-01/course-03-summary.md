# Summary

A Sigstore bundle carries everything a verifier needs about one signing: the Fulcio certificate with the signer's identity, the Rekor entry with its inclusion proof and integrated time, the digest of the signed file and the signature over that digest. The bundle brings its own certificate, so the verifier also needs a trusted root: the certificate chains of the Fulcio instances it accepts and the keys of the transparency logs and certificate transparency logs it trusts.

A verifier makes its checks in order. The certificate must chain to a trusted Fulcio and have been valid at the time the log recorded the signing. It must carry a signed certificate timestamp from a trusted CT log. The log entry must be in a trusted log. The signature must match the digest, the digest must match the file, and the certificate's identity must be the signer you expect. A failure at any step rejects the file.

sigstore-go splits this into four pieces: `root.NewTrustedRootFromPath` loads the trusted root, `bundle.LoadJSONFromPath` loads the bundle, `verify.NewVerifier` sets the evidence thresholds, and `verify.NewPolicy` names the artifact and the expected identity. `verify.NewShortCertificateIdentity` builds that identity from an issuer and a subject alternative name. The key facts to remember are these:

- A valid signature from the wrong signer is still valid; only the identity in the policy tells signers apart.
- `verify.WithoutIdentitiesUnsafe()` accepts any signer and must never decide anything.
- A verifier must return its error and exit with a non-zero code; a warning that carries on lets every file through.
- Test a verifier with a good file, a changed file and a wrong signer, and compare its answers with `cosign verify-blob`.

<!-- astrona:playground:destroy -->
