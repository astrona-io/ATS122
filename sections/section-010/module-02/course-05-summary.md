# Summary

gitsign signs as whoever owns the identity token, so the token source decides the signer. The token provider setting selects the source: `interactive` for a browser login, `github-actions` for the token a workflow can request, `filesystem` for a mounted token file, and `envvar` for a token in `SIGSTORE_ID_TOKEN`. Fulcio checks the token and issues a certificate for the identity in it. The pod, the Git user name and the committer email do not matter. A workflow signs with the address of its workflow file as the identity and `https://token.actions.githubusercontent.com` as the issuer.

A release is marked with an annotated tag, because a lightweight tag is only a name and cannot carry a signature. With `tag.gpgsign` set to `true`, Git signs every new tag through gitsign, and a signed tag is annotated. The signature block sits at the end of the tag message. `gitsign verify-tag`, with `--certificate-identity` and `--certificate-oidc-issuer`, checks the signature and the signer, while `git verify-tag` does not check the signer. A valid signature does not prove that the tag points at the right commit, so a release step also compares the tagged commit with the commit it built. `git push` does not send tags; each tag is pushed by name.

A pipeline check lists the commits of a range with `git rev-list`, verifies every one, prints one line per commit, and fails after the last check if any commit failed. An empty range counts as a failure. `--certificate-identity-regexp` allows several signers, and an anchored pattern with the accounts listed one by one keeps the list tight. Commits that a hosting service creates when it merges are not signed by gitsign, so the pipeline either skips merge commits or verifies the branch before the merge.

When signing fails, Git shows only `gpg failed to sign the data`. The real reason is in the file named by `GITSIGN_LOG`. The most common causes are Git not calling gitsign, no token provider in a place without a browser, a wrong Fulcio or Rekor address, a token with the wrong audience, and missing trust files for a private instance. The key facts to remember are these:

- The identity in the certificate is the identity in the token.
- Only an annotated tag can be signed, and every tag is pushed by name.
- A pipeline gate checks every commit, reports each failure and fails at the end.
- Read `GITSIGN_LOG` first when signing fails.

<!-- astrona:playground:destroy -->
