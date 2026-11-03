# Solution: Sign And Verify A Release Tag

Work the task yourself first. Running `astrona submit -c sections/section-010/module-02/labs/lab-01` after a step tells you which checks pass.

The grader checks three things: the local setting `tag.gpgsign`, that `v1.0.0` in Gitea is an annotated tag on the tip of `main` that `gitsign verify-tag` accepts as the service account `developer`, and that `v0.9.0` did not change.

## Step 1: Open the workstation and look at the tags

Open a shell in the workstation pod and list the tags with their types:

```sh
kubectl -n workstation exec -it deploy/workstation -- sh
cd /root/inventory-app
git config --local --list
git tag --list
git cat-file -t v0.9.0
git cat-file tag v0.9.0
```

The clone already has the commit signing settings. `v0.9.0` is an annotated tag (its type is `tag`), and its text has no signature block, so it is unsigned.

## Step 2: Make Git sign every new tag

Set the tag setting for this repository:

```sh
git config --local tag.gpgsign true
```

`tag.gpgsign true` signs every new tag, as if you passed `-s`.

## Step 3: Create and push the signed tag

Check that you are on `main`, create the annotated tag, and push it. The tag is annotated because it has a message, and it is signed because of the setting from Step 2:

```sh
git checkout main
git tag -a v1.0.0 -m "Release 1.0.0"
git cat-file tag v1.0.0
git push origin v1.0.0
```

gitsign gets a certificate from the private Fulcio, signs the tag and records it in Rekor. `git cat-file tag v1.0.0` shows the tag message followed by a signature block that starts with `-----BEGIN SIGNED MESSAGE-----`. If the tag fails with `gpg failed to sign the data`, run the `git tag` command again with `GITSIGN_LOG=/tmp/gitsign.log` and read the file.

## Step 4: Verify like the grader

Check the tag with the expected identity and the cluster's issuer, in a fresh clone:

```sh
ISSUER="$(cat /trust/issuer)"
rm -rf /tmp/check && git clone -q http://gitea.localtest.me:3000/gitops/inventory-app.git /tmp/check
cd /tmp/check
gitsign verify-tag --certificate-identity="https://kubernetes.io/namespaces/workstation/serviceaccounts/developer" \
  --certificate-oidc-issuer="$ISSUER" v1.0.0; echo "exit code $?"
git rev-parse 'v1.0.0^{commit}' origin/main
```

The command exits with code `0`, and the two hashes are the same.

## Step 5: Submit

Send the lab for grading from your machine:

```sh
astrona submit -c sections/section-010/module-02/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| `git tag v1.0.0` on a machine without `tag.gpgsign` | It creates a lightweight tag, which is only a name for a commit and cannot carry a signature |
| Moving `v0.9.0` to sign it | The tag changes, and the grader compares it with the tag the lab started with |
| `git verify-tag` instead of `gitsign verify-tag` | It passes for any accepted signer; it does not prove the signer is `developer` |
| Forgetting `git push origin v1.0.0` | `git push` alone does not send tags, so Gitea has no `v1.0.0` |
