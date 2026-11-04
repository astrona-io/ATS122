# Solution: Pin A GitHub Workflow In The Release Policy

Work the task yourself first. Running `astrona submit -c sections/section-030/module-03/labs/lab-01` after a step tells you which checks pass.

The grader reads the policy with `print-policy`, changes the ref in a copy of the signers file, and runs `verify` on the two folders.

## Step 1: Reproduce the problems

Define the helpers on your machine and read the policy:

```sh
pyrun() { kubectl -n workstation exec -i deploy/py-runner -- "$@"; }
put_file() { kubectl -n workstation exec -i "deploy/$1" -- sh -c "cat > '$3'" < "$2"; }
pyrun python /work/policy_check.py print-policy
pyrun python /work/policy_check.py verify /work/release-good; echo "exit code $?"
```

The GitHub line shows an identity without `/.github/workflows/` and the issuer `https://github.com`. The good folder is refused, because the policy needs both signers at the same time.

## Step 2: Read the script

```sh
pyrun cat /work/policy_check.py > policy_check.py
```

Three lines are wrong. In `identity_for`, the GitHub identity leaves out `/.github/workflows/` between the repository and the workflow file. `GITHUB_ISSUER` is `https://github.com`, which is not the issuer of GitHub Actions tokens. And `build_policy` returns `AllOf`, which accepts a file only when every listed signer accepts it. A file has one signer, so a list of allowed signers needs `AnyOf`.

## Step 3: Fix the three lines

Change the import to `from sigstore.verify.policy import AnyOf, Identity`, set the issuer, and fix the identity and the policy:

```python
GITHUB_ISSUER = "https://token.actions.githubusercontent.com"

        return (
            f"https://github.com/{signer['repository']}"
            f"/.github/workflows/{signer['workflow']}@{signer['ref']}"
        )

    return AnyOf([Identity(identity=identity_for(s), issuer=issuer_for(s)) for s in signers])
```

The `ref` stays in the identity because it is read from the signer, so a different ref gives a different identity. Copy the file back:

```sh
put_file py-runner policy_check.py /work/policy_check.py
```

## Step 4: Test the cases

```sh
pyrun python /work/policy_check.py print-policy
pyrun python /work/policy_check.py verify /work/release-good; echo "exit code $?"
pyrun python /work/policy_check.py verify /work/release-bad; echo "exit code $?"
```

The first line of the policy output is the GitHub signer with the full workflow reference and the GitHub Actions issuer. The good folder prints two `VERIFIED` lines and exits with `0`. The bad folder prints `FAILED` for `a-changed.tar.gz` and `b-intruder.tar.gz`, `VERIFIED` for `c-ci.tar.gz`, and exits with `1`.

## Step 5: Submit

```sh
astrona submit -c sections/section-030/module-03/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| `UnsafeNoOp` instead of the list | The intruder's file passes, and the last check fails |
| Hard-coding the ref `refs/tags/v1.0.0` | The check that changes the ref fails |
| Fixing the identity but keeping `AllOf` | The policy prints correctly, but the good folder is still refused |
| Removing the GitHub signer from the file | The signers file is part of the task and must stay as it is |
