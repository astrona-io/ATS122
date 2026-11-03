# Signing And Verifying Tags

A release is marked by a Git tag, and a deploy step that trusts a tag name trusts whoever could push that name. A signed tag lets the deploy step check who created the release. This part explains what a tag object is, signs one with gitsign, and verifies it with `gitsign verify-tag` and an expected identity.

## What a tag is

Git has two kinds of tag. A **lightweight tag** is only a name that points at a commit. It has no author, no date, no message and no room for a signature. An **annotated tag** is a Git object of its own: it stores the object it points at, the tagger, a date and a message. Only an annotated tag can be signed. You create one with `git tag -a`, or with `git tag -s`, which also signs it.

The signature of a tag does not sit in a header like the `gpgsig` header of a commit. Git appends the signature block to the end of the tag message. With gitsign, that block starts with `-----BEGIN SIGNED MESSAGE-----`. The signature covers the pointed-at object, the tagger line, the date and the message, so moving the tag to another commit, or changing its message, breaks it.

## Sign a tag

Signing a tag needs the same settings as signing a commit. The `tag.gpgsign` setting plays the role of `commit.gpgsign`: when it is `true`, every new tag is signed without `-s`, and Git makes it an annotated tag. A related setting, `tag.forceSignAnnotated`, signs only the tags that you already create as annotated. In the workstation shell, set the gitsign environment variables and the Git settings for the clone:

<!-- astrona:playground:renew -->

```sh
cd /root/inventory-app
export GITSIGN_FULCIO_URL="$FULCIO_URL" GITSIGN_REKOR_URL="$REKOR_URL" GITSIGN_TOKEN_PROVIDER=filesystem
git config --local gpg.format x509
git config --local gpg.x509.program gitsign
git config --local tag.gpgsign true
git checkout -q main
```

Create an annotated tag for a release candidate and print it. Git calls gitsign, which gets a certificate for `developer` from the private Fulcio and records the signing in Rekor:

```sh
git tag -a v1.0.0-rc1 -m "Release candidate 1"
git cat-file -t v1.0.0-rc1
git cat-file tag v1.0.0-rc1
```

The type is `tag`. The object lists the commit it points at, the type `commit`, the tag name, the tagger and the message, and then the signature block. Without `tag.gpgsign` and without `-s`, the same name would have been a lightweight tag. `git cat-file -t` on a lightweight tag prints `commit`, because the name points straight at the commit. That is the most common reason that a release has no signature: the signing setting is missing on the machine that cut the release, so Git quietly made a lightweight tag.

## Push the tag

`git push` sends branches and not tags, so a tag needs its own push. Push the signed tag to Gitea by name:

```sh
git push origin v1.0.0-rc1
```

Gitea shows the tag, but like for commits it does not verify a gitsign signature. A consumer of the release has to run the check itself.

## Verify a tag

`gitsign verify-tag` checks a tag the way `gitsign verify` checks a commit: the signature, the Rekor proof, and the certificate against the identity and the issuer you pass. Verify the tag as `developer`, and then as `ci-bot`:

```sh
ISSUER="$(cat /trust/issuer)"
BASE="https://kubernetes.io/namespaces/workstation/serviceaccounts"
gitsign verify-tag --certificate-identity="$BASE/developer" --certificate-oidc-issuer="$ISSUER" v1.0.0-rc1; echo "exit code $?"
gitsign verify-tag --certificate-identity="$BASE/ci-bot" --certificate-oidc-issuer="$ISSUER" v1.0.0-rc1; echo "exit code $?"
```

The first command succeeds with exit code `0`. The second fails with a non-zero exit code, because the certificate names `developer`. As with commits, `git verify-tag` calls gitsign too, but Git passes no expected identity, so it accepts any signer that Sigstore accepts. Use `gitsign verify-tag` in every automatic check.

A tag also needs a check that it points where you expect. A valid signature on a tag proves who made it, not that it points at the commit you want to ship. Resolve the commit behind the tag and compare it with the commit you built:

```sh
git rev-parse 'v1.0.0-rc1^{commit}'
git rev-parse main
```

The two hashes are the same here. In a release step, compare the first hash with the commit hash that the build recorded, and stop the release when they differ.

## Changing a tag

A signed tag cannot be moved without breaking its trust. If you delete `v1.0.0-rc1` and create it again on another commit, you create a new tag object with a new signature, and anyone who had fetched the old tag still has the old one. Git does not replace a tag that a clone already has unless the user forces it. So treat a released tag as final: if the release is wrong, publish a new tag such as `v1.0.1`.

You can now sign a release tag, push it, and verify it against the identity you expect and the commit it must point at. Tags cover the release marker. The rest of the history still has to be checked commit by commit, and that check has to be something a pipeline can run and fail on.

## Common pitfalls

> [!WARNING]
> - **A lightweight tag.** `git tag v1.0.0` without `-a`, `-s`, a message or `tag.gpgsign` makes a lightweight tag, which cannot be signed. Check the type with `git cat-file -t`, which must print `tag`.
> - **No message with `tag.gpgsign`.** A signed tag is annotated and needs a message. Pass `-m`, or Git opens an editor.
> - **Forgetting to push the tag.** `git push` does not send tags. Push each tag by name, or use `git push --tags` knowing that it sends all of them.
> - **Verifying with `git verify-tag`.** It does not check the signer. Use `gitsign verify-tag` with `--certificate-identity` and `--certificate-oidc-issuer`.
> - **Trusting the tag name.** A valid signature does not say that the tag points at the commit you built. Compare `git rev-parse 'TAG^{commit}'` with your build's commit.

## Your mission: Sign And Verify A Release Tag

You can now make Git sign tags and verify them with `gitsign verify-tag`. The graded lab gives you a clone that signs commits but not tags, and asks you to create and push a signed `v1.0.0` tag without touching the existing unsigned tag.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-122-playground-010-02
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS122.git -c sections/section-010/module-02/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-010/module-02/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-122-lab-010-02
astrona start ats-122-playground-010-02
```
