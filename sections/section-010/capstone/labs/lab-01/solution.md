# Solution: Re-Sign A Release Branch With The Right Identity

Work the task yourself first. Running `astrona submit -c sections/section-010/capstone/labs/lab-01` after a step tells you which checks pass.

The grader checks three things: every commit on `release/1.0` after `main` verifies as `developer`, the branch keeps its four commits, messages and final files, and the repository-local signing settings.

## Step 1: Find the bad commits

Open a shell in the workstation and check every commit of the branch with the expected identity:

```sh
kubectl -n workstation exec -it deploy/workstation -- sh
cd /root/inventory-app
ISSUER="$(cat /trust/issuer)"
DEVELOPER="https://kubernetes.io/namespaces/workstation/serviceaccounts/developer"
for commit in $(git rev-list main..release/1.0); do
  gitsign verify --certificate-identity="$DEVELOPER" --certificate-oidc-issuer="$ISSUER" "$commit" >/dev/null 2>&1 \
    && echo "OK   $(git log -1 --format='%h %s' "$commit")" || echo "FAIL $(git log -1 --format='%h %s' "$commit")"
done
```

Two commits fail: "Release: fix a typo in the counter" and "Release: change the price rules". Look at each one:

```sh
git cat-file commit "$(git log --format=%H --grep='fix a typo' release/1.0)" | head -8
gitsign verify --certificate-identity-regexp='.*' --certificate-oidc-issuer="$ISSUER" "$(git log --format=%H --grep='price rules' release/1.0)"
```

The typo commit has no `gpgsig` header: it is unsigned. The price commit has a valid signature, and the "Good signature" line names the identity `https://kubernetes.io/namespaces/workstation/serviceaccounts/intruder`. Its signature is fine; its signer is not.

## Step 2: Configure signing for the clone

Set the Git and gitsign settings for this repository:

```sh
git config --local gpg.format x509
git config --local gpg.x509.program gitsign
git config --local commit.gpgsign true
git config --local gitsign.fulcio "$FULCIO_URL"
git config --local gitsign.rekor "$REKOR_URL"
git config --local gitsign.tokenProvider filesystem
```

## Step 3: Re-sign every commit of the branch

A signature covers the whole commit object, including the committer and the date, so re-signing makes new commits. `git rebase` with `--force-rebase` rewrites every commit after `main`, even the ones it could keep, and `--gpg-sign` signs each new commit. The files and messages stay the same:

```sh
git checkout release/1.0
git rebase --force-rebase --gpg-sign main
```

gitsign signs four times, each time as `developer`, because the workstation's token belongs to `developer`. Run the loop from Step 1 again: all four commits print `OK`.

## Step 4: Push the rewritten branch

The new commits replace the old ones, so the push must be forced:

```sh
git push --force origin release/1.0
```

Check that the content did not change. The tree of the branch tip is the same as before the rebase, and the messages are the same:

```sh
git log --reverse --format=%s main..origin/release/1.0
```

## Step 5: Submit

Send the capstone for grading from your machine:

```sh
astrona submit -c sections/section-010/capstone/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Squashing the branch into one signed commit | It verifies, but the branch no longer has four commits with their messages |
| Re-signing only the last commit | The unsigned and the wrongly signed commits below it still fail |
| Dropping the two bad commits | The final files change, and the history check fails |
| Verifying with `git verify-commit` | The `intruder` commit passes, because Git's check does not look at the signer |
