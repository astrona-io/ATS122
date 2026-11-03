# Fixing Unsigned And Wrongly Signed Commits

Verification will sooner or later find a commit that is not signed, or is signed by an identity you do not accept. A signature cannot be edited, added or moved by hand, because it covers the whole commit object. This part explains what actually changes when you sign a commit again, shows the two Git commands that do it, and ends with the push that publishes the new history.

## What a new signature changes

A commit's hash is computed from the whole commit object: the tree, the parent, the author, the committer, the dates, the message and the `gpgsig` header. Adding or replacing a signature therefore creates a new commit with a new hash. The old commit still exists in the repository until Git removes it, but no branch points at it any more.

What stays the same is the content you care about: the tree (the files), the message and the author. What changes is the commit hash, the committer date and the signature. Every commit that comes after the changed one has the changed commit as its parent, so those commits get new hashes too. That is why fixing one commit in the middle of a branch means rewriting every commit after it.

The identity in the new signature is the identity of whoever signs now. If the `ci-bot` service account re-signs a commit that `intruder` signed, the new certificate names `ci-bot`. The author line of the commit still names the original author, because gitsign signs the commit as it is.

## Re-sign the last commit

The fastest fix is to amend the newest commit. `git commit --amend --no-edit -S` makes a new commit with the same message and the same files, and signs it. First make a commit that has no signature, so there is something to fix. In the workstation shell, give gitsign its settings in environment variables, and tell Git to use gitsign for this repository:

<!-- astrona:playground:renew -->

```sh
cd /root/inventory-app
export GITSIGN_FULCIO_URL="$FULCIO_URL" GITSIGN_REKOR_URL="$REKOR_URL" GITSIGN_TOKEN_PROVIDER=filesystem
git config --local gpg.format x509
git config --local gpg.x509.program gitsign
git checkout -b practice/resign main
printf 'practice: an unsigned change\n' >> src/app.txt
git -c commit.gpgsign=false commit -am "Add an unsigned change"
```

The `-c commit.gpgsign=false` option turns signing off for this one command, so the commit has no `gpgsig` header. Check it with `gitsign verify`, using the service account `developer` as the expected identity and the cluster issuer:

```sh
ISSUER="$(cat /trust/issuer)"
DEVELOPER="https://kubernetes.io/namespaces/workstation/serviceaccounts/developer"
git log -1 --format='%h %s'
gitsign verify --certificate-identity="$DEVELOPER" --certificate-oidc-issuer="$ISSUER" HEAD; echo "exit code $?"
```

The verification fails and the exit code is not `0`, because there is no signature to check. Now amend the commit with a signature and verify it again:

```sh
git commit --amend --no-edit -S
git log -1 --format='%h %s'
gitsign verify --certificate-identity="$DEVELOPER" --certificate-oidc-issuer="$ISSUER" HEAD; echo "exit code $?"
```

The subject line is the same, the short hash is different, and the verification now succeeds with exit code `0`. Git made a new commit, and gitsign signed it with a fresh certificate from the private Fulcio.

## Re-sign a series of commits

A branch with several bad commits, or a bad commit below the tip, needs a rebase. `git rebase` replays commits on top of a base commit. Two options turn it into a re-signing tool. `--gpg-sign` (short form `-S`) signs every commit that the rebase creates. `--force-rebase` makes Git create new commits even when the commits could stay as they are. Without `--force-rebase`, Git sees that the branch already sits on top of the base and changes nothing, so nothing is signed.

Add a second unsigned commit on the practice branch, then re-sign both commits after `main`:

```sh
printf 'practice: a second unsigned change\n' >> src/app.txt
git -c commit.gpgsign=false commit -am "Add a second unsigned change"
git rebase --force-rebase --gpg-sign main
```

gitsign signs once for each replayed commit, so the rebase asks Fulcio for one certificate per commit. When the rebase ends, check every commit between `main` and the branch with a loop that runs `gitsign verify` on each one:

```sh
for commit in $(git rev-list main..practice/resign); do
  gitsign verify --certificate-identity="$DEVELOPER" --certificate-oidc-issuer="$ISSUER" "$commit" >/dev/null 2>&1 \
    && echo "signed by developer: $commit" || echo "NOT signed by developer: $commit"
done
```

Every line starts with `signed by developer`. If a conflict stops the rebase, Git tells you which file to fix; you resolve it, run `git add` on the file and `git rebase --continue`, and the rest of the commits are signed as before.

## Publish the rewritten branch

A rebased branch no longer contains the commits that Gitea holds, so a normal `git push` is refused. The push has to replace the remote branch. `git push --force-with-lease` does that, and it refuses when somebody else pushed to the branch since your last fetch, which `--force` would overwrite without a word:

```sh
git push --force-with-lease -u origin practice/resign
```

Gitea now holds the signed commits. Anybody who already had the old commits must reset their copy of the branch to the new one, because the old commits and the new commits have the same content but different hashes. For that reason, rewrite only branches that nobody else builds on, and never rewrite a protected branch such as `main`.

Last, compare the old and the new commits. The tree of the branch tip did not change, which proves that the rewrite only added signatures:

```sh
git diff origin/main practice/resign --stat
git log --format='%h %s' main..practice/resign
```

You can now fix an unsigned or wrongly signed commit: amend the newest commit, or rebase a series with `--force-rebase --gpg-sign`, and publish the result with a lease-protected force push. What is still open is how gitsign gets its identity token in places where nobody can log in, such as a pipeline, and how to find the cause when signing fails.

## Common pitfalls

> [!WARNING]
> - **Rebasing without `--force-rebase`.** When the branch already sits on the base, Git does nothing and the bad commits stay as they are.
> - **Using `git push --force` on a shared branch.** It overwrites commits that somebody else may have pushed. Use `--force-with-lease`, and avoid rewriting branches other people use.
> - **Expecting the old identity to stay.** The new signature names whoever signs now. Re-signing a colleague's commit as yourself changes the signer, not the author.
> - **Rewriting a branch that is already merged.** The merge commit points at the old commits. Re-sign before the merge, not after.
