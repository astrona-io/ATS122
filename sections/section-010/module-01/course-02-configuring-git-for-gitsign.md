# Configuring Git To Sign With Gitsign

A signing tool helps only if it runs on every commit, without anyone remembering a flag. This part sets up the clone in the workstation so that Git calls gitsign for each commit, and so that gitsign uses the private Fulcio and Rekor of this cluster instead of the public Sigstore instance. Then it makes a signed commit and pushes it.

## The Git settings

Git needs three settings to sign with gitsign. Each one is a normal `git config` key, and you can set it for one repository (`--local`, stored in `.git/config`) or for every repository of a user (`--global`, stored in `~/.gitconfig`):

| Setting | Value | What it does |
| --- | --- | --- |
| `gpg.format` | `x509` | Git calls an X.509 signing program and stores a CMS signature |
| `gpg.x509.program` | `gitsign` | The X.509 signing program is gitsign |
| `commit.gpgsign` | `true` | Every new commit is signed, as if you passed `-S` |
| `tag.gpgsign` | `true` | Every new annotated tag is signed, as if you passed `-s` |

The gitsign documentation warns that with `commit.gpgsign` set, every commit needs the signing services. If they cannot be reached, the commit fails. Without it, you sign one commit at a time with `git commit -S`.

Set the Git settings for the clone only. In the workstation shell:

<!-- astrona:playground:renew -->

```sh
cd /root/inventory-app
git config --local gpg.format x509
git config --local gpg.x509.program gitsign
git config --local commit.gpgsign true
```

From now on, Git calls gitsign for every commit in this repository and stores the result in the `gpgsig` header.

## Pointing gitsign at an instance

By default gitsign uses the public Sigstore instance: Fulcio at `https://fulcio.sigstore.dev`, Rekor at `https://rekor.sigstore.dev`, and a browser login for the identity token. This cluster has its own instance, so gitsign needs three more settings. gitsign reads them from Git configuration (the `gitsign.` keys) or from environment variables; when both exist, the environment variable wins.

| Git setting | Environment variable | Value here |
| --- | --- | --- |
| `gitsign.fulcio` | `GITSIGN_FULCIO_URL` | `http://fulcio-server.fulcio-system.svc` |
| `gitsign.rekor` | `GITSIGN_REKOR_URL` | `http://rekor-server.rekor-system.svc` |
| `gitsign.tokenProvider` | `GITSIGN_TOKEN_PROVIDER` | `filesystem` |

The **token provider** decides where gitsign gets the identity token. `interactive` opens a browser, `github-actions` reads the token a GitHub Actions job can request, and `filesystem` reads the file `/var/run/sigstore/cosign/oidc-token`, which is where the workstation's service account token is mounted. The workstation shell has the two service addresses in `FULCIO_URL` and `REKOR_URL`. Set the gitsign keys for this repository:

```sh
git config --local gitsign.fulcio "$FULCIO_URL"
git config --local gitsign.rekor "$REKOR_URL"
git config --local gitsign.tokenProvider filesystem
```

gitsign also has to trust the private instance when it checks its own results. The workstation already sets that up with environment variables: `GITSIGN_FULCIO_ROOT` names Fulcio's certificate chain, `SIGSTORE_REKOR_PUBLIC_KEY` names Rekor's public key, and `SIGSTORE_CT_LOG_PUBLIC_KEY_FILE` names the CT log's key, all files under `/trust`. Ask gitsign which configuration it will use:

```sh
gitsign --version
```

gitsign prints its version and the parsed configuration as JSON. Check that `Fulcio` and `Rekor` show the private addresses and that `FulcioRoot` names `/trust/fulcio.pem`. This is the first command to run when gitsign signs against the wrong place.

## A signed commit

Now make a change on a new branch and commit it. You do not pass `-S`, because `commit.gpgsign` is set:

```sh
git checkout -b practice/signing
printf 'practice: one signed change\n' >> src/app.txt
git commit -am "Practise a signed commit"
```

gitsign reads the token file, gets a certificate from the private Fulcio, signs, and records the signing in Rekor. When there is no terminal, gitsign writes its messages nowhere you can see; if a commit fails with `gpg failed to sign the data`, set `GITSIGN_LOG=/tmp/gitsign.log` for that one command and read the file. Check the commit and push it to Gitea:

```sh
git cat-file commit HEAD
git push -u origin practice/signing
```

The new commit has a `gpgsig` header, and Gitea now holds the signed branch. Gitea shows the commit, but it does not verify gitsign signatures, and neither does GitHub: the Sigstore root is not in their trust store, and the short-lived certificate can only be checked together with the Rekor proof.

## The credential cache

Each signing asks Fulcio for a new certificate. With a browser login, that means one login per commit, which is slow. gitsign can keep the key and certificate for the certificate's lifetime and reuse them. `gitsign.credentialCacheMode` set to `system` stores them in the operating system's keyring (macOS Keychain, Windows Credential Manager, Linux Secret Service). Set to `socket`, it uses the `gitsign-credential-cache` daemon, named by `gitsign.credentialCache`. With the `filesystem` provider there is no login, so the workstation needs no cache.

You can now make Git sign every commit with gitsign and point gitsign at any Sigstore instance with three settings. The signature is in the commit and the signing is in Rekor. What you cannot do yet is prove who signed a commit; that needs a check against an expected identity.

## Common pitfalls

> [!WARNING]
> - **Forgetting `gpg.format x509`.** Without it, Git calls `gpg` (OpenPGP) and fails, or signs with the wrong tool. gitsign needs both `gpg.format` and `gpg.x509.program`.
> - **Leaving gitsign on the public instance.** Without `gitsign.fulcio` and `gitsign.rekor`, gitsign uses `fulcio.sigstore.dev` and tries a browser login. Check with `gitsign --version`.
> - **An environment variable you forgot.** A `GITSIGN_FULCIO_URL` in your shell wins over `gitsign.fulcio` in Git configuration.
> - **Global settings in a shared account.** `--global` signs every repository of the user, including repositories that should not reach your Sigstore instance. Prefer `--local` until you mean it.

## Your mission: Sign Every Commit With Gitsign

You can now configure a repository to sign every commit with gitsign against a private Sigstore instance. The graded lab gives you a clone that signs nothing yet, and asks you to configure it and push a branch of signed commits.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-122-playground-010-01
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS122.git -c sections/section-010/module-01/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-010/module-01/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-122-lab-010-01
astrona start ats-122-playground-010-01
```
