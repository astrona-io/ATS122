# Verifying History In A Pipeline

A review that checks signatures by hand does not scale. The check that protects a branch must run on every change, say exactly which commit failed, and stop the pipeline when anything fails. This part writes that check as a shell script, explains how to allow more than one signer, and covers the commits that a hosting service creates.

## What the pipeline check must do

A pipeline step is a command with an exit code. The step passes when the code is `0` and stops the pipeline otherwise. A good history check therefore does four things. It lists the commits that are new in the change, with `git rev-list BASE..TIP`. It verifies every one, not only the newest. It prints one line per commit, so the person reading the log sees which commit failed and why. And it exits with a non-zero code when at least one commit failed, after it has checked all of them.

The last point is easy to get wrong in both directions. A script that exits at the first failure hides the other bad commits and makes the author fix them one push at a time. A script that prints the failures but exits with `0` lets them through.

## The script

The script takes a base and a tip, and reads the allowed identities and the issuer from environment variables. It uses `--certificate-identity-regexp`, which takes a regular expression, so one run can allow more than one service account. Save this as `verify-history.sh` on your machine:

```sh
#!/bin/sh
# Verifies every commit in BASE..TIP with gitsign.
# Usage: verify-history.sh BASE TIP
# Environment: ALLOWED_IDENTITY_REGEXP and ISSUER are required.
# Exit code: 0 when every commit is signed by an allowed identity, 1 otherwise.
set -u

base="$1"
tip="$2"
failures=0
checked=0

for commit in $(git rev-list --reverse "$base..$tip"); do
  checked=$((checked + 1))
  subject="$(git log -1 --format='%h %s' "$commit")"
  if gitsign verify \
      --certificate-identity-regexp="$ALLOWED_IDENTITY_REGEXP" \
      --certificate-oidc-issuer="$ISSUER" "$commit" >/dev/null 2>&1; then
    echo "OK     $subject"
  else
    echo "FAILED $subject"
    failures=$((failures + 1))
  fi
done

echo "checked $checked commits, $failures failed"
[ "$failures" -eq 0 ] && [ "$checked" -gt 0 ]
```

The last line makes the script fail when there is nothing to check. A range with zero commits usually means a wrong base, and a gate that passes on an empty range passes by mistake. Copy the script into the workstation:

<!-- astrona:playground:renew -->

```sh
kubectl -n workstation exec -i deploy/workstation -- sh -c 'cat > /root/verify-history.sh' < verify-history.sh
```

## Build a history to check

The script needs a history with a signed commit from each service account and one commit with no signature. In the workstation shell, make three commits on a new branch. The first is signed by `developer`, with the token of the pod. The second has no signature. The third is signed by `developer` again:

```sh
cd /root/inventory-app
export GITSIGN_FULCIO_URL="$FULCIO_URL" GITSIGN_REKOR_URL="$REKOR_URL" GITSIGN_TOKEN_PROVIDER=filesystem
git config --local gpg.format x509
git config --local gpg.x509.program gitsign
git checkout -q -B practice/history main
printf 'history: one\n' >> src/app.txt && git commit -q -a -S -m "History one"
printf 'history: two\n' >> src/app.txt && git -c commit.gpgsign=false commit -q -a -m "History two"
printf 'history: three\n' >> src/app.txt && git commit -q -a -S -m "History three"
```

Run the script with an exact pattern for `developer`. The characters `^` and `$` anchor the pattern to the whole identity, and the dots are escaped, so only that one address matches:

```sh
export ISSUER="$(cat /trust/issuer)"
export ALLOWED_IDENTITY_REGEXP='^https://kubernetes\.io/namespaces/workstation/serviceaccounts/developer$'
sh /root/verify-history.sh main practice/history; echo "exit code $?"
```

The script prints `OK` for the first and third commit and `FAILED` for the second. It ends with `checked 3 commits, 1 failed`, and the exit code is `1`. Pipelines run exactly this kind of script, and the exit code is what stops them.

## Allowing more than one signer

A team often allows a person and a bot. Change the pattern so that it accepts two service accounts, and nothing else:

```sh
export ALLOWED_IDENTITY_REGEXP='^https://kubernetes\.io/namespaces/workstation/serviceaccounts/(developer|ci-bot)$'
sh /root/verify-history.sh main practice/history; echo "exit code $?"
```

The result for these three commits is the same, because the unsigned commit still fails. The point is the pattern. It lists the allowed accounts one by one. A pattern such as `.*` or `serviceaccounts/.*` is a decision to accept every signer or every account of the namespace, and a new account would then be allowed without anyone reviewing it. The same applies to `--certificate-oidc-issuer-regexp`: use the exact issuer when you know it.

## Commits made by the hosting service

A hosting service can create commits that you did not sign. When a pull request is merged with a merge commit or a squash, the service writes a new commit on the target branch and signs it, if at all, with its own key. That commit is not signed by gitsign, so the script reports it as `FAILED`.

There are two clean ways to handle this. The first is to list only the commits that people or bots wrote, by skipping merge commits with `git rev-list --no-merges`. The second is to verify the pull request branch before the merge, which is where the commits you want to check still exist as written. A squash merge replaces them with one new commit, so with squash merges the check has to run on the branch before the merge. Pick one rule for the repository, write it down, and make the pipeline follow it.

You can now write a pipeline check that verifies every commit in a range, reports each failure and stops the pipeline. What is still open is what to do when signing itself fails, before there is anything to verify.

## Common pitfalls

> [!WARNING]
> - **An unanchored pattern.** Without `^` and `$`, a pattern matches anywhere in the identity, so a longer address that contains your pattern passes.
> - **An empty range.** If `BASE..TIP` has no commits, a loop checks nothing and passes. Treat an empty range as an error.
> - **Exiting at the first failure.** The author then sees one bad commit per run. Check all commits, print each result, and fail at the end.
> - **Checking merge commits that the service created.** They are not signed by gitsign. Decide whether to skip them or to verify before the merge.
