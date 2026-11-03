# Identity Token Providers

gitsign cannot sign without an identity token, because Fulcio only issues a certificate to a caller that proves who it is. On a laptop, the token comes from a browser login. In a pipeline there is no browser, so the token has to come from somewhere else. This part lists where gitsign can get a token, shows how to sign as a chosen service account, and explains the identity that a GitHub Actions workflow receives.

## Where the token comes from

The **token provider** setting decides how gitsign gets its identity token. You set it with the Git key `gitsign.tokenProvider` or the environment variable `GITSIGN_TOKEN_PROVIDER`. The environment variable wins when both are set. These values matter for this course:

| Provider | Where the token comes from | Typical use |
| --- | --- | --- |
| `interactive` (default) | A browser login with an OpenID Connect (OIDC) provider | A developer on a laptop |
| `github-actions` | The token that a GitHub Actions job can request from GitHub | A workflow that signs commits or tags |
| `filesystem` | The file `/var/run/sigstore/cosign/oidc-token` | A pod whose service account token is mounted as that file |
| `envvar` | The environment variable `SIGSTORE_ID_TOKEN` | A bot that receives a token from its runner |

gitsign uses the token provider libraries of the Sigstore project, so other providers exist for other platforms. The rule is the same for all of them: the provider returns a token, Fulcio checks it, and the certificate names the identity in the token.

The interactive provider has its own settings. `gitsign.issuer` (`GITSIGN_OIDC_ISSUER`) is the OIDC provider to log in with, `gitsign.clientID` (`GITSIGN_OIDC_CLIENT_ID`) is the client identifier gitsign presents to it, `gitsign.redirectURL` (`GITSIGN_OIDC_REDIRECT_URL`) is the address the browser returns to, and `gitsign.connectorID` (`GITSIGN_CONNECTOR_ID`) selects one login method when the OIDC provider offers several. None of them matters for the `filesystem` and `envvar` providers, which never open a browser.

## Sign as a chosen service account

The workstation pod runs as `developer`, so the `filesystem` provider gives it the identity of `developer`. A pipeline usually signs as another account. To show this, create a token for the service account `ci-bot` on your machine. `kubectl create token` asks the Kubernetes API server for a new service account token, and `--audience sigstore` sets the audience that Fulcio requires:

<!-- astrona:playground:renew -->

```sh
TOKEN="$(kubectl -n workstation create token ci-bot --audience sigstore --duration 1h)"
```

Now run one commit in the workstation with that token. The command sets `GITSIGN_TOKEN_PROVIDER=envvar` and `SIGSTORE_ID_TOKEN` only for this one `kubectl exec`, so nothing is stored in the pod. The pod's shell fills in `$FULCIO_URL` and `$REKOR_URL`:

```sh
kubectl -n workstation exec deploy/workstation -- env SIGSTORE_ID_TOKEN="$TOKEN" GITSIGN_TOKEN_PROVIDER=envvar sh -c '
  cd /root/inventory-app && git checkout -q -B practice/pipeline main &&
  printf "change made by the pipeline\n" >> src/app.txt &&
  GITSIGN_FULCIO_URL="$FULCIO_URL" GITSIGN_REKOR_URL="$REKOR_URL" \
    git -c gpg.format=x509 -c gpg.x509.program=gitsign commit -q -a -S -m "Change made by the pipeline"'
```

Git calls gitsign, gitsign reads the token from `SIGSTORE_ID_TOKEN`, Fulcio checks it and issues a certificate for `ci-bot`, and gitsign signs the commit. Nothing in the commit says which provider was used. The only trace is the identity inside the certificate.

## Check which identity signed

Open a shell in the workstation and verify the commit with each of the two service accounts as the expected identity. The first succeeds only if `ci-bot` signed it:

```sh
cd /root/inventory-app
ISSUER="$(cat /trust/issuer)"
BASE="https://kubernetes.io/namespaces/workstation/serviceaccounts"
gitsign verify --certificate-identity="$BASE/ci-bot" --certificate-oidc-issuer="$ISSUER" HEAD; echo "exit code $?"
gitsign verify --certificate-identity="$BASE/developer" --certificate-oidc-issuer="$ISSUER" HEAD; echo "exit code $?"
```

The first command ends with exit code `0`. The second fails with an error about the certificate identity and a non-zero exit code. The pod runs as `developer`, but the signature names `ci-bot`, because the token decided the signer and not the pod. This is the reason a verifier must check the identity, and never the place where the commit was made.

## GitHub Actions identities

GitHub Actions can give a workflow job an OIDC token, if the workflow asks for the permission `id-token: write`. With `GITSIGN_TOKEN_PROVIDER=github-actions`, gitsign requests that token, and Fulcio issues a certificate for it. The issuer in the certificate is `https://token.actions.githubusercontent.com`. The identity is not an email address: it is the address of the workflow file that ran, in the form `https://github.com/<owner>/<repository>/.github/workflows/<file>@<ref>`, where `<ref>` is the Git reference, for example `refs/heads/main`.

So a verifier for commits signed in a workflow expects that workflow address and that issuer. A pattern such as `^https://github.com/inventory/app/\.github/workflows/release\.yml@refs/heads/main$` accepts only one workflow file on one branch. A looser pattern accepts every workflow of the repository, or every branch, and that is a decision about who may sign, not a convenience. The playground has no GitHub, so this part only describes the identity; the verification commands are the ones you ran above, with another value for `--certificate-identity` and `--certificate-oidc-issuer`.

## Which provider to choose

Use `interactive` for people, so every signature names a person. Use `github-actions` when the workflow itself should sign, so the signature names the workflow file. Use `filesystem` or `envvar` where the platform gives the job a token: a mounted service account token, or a token the runner puts in the environment. Prefer a short-lived token with the audience `sigstore`, and never write a token into a file that is committed or into a log.

You can now explain where gitsign gets its token, sign as any service account whose token you can create, and read the identity out of a verification. What is still open is how to sign something other than a commit. A release is marked by a tag, and a tag needs its own signing and its own check.

## Common pitfalls

> [!WARNING]
> - **Reading the signer from the pod or the committer email.** The signer is the identity in the token. The pod, the Git user name and the committer email are plain text that anyone can set.
> - **A token with the wrong audience.** Fulcio refuses a token without the audience `sigstore`, and the commit fails. Create the token with `--audience sigstore`.
> - **Leaving `GITSIGN_TOKEN_PROVIDER` unset in a pipeline.** The default provider is `interactive`, which waits for a browser that does not exist.
> - **A loose identity pattern for workflows.** A pattern that accepts every workflow or every branch of a repository lets any workflow in it sign as the release process.
