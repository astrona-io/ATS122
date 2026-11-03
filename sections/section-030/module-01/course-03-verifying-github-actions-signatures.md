# Verifying GitHub Actions Signatures

A workflow that runs on GitHub Actions can sign a build output without any secret. GitHub gives the job an identity token, Fulcio turns it into a short-lived certificate, and the certificate names the repository and the workflow that ran. The consumer of the file then verifies that name. sigstore-python has a `verify github` subcommand for this case. This part explains what a GitHub certificate holds, how `verify github` differs from `verify identity`, and why you can read it but not run it against the private stack of this playground.

## What a GitHub certificate names

The identity in a certificate from a GitHub Actions job is not a user name. It is a **workflow reference**: the address of the workflow file, followed by the Git reference that triggered the run. For a workflow `release.yml` in the repository `acme/inventory-app` that ran on the `main` branch, the subject alternative name looks like this:

```text
https://github.com/acme/inventory-app/.github/workflows/release.yml@refs/heads/main
```

The OIDC issuer is always the same address, `https://token.actions.githubusercontent.com`. Fulcio also copies claims from the token into extensions of the certificate, for example the repository, the commit that was built and the event that started the run. That is why a GitHub certificate says much more than a service account certificate: it ties the signature to code, not only to a name.

## Two commands for two jobs

`sigstore verify identity` takes the identity and the issuer you expect as plain values. It works for every Sigstore signer, and it is the command used earlier in this module. `sigstore verify github` is a shortcut for the GitHub case. It fills in the GitHub issuer for you and takes the repository as an option, as its help page shows, so you do not type the issuer or the start of the identity yourself. It can also check the extra fields that only a GitHub certificate has, such as the commit or the branch. The options differ between versions, so read what your installed version offers:

<!-- astrona:playground:renew -->

```sh
pyrun() { kubectl -n workstation exec -i deploy/py-runner -- "$@"; }
pyrun sigstore verify github --help
pyrun sigstore verify identity --help
```

Read the two help pages side by side and note which options of `verify github` have no counterpart in `verify identity`. Those options are the extra claims a GitHub certificate carries.

## The same check with `verify identity`

Everything `verify github` checks can also be written with `verify identity`, by giving the full workflow reference and the GitHub issuer yourself:

```sh
sigstore verify identity \
  --cert-identity https://github.com/acme/inventory-app/.github/workflows/release.yml@refs/heads/main \
  --cert-oidc-issuer https://token.actions.githubusercontent.com \
  app.tar.gz
```

The names in the command are examples of a made-up repository; no such repository exists, and the playground has no bundle for it. Use this command as the shape to copy when you verify a file from a real repository. In your own pipeline, the consumer must pin a workflow and a reference. A pattern for the whole organization, or any workflow in the repository, accepts a signature from a pull request branch that anyone can open.

## Why you cannot run it here

The private Sigstore stack of the playground trusts Kubernetes service account tokens. No GitHub Actions job signs in this cluster, so there is no certificate that names a repository, and `verify github` has nothing to verify. The playground signers are `developer`, `ci-bot` and `intruder`, and for them `verify identity` is the right command. The lesson to keep is the concept: a signer in CI is named by the code that ran, and a verifier should require that name, with the issuer of the CI system.

## Common pitfalls

> [!WARNING]
> - **Accepting a whole repository or organization.** A pattern that matches any workflow or any branch accepts a signature from code that the repository owners never reviewed. Pin the workflow file and the reference.
> - **Leaving the issuer out.** A GitHub name is only meaningful with the GitHub issuer. Another provider could present a certificate with a similar name.
> - **Using `verify github` for a non-GitHub signer.** It assumes a GitHub issuer. For any other signer use `verify identity`.
