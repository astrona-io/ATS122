# Summary

Git records an author and a committer on every commit but never checks them. A signature in the commit's `gpgsig` header covers the whole commit object, so any change to the files, the author or the message breaks it. Git does not sign by itself: it calls a signing program, and with `gpg.format x509` and `gpg.x509.program gitsign` that program is gitsign.

gitsign signs keylessly. It gets an identity token from an OpenID Connect provider, asks Fulcio for a certificate that binds a new, short-lived key to that identity, signs the commit, and records the signing in Rekor. The certificate expires about ten minutes later, and the Rekor proof shows it was valid when the signing happened. In offline Rekor mode the proof is stored in the commit itself, so verification needs no search in the log.

Three Git settings and three gitsign settings make a repository sign every commit against an instance: `gpg.format`, `gpg.x509.program` and `commit.gpgsign`, then `gitsign.fulcio`, `gitsign.rekor` and `gitsign.tokenProvider`. Environment variables such as `GITSIGN_FULCIO_URL` win over Git configuration, and `gitsign --version` shows the configuration gitsign really uses. A credential cache keeps one certificate for its lifetime when every signing would otherwise need a browser login.

A signature only proves that some accepted identity signed. `gitsign verify` with `--certificate-identity` and `--certificate-oidc-issuer` proves who signed, while `git verify-commit` and `git log --show-signature` do not check the signer. GitHub and Gitea do not verify gitsign signatures, so your own tooling has to. The key facts to remember are these:

- The signature proves the content; the certificate and the identity check prove the signer.
- The identity of a Kubernetes service account is `https://kubernetes.io/namespaces/<namespace>/serviceaccounts/<name>`.
- Verify every commit of a branch, not only the last one.
- Fix a wrong or missing signature by signing the same content again, then force-push.

<!-- astrona:playground:destroy -->
