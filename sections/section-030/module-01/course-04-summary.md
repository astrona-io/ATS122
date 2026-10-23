# Summary

sigstore-python signs and verifies Sigstore bundles from its `sigstore` command and from Python code. To sign it needs three inputs: an identity token that says who signs, a signing configuration that names Fulcio, Rekor and the OIDC provider, and a trusted root to check the results. A client trust configuration holds the signing configuration and the trusted root in one file, and the global option `--trust-config` points the command at it. Without it, sigstore-python uses the public instance and a browser login.

The identity token must have the audience `sigstore`. sigstore-python checks the audience before it sends the token, and Fulcio checks it again. Ambient detection finds tokens in CI systems such as GitHub Actions; a Kubernetes service account token is passed with `--identity-token`. `sigstore sign` writes `<file>.sigstore.json`, and `sigstore verify identity` checks it with `--cert-identity` and `--cert-oidc-issuer`.

In code, `ClientTrustConfig.from_json` loads the trust configuration, `IdentityToken` wraps the token, and `SigningContext.from_trust_config` with `signer` and `sign_artifact` signs bytes and returns a `Bundle`. `Verifier(trusted_root=...)` with `verify_artifact` and an `Identity` policy verifies, and raises `VerificationError` on any failure. The bundle format is shared by every Sigstore client, so `cosign verify-blob` and sigstore-go accept the same bundle with the same trusted root. The key facts to remember are these:

- Sign the bytes on disk exactly; any change, even stripped whitespace, breaks the digest.
- Require the signer's identity and issuer; a valid signature from the wrong signer must fail.
- Let a verification error stop the work; never log it and carry on.
- Check a language client for identity checks, current bundle support and private-instance support before you depend on it.

<!-- astrona:playground:destroy -->
