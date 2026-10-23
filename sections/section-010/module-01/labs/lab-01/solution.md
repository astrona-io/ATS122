# Solution: Sign Every Commit With Gitsign

Work the task yourself first. Running `astrona submit -c sections/section-010/module-01/labs/lab-01` after a step tells you which checks pass.

The grader checks two things: the six repository-local settings of `/root/inventory-app`, and that every commit on `feature/signed` after `main` verifies with `gitsign verify` as the service account `developer`.

## Step 1: Open the workstation and look at the clone

Open a shell in the workstation pod and go to the clone:

```sh
kubectl -n workstation exec -it deploy/workstation -- sh
cd /root/inventory-app
git status
git config --local --list
```

The clone is on `main`, and its local configuration has only the remote and branch settings. No signing is set up.

## Step 2: Make Git sign with gitsign

Set the three Git settings for this repository:

```sh
git config --local gpg.format x509
git config --local gpg.x509.program gitsign
git config --local commit.gpgsign true
```

`gpg.format x509` makes Git call an X.509 signing program, `gpg.x509.program gitsign` names gitsign as that program, and `commit.gpgsign true` signs every commit without `-S`.

## Step 3: Point gitsign at the private stack

Set the three gitsign settings:

```sh
git config --local gitsign.fulcio "$FULCIO_URL"
git config --local gitsign.rekor "$REKOR_URL"
git config --local gitsign.tokenProvider filesystem
gitsign --version
```

`gitsign --version` prints the configuration gitsign will use. `Fulcio` and `Rekor` show the private addresses. The `filesystem` provider reads the token from `/var/run/sigstore/cosign/oidc-token`.

## Step 4: Commit on a new branch and push

Create the branch, make two commits, and push:

```sh
git checkout -b feature/signed main
printf 'feature: count items\n' >> src/app.txt
git commit -am "Count items"
printf 'feature: list items\n' >> src/app.txt
git commit -am "List items"
git push -u origin feature/signed
```

Each `git commit` calls gitsign, which gets a certificate from the private Fulcio and records the signing in Rekor. If a commit fails with `gpg failed to sign the data`, run it again with `GITSIGN_LOG=/tmp/gitsign.log` in front and read that file.

## Step 5: Verify like the grader

Check every commit on the branch with the expected identity and the cluster's issuer:

```sh
ISSUER="$(cat /trust/issuer)"
for commit in $(git rev-list origin/main..origin/feature/signed); do
  gitsign verify --certificate-identity="https://kubernetes.io/namespaces/workstation/serviceaccounts/developer" \
    --certificate-oidc-issuer="$ISSUER" "$commit" >/dev/null 2>&1 && echo "OK $commit" || echo "FAIL $commit"
done
```

Both commits print `OK`.

## Step 6: Submit

Send the lab for grading from your machine:

```sh
astrona submit -c sections/section-010/module-01/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| `git config --global` instead of `--local` | Signing works, but the grader reads the repository's own settings and finds them empty |
| `git commit -S` without `commit.gpgsign` | The commits are signed, but the next commit without `-S` is not, and the configuration check fails |
| Leaving `gitsign.fulcio` unset | gitsign uses `fulcio.sigstore.dev` and tries a browser login, so the commit fails |
| Verifying with `git verify-commit` | It passes for any accepted signer; it does not prove the signer is `developer` |
