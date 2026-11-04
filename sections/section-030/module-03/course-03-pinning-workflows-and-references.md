# Pinning Workflows And References

A policy that names the right repository can still accept the wrong code. The Git reference at the end of the identity decides which commits can produce a matching signature, and some workflow setups put a different file in the identity than you expect. This part looks at what a branch, a tag, a pull request and a reusable workflow each put in the certificate, and how to write a policy that matches a family of tags without matching too much.

## Branches move, tags are meant to stay

A reference such as `refs/heads/main` names a branch. Every merge to `main` runs the workflow again, and every run signs with the same identity. A policy on the branch accepts the release workflow at every commit that reaches `main`. A reference such as `refs/tags/v1.0.0` names one tag. The workflow runs when someone pushes the tag, and the identity matches only that version.

For a release, the tag is the better pin when the repository protects its tags, because only people allowed to create a tag can produce the identity. The reverse also holds: if anyone with write access can create any tag, a policy on `refs/tags/` accepts whatever they build. The pin is only as strong as the rule in the repository that controls the reference.

## Pull requests

A workflow that runs for a pull request has a reference like `refs/pull/42/merge`. If such a workflow has the permission `id-token: write` and a signing step, it signs with the identity of the pull request reference, not the identity of the release. A policy that accepts the workflow file at any reference accepts these signatures too. The event extension holds `pull_request` for these runs, so a policy that also requires the event `push` refuses them, and a policy that pins the exact reference refuses them without it.

## Reusable workflows

A workflow can call another workflow with `uses:`. The identity in the certificate comes from the `job_workflow_ref` claim, and for a called workflow this is the called file, not the file of the caller. If many repositories call a shared `sign.yml` from one organization, every one of them gets an identity with the repository and the path of the shared file. Then the repository inside the identity is the one that holds the shared workflow, and the repository that ran the job is in the source repository extension. A policy that wants to know which repository built the file must check that extension as well as the identity.

## Match a family of tags

A policy on the exact tag needs a new entry for each release. Many teams match every tag of a pattern instead. sigstore-python's `Identity` compares exact values, so the library needs a list of identities or a custom policy. `cosign verify-blob` accepts an anchored regular expression with `--certificate-identity-regexp`. Try it on the bundle of `app.tar.gz`, once with a pattern that fits and once with a pattern that does not:

<!-- astrona:playground:renew -->

```sh
pyrun() { kubectl -n workstation exec -i deploy/py-runner -- "$@"; }
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
pyrun cat /work/release-good/app.tar.gz | ws sh -c 'cat > /tmp/app.tar.gz'
pyrun cat /work/release-good/app.tar.gz.sigstore.json | ws sh -c 'cat > /tmp/app.tar.gz.sigstore.json'
ISSUER="$(ws cat /trust/issuer)"
ws cosign verify-blob --trusted-root /trust/trusted_root.json --bundle /tmp/app.tar.gz.sigstore.json \
  --certificate-identity-regexp '^https://kubernetes\.io/namespaces/workstation/serviceaccounts/(ci-bot|developer)$' \
  --certificate-oidc-issuer "$ISSUER" /tmp/app.tar.gz
ws cosign verify-blob --trusted-root /trust/trusted_root.json --bundle /tmp/app.tar.gz.sigstore.json \
  --certificate-identity-regexp 'ci-bot' --certificate-oidc-issuer "$ISSUER" /tmp/app.tar.gz
```

The first command anchors the pattern with `^` and `$` and escapes the dot, so it matches exactly the two service accounts. The second command uses an unanchored pattern. It also succeeds here, and that is the lesson: `ci-bot` matches any identity that contains those letters, including `https://evil.example/ci-bot-copy`. The same mistake with a GitHub reference is a pattern such as `release.yml`, which matches a workflow of any repository that has a file with that name.

A safe pattern for the tags of one workflow looks like `^https://github\.com/acme/inventory-app/\.github/workflows/release\.yml@refs/tags/v[0-9]+\.[0-9]+\.[0-9]+$`. It fixes the repository, the file and the form of the tag, and nothing else can match.

You now know how the reference, the event and a reusable workflow change what a policy accepts. The remaining question is how to write the same verification outside Python.

## Common pitfalls

> [!WARNING]
> - **An unanchored regular expression.** Without `^` and `$` the pattern matches inside a longer identity.
> - **An unescaped dot.** In a regular expression `.` matches any character. Write `\.` in the host name and the file name.
> - **Pinning a branch of a repository that allows direct pushes.** Anyone with write access can produce the identity.
> - **Ignoring pull requests.** A signing step that runs for a pull request signs with the identity of the pull request reference.
