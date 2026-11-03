# Solution: Make The Release Check Accept Two Signers

Work the task yourself first. Running `astrona submit -c sections/section-030/module-02/labs/lab-01` after a step tells you which checks pass.

The grader runs your check on the good folder, on the bad folder, and on a folder that holds only the intruder's file.

## Step 1: Reproduce the problems

Define the helpers on your machine and run the check on both folders:

```sh
pyrun() { kubectl -n workstation exec -i deploy/py-runner -- "$@"; }
put_file() { kubectl -n workstation exec -i "deploy/$1" -- sh -c "cat > '$3'" < "$2"; }
pyrun python /work/check_release.py /work/release-good; echo "exit code $?"
pyrun python /work/check_release.py /work/release-bad; echo "exit code $?"
```

On the good folder the check reports `app.tar.gz` as verified and `tools.tar.gz` as failed, although `developer` is an allowed signer. On the bad folder it reports the first failure and stops. Both runs exit with `0`.

## Step 2: Read the script

Copy it to your machine:

```sh
pyrun cat /work/check_release.py > check_release.py
```

Three things are wrong. The policy is one `Identity` for `ci-bot`, so the developer's file is refused. The loop has a `break` after the first failure, so later files are never examined. And `main` ends with `return 0`, whatever happened in the loop.

## Step 3: Fix all three

Import `AnyOf` with `Identity`, build the policy from a list of allowed signers, count the failures, and return the count as the exit code. Replace the body of `main` after the `verifier` line with:

```python
    policy = AnyOf([Identity(identity=BASE + name, issuer=ISSUER) for name in ALLOWED_SIGNERS])

    failures = 0
    for artifact in sorted(folder.glob("*.tar.gz")):
        bundle_path = Path(f"{artifact}.sigstore.json")
        try:
            bundle = Bundle.from_json(bundle_path.read_bytes())
            verifier.verify_artifact(artifact.read_bytes(), bundle, policy)
        except (VerificationError, OSError, ValueError) as error:
            print(f"FAILED {artifact.name}: {error}")
            failures += 1
            continue
        print(f"VERIFIED {artifact.name}")

    print(f"{failures} file(s) failed")
    return 1 if failures else 0
```

Also add `ALLOWED_SIGNERS = ["developer", "ci-bot"]` under the `BASE` line, and change the import to `from sigstore.verify.policy import AnyOf, Identity`. Copy the file back:

```sh
put_file py-runner check_release.py /work/check_release.py
```

## Step 4: Test the cases

```sh
pyrun python /work/check_release.py /work/release-good; echo "exit code $?"
pyrun python /work/check_release.py /work/release-bad; echo "exit code $?"
```

The good folder prints two `VERIFIED` lines and exits with `0`. The bad folder prints `FAILED` for `a-changed.tar.gz`, `b-intruder.tar.gz` and `d-changed.tar.gz`, `VERIFIED` for `c-ci.tar.gz`, and exits with `1`.

## Step 5: Submit

```sh
astrona submit -c sections/section-030/module-02/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| `UnsafeNoOp` instead of a list of signers | The intruder's file passes, and the third check fails |
| Fixing only the policy | The bad folder still exits with `0` and reports only the first failure |
| Removing the `break` but keeping `return 0` | Every failure is printed, but the pipeline still sees success |
| Returning `1` after the first failure | The exit code is right, but later bad files are never named |
