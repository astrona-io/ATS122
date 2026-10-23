# Section 010: Signing Git Commits With Gitsign

A Git commit carries an author name and an email address, and Git accepts whatever you type there. Anyone who can push to a repository can write a commit in your name. A signed commit adds proof of who made it, and gitsign makes that proof keyless: it signs with a short-lived certificate from Fulcio, Sigstore's certificate authority, and records the signing in Rekor, Sigstore's transparency log.

This section teaches the whole loop on a private Sigstore stack in your cluster: what gitsign puts into a commit, how to configure Git and gitsign for an instance, and how to verify who signed a commit. In this stack, Fulcio accepts Kubernetes service account tokens, so the signer of every commit is a service account.

**Topic covered:** Signing Git commits with gitsign

## What you will learn

- What a commit signature is, where Git stores it, and what gitsign adds to it.
- How a keyless signing works: identity token, Fulcio certificate, signature, Rekor entry.
- The difference between gitsign's online and offline Rekor modes.
- The Git settings `gpg.format`, `gpg.x509.program`, `commit.gpgsign` and `tag.gpgsign`.
- The gitsign settings for an instance: `gitsign.fulcio`, `gitsign.rekor`, `gitsign.tokenProvider`, and the credential cache.
- Verifying a commit with `gitsign verify`, `--certificate-identity` and `--certificate-oidc-issuer`, and why `git verify-commit` is not enough.
- Why GitHub shows gitsign commits as unverified.

## The learning path

The module starts at its landing page, which also launches the playground. The playground holds Gitea with the repository `gitops/inventory-app`, a clone of it in the workstation pod, and a branch `demo/signed` with one signed commit.

1. How Gitsign Signs A Commit
2. Configuring Git To Sign With Gitsign, followed by the lab **Sign Every Commit With Gitsign**
3. Verifying Who Signed A Commit
4. Summary

## Section capstone: Re-Sign A Release Branch With The Right Identity

The branch `release/1.0` has four commits. One is unsigned, and one is signed by the service account `intruder`. The task is to make every commit on the branch signed by the developer, without changing a single message or file, and to prove it with `gitsign verify`. Work it after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS122.git -c sections/section-010/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-010/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-122-capstone-010
```
