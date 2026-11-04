# Writing A Workflow Policy

A release gate answers one question for each file: did a workflow I trust sign this? In sigstore-python the answer is a policy object. This part builds that policy for a GitHub workflow, shows the two ways to check a GitHub signature from the command line, and reads a script that builds one policy from a list of signers, which is the shape a real release gate has.

## The identity of a workflow

An `Identity` policy takes the subject alternative name and the issuer, and it accepts a certificate only when both match exactly. For a GitHub workflow the SAN is the workflow reference you saw in the certificate. Write it from three facts: the repository, the path of the workflow file and the Git reference.

```python
from sigstore.verify.policy import Identity

policy = Identity(
    identity="https://github.com/acme/inventory-app/.github/workflows/release.yml@refs/tags/v1.0.0",
    issuer="https://token.actions.githubusercontent.com",
)
```

The names are an example. The repository `acme/inventory-app` is made up and the playground has no file signed by it. Three details matter: the path includes `/.github/workflows/`, the file name includes its extension, and the reference includes `refs/tags/` or `refs/heads/`. If any of them is wrong, the policy never matches and every file is refused.

## More than the identity

The module `sigstore.verify.policy` also has policy classes for the GitHub extensions of the previous part. List what your installed version offers, and do not rely on a name from memory, because the classes changed between versions:

<!-- astrona:playground:renew -->

```sh
pyrun() { kubectl -n workstation exec -i deploy/py-runner -- "$@"; }
pyrun python -c "import sigstore.verify.policy as p; print([n for n in dir(p) if n.startswith(('GitHub', 'OIDC'))])"
```

The command prints the names that start with `GitHub` or `OIDC`. These classes take the expected value of one extension, for example a repository or a trigger. You combine them with `AllOf` and the `Identity`, so a file passes only when the SAN and the extension agree.

## The command line

`sigstore verify identity` takes the SAN and the issuer as plain values. `sigstore verify github` fills the GitHub issuer for you and has options for the GitHub extensions. Print the options of your installed version and compare them:

```sh
pyrun sigstore verify github --help
```

The options differ between versions, so use the help page as the reference. In a release script, prefer `verify identity` with the full workflow reference. The reference holds the repository, the workflow file and the Git reference in one value, so the script has one thing to review.

## A policy from a list of signers

A release usually has more than one trusted signer. `/work/policy_check.py` reads them from `/work/signers.json`, builds one `Identity` for each and combines them with `AnyOf`. Look at the signers file, and at the policy the script builds from it:

```sh
pyrun cat /work/signers.json
pyrun python /work/policy_check.py print-policy
```

The file lists a GitHub workflow with `repository`, `workflow` and `ref`, and a service account with `namespace` and `serviceaccount`. The second command prints one line for each signer with the kind, the identity and the issuer. The GitHub line shows the full workflow reference and the GitHub issuer. Now check the two release folders:

```sh
pyrun python /work/policy_check.py verify /work/release-good; echo "exit code $?"
pyrun python /work/policy_check.py verify /work/release-bad; echo "exit code $?"
```

The good folder passes because `ci-bot` is in the list. The bad folder names the changed file and the file signed by `intruder`. The GitHub signer is in the list too, but no file in this cluster is signed by it, so it matches nothing; that is correct, because a policy lists who may sign, not who did.

## Why the list is data

The signers sit in a file, and the script turns each entry into an identity with one function. Adding a workflow means adding one entry for review, and the code that builds the identity is written once. A policy built by pasting strings in several places drifts: one place gets the new tag and another place keeps the old one. A single function that builds the reference from three fields also makes the common mistakes easy to see in one place.

You can now write a policy for a GitHub workflow and for a list of signers. The next question is which Git reference to pin, because the reference decides who can produce a matching signature.

## Common pitfalls

> [!WARNING]
> - **A missing `/.github/workflows/`.** The reference is the workflow path in the repository, not just the file name.
> - **The wrong issuer.** The GitHub Actions issuer is `https://token.actions.githubusercontent.com`. The address `https://github.com` is not an issuer of identity tokens.
> - **`AllOf` for a list of signers.** `AllOf` accepts a file only when every listed signer accepts it. A file has one signer, so use `AnyOf`.
> - **Using `verify github` for a non-GitHub signer.** It assumes the GitHub issuer.

## Your mission: Pin A GitHub Workflow In The Release Policy

You can now build a policy from a list of signers that includes a GitHub workflow. The graded lab gives you a script that builds a wrong workflow reference, uses the wrong issuer and combines the signers with `AllOf`, and asks you to fix all three.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-122-playground-030-03
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS122.git -c sections/section-030/module-03/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-030/module-03/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-122-lab-030-03
astrona start ats-122-playground-030-03
```
