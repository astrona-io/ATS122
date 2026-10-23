# Solution: Make A Go Verifier Check Who Signed

Work the task yourself first. Running `astrona submit -c sections/section-020/module-01/labs/lab-01` after a step tells you which checks pass.

The grader builds `/work/verify-blob` and runs the program on three cases: the good file must pass, and the wrong signer and the changed file must fail with a non-zero exit code.

## Step 1: Reproduce the problem

Define the helpers on your machine, build the program, and run it on the case that must fail:

```sh
gorun() { kubectl -n workstation exec -i deploy/go-runner -- "$@"; }
put_file() { kubectl -n workstation exec -i "deploy/$1" -- sh -c "cat > '$3'" < "$2"; }
gorun sh -c 'cd /work/verify-blob && go build -o verify-blob .'
gorun sh -c '/work/verify-blob/verify-blob --trusted-root /trust/trusted_root.json \
  --bundle /work/data/other.txt.sigstore.json --artifact /work/data/other.txt \
  --identity https://kubernetes.io/namespaces/workstation/serviceaccounts/developer \
  --issuer "$(cat /trust/issuer)"; echo "exit code $?"'
```

The program prints `VERIFIED` with the `intruder` identity, and exit code `0`. It should have refused the file.

## Step 2: Read the program

Copy it to your machine and read the end of `run`:

```sh
gorun cat /work/verify-blob/main.go > main.go
```

Two lines are wrong. The policy uses `verify.WithoutIdentitiesUnsafe()`, so the verifier never checks who signed; the `identity` and `issuer` flags are read but never used. And when `verifier.Verify` returns an error, the program prints a warning and returns `nil`, so `main` exits with code `0` even for a changed file.

## Step 3: Fix the policy and the error handling

In `run`, build the expected identity from the flags, use it in the policy, and return the error. Replace the end of the function, from the comment `// TODO: check who signed the file.` down to the `if err != nil` block, with:

```go
	certID, err := verify.NewShortCertificateIdentity(issuer, "", identity, "")
	if err != nil {
		return fmt.Errorf("building identity: %w", err)
	}

	result, err := verifier.Verify(signedBundle,
		verify.NewPolicy(verify.WithArtifact(artifact), verify.WithCertificateIdentity(certID)))
	if err != nil {
		return err
	}
```

Keep the `fmt.Printf("VERIFIED ...")` lines after it. Copy the file back and build:

```sh
put_file go-runner main.go /work/verify-blob/main.go
gorun sh -c 'cd /work/verify-blob && go build -o verify-blob .'
```

## Step 4: Test all three cases

Run the program on the good file, the wrong signer and the changed file:

```sh
for test in "release.txt.sigstore.json release.txt" "other.txt.sigstore.json other.txt" "release.txt.sigstore.json release-tampered.txt"; do
  set -- $test
  gorun sh -c "/work/verify-blob/verify-blob --trusted-root /trust/trusted_root.json --bundle /work/data/$1 --artifact /work/data/$2 --identity https://kubernetes.io/namespaces/workstation/serviceaccounts/developer --issuer \"\$(cat /trust/issuer)\"; echo \"$2: exit code \$?\""
done
```

`release.txt` exits with `0`. `other.txt` fails because no certificate identity matched, and `release-tampered.txt` fails because the digest does not match; both exit with `1`.

## Step 5: Submit

```sh
astrona submit -c sections/section-020/module-01/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Fixing only the identity | The changed file still exits with `0`, because the error is swallowed |
| Fixing only the error handling | The `intruder` file still passes, because no identity is checked |
| A SAN regular expression `.*` | It is the same as no identity check; the wrong signer passes |
| Hard-coding the developer's identity | It works today, but the `--identity` flag no longer means anything |
