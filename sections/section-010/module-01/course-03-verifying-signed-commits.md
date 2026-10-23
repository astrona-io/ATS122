# Verifying Who Signed A Commit

A valid signature only says that someone with a Fulcio certificate signed the commit. On a Sigstore instance, anyone with an accepted identity token can get such a certificate. So the real question is not "is it signed?" but "is it signed by the identity I expect?". This part answers that question with `gitsign verify`, and shows why Git's own check does not.

## Verify a signature and its signer

`gitsign verify` checks three things about one commit: that the signature matches the commit content, that the Rekor proof is valid, and that the certificate names the identity you expect. You pass the expected identity with `--certificate-identity` (the subject alternative name) and `--certificate-oidc-issuer` (the issuer that vouched for it). In this cluster, the identity of the workstation is its service account, and the issuer is in `/trust/issuer`.

In the workstation shell, verify the signed commit on `demo/signed`:

<!-- astrona:playground:renew -->

```sh
cd /root/inventory-app
ISSUER="$(cat /trust/issuer)"
DEVELOPER="https://kubernetes.io/namespaces/workstation/serviceaccounts/developer"
gitsign verify --certificate-identity="$DEVELOPER" --certificate-oidc-issuer="$ISSUER" origin/demo/signed
```

gitsign prints the transparency log index of the entry, the certificate's issuer, a "Good signature" line with the identity and issuer from the certificate, and three lines that say the Git signature, the Rekor entry and the certificate claims were validated. Its exit code is `0`. Now ask the same question with an identity that did not sign:

```sh
gitsign verify --certificate-identity="https://kubernetes.io/namespaces/workstation/serviceaccounts/ci-bot" --certificate-oidc-issuer="$ISSUER" origin/demo/signed
echo $?
```

This time gitsign fails with an error about the certificate identity, and the exit code is not `0`. The signature itself is still valid; only the signer is wrong. That difference is the whole point of identity checks.

When you leave out `--certificate-identity`, gitsign v0.18.0 uses the committer's email address of the commit as the expected identity. That fits the public instance, where your identity is your email. Here the identity is a service account URI and the committer email is `developer@inventory.lab`, so the check fails. Always pass the identity you expect. When several identities are allowed, `--certificate-identity-regexp` and `--certificate-oidc-issuer-regexp` take a regular expression instead.

## Why `git verify-commit` is not enough

Git has its own commands, `git verify-commit` and `git verify-tag`. They call gitsign too, but Git does not pass any expected identity to the signing program. Try it on the same commit:

```sh
git verify-commit origin/demo/signed
```

The commit passes, and gitsign adds a warning: Git's command does not verify the certificate claims, so you should prefer `gitsign verify`. In other words, `git verify-commit` proves that some accepted identity signed the commit and that the signing is in Rekor, but not who signed it. `git log --show-signature` makes the same check for every commit it shows.

## Verify a whole branch

A review or a release usually needs every commit on a branch to be signed by an allowed identity, not just the last one. `git rev-list` lists the commits between two points, and a short loop checks each one:

```sh
for commit in $(git rev-list origin/main..origin/demo/signed); do
  gitsign verify --certificate-identity="$DEVELOPER" --certificate-oidc-issuer="$ISSUER" "$commit" >/dev/null 2>&1 \
    && echo "signed by developer: $commit" || echo "NOT signed by developer: $commit"
done
```

The loop prints one line per commit. An unsigned commit fails too, because there is no signature to check. This is how a pipeline gate or a reviewer script checks a branch before it merges. When a commit fails, the fix is a new signature on the same content: amend that one commit with `git commit --amend --no-edit -S`, or re-sign a series with `git rebase --force-rebase --gpg-sign <base>`, and force-push the branch.

gitsign can also compare the certificate with the committer. With `gitsign.matchCommitter` set to `true`, verification checks that the committer of the commit matches the identity in the certificate. That makes sense when identities are email addresses. With service account identities it never matches, so it stays off here.

## Hosting services

GitHub and Gitea show gitsign commits as unverified, or as signed by an unknown key. gitsign's documentation gives two reasons. The Sigstore root certificate is not in GitHub's trust store, and a standard X.509 check would call the short-lived certificate expired, because it does not use the Rekor proof. So the place that verifies gitsign commits is your own tooling: a pipeline step or a review script that runs `gitsign verify` with the identities you allow.

On your own machine, outside the playground, you can try the public instance. Install gitsign, configure a repository of your own with the Git settings `gpg.format x509`, `gpg.x509.program gitsign` and `commit.gpgsign true`, and commit. gitsign opens a browser to log in with GitHub, Google or Microsoft, and the certificate names your email address. Verify it with your email as `--certificate-identity` and your provider's issuer, for example `https://github.com/login/oauth`. This step is optional and not part of any lab, and the commit and your email address then go into the public Rekor log.

You can now prove who signed a commit, and you know why Git's own check and the hosting service's badge do not tell you that. With signing configured and verification in a loop, you have the two halves a team needs to require signed history.

## Common pitfalls

> [!WARNING]
> - **Treating "signed" as "trusted".** Any accepted identity can sign. Always verify with `--certificate-identity` and `--certificate-oidc-issuer`, or their `-regexp` forms.
> - **Relying on `git verify-commit` or `git log --show-signature`.** They check the signature and the log entry, not the signer.
> - **Verifying only the last commit.** A branch can hide an unsigned or wrongly signed commit below the top. Check every commit in the range.
> - **Hard-coding the issuer.** The issuer of service account tokens depends on the cluster. Read it from the token or from your trust material.
