# Solution: Accept Two Signers With A Pattern

Work the task yourself first. Running `astrona submit -c sections/section-020/module-02/labs/lab-01` after a step tells you which checks pass.

The grader builds `/work/verify-blob` and runs the program with the pattern for `developer` and `ci-bot`, with a narrower pattern for `ci-bot` only, and with no pattern.

## Step 1: Reproduce the problem

Define the helpers on your machine, build the program, and run it on the good file with the pattern:

```sh
gorun() { kubectl -n workstation exec -i deploy/go-runner -- "$@"; }
put_file() { kubectl -n workstation exec -i "deploy/$1" -- sh -c "cat > '$3'" < "$2"; }
gorun sh -c 'cd /work/verify-blob && go build -o verify-blob .'
gorun sh -c '/work/verify-blob/verify-blob --trusted-root /trust/trusted_root.json \
  --bundle /work/data/release.txt.sigstore.json --artifact /work/data/release.txt \
  --identity-regexp "^https://kubernetes\.io/namespaces/workstation/serviceaccounts/(developer|ci-bot)\$" \
  --issuer "$(cat /trust/issuer)"; echo "exit code $?"'
```

The program prints `FAILED` and exits with code `1`, although the developer is allowed. Run it again without `--identity-regexp`: it prints `VERIFIED` and exits with `0`, although no signer was named.

## Step 2: Read the program

Copy it to your machine and read the end of `run`:

```sh
gorun cat /work/verify-blob/main.go > main.go
```

Two things are wrong. The pattern is passed as the third argument of `verify.NewShortCertificateIdentity`, which is the exact SAN, so it is compared as plain text and never matches a real identity. And when the flag is empty, the policy uses `verify.WithoutIdentitiesUnsafe()`, so a missing option widens the policy to every signer.

## Step 3: Use the pattern argument and require it

The fourth argument of `verify.NewShortCertificateIdentity` is the SAN as a regular expression. Replace the block from `policy := verify.NewPolicy(...WithoutIdentitiesUnsafe())` down to the closing brace of the `if` with:

```go
	if identityRegexp == "" {
		return errors.New("--identity-regexp is required")
	}
	certID, err := verify.NewShortCertificateIdentity(issuer, "", "", identityRegexp)
	if err != nil {
		return fmt.Errorf("building identity: %w", err)
	}
	policy := verify.NewPolicy(verify.WithArtifact(artifact), verify.WithCertificateIdentity(certID))
```

Add `"errors"` to the imports. Copy the file back and build:

```sh
put_file go-runner main.go /work/verify-blob/main.go
gorun sh -c 'cd /work/verify-blob && go build -o verify-blob .'
```

## Step 4: Test the cases

Run the program on the four files with the pattern, and once without a pattern:

```sh
for test in "release.txt release.txt" "ci-build.txt ci-build.txt" "other.txt other.txt" "release.txt release-tampered.txt"; do
  set -- $test
  gorun sh -c "/work/verify-blob/verify-blob --trusted-root /trust/trusted_root.json --bundle /work/data/$1.sigstore.json --artifact /work/data/$2 --identity-regexp '^https://kubernetes\.io/namespaces/workstation/serviceaccounts/(developer|ci-bot)\$' --issuer \"\$(cat /trust/issuer)\"; echo \"$2: exit code \$?\""
done
gorun sh -c '/work/verify-blob/verify-blob --trusted-root /trust/trusted_root.json --bundle /work/data/release.txt.sigstore.json --artifact /work/data/release.txt --issuer "$(cat /trust/issuer)"; echo "no pattern: exit code $?"'
```

The first two exit with `0`. `other.txt` fails because the SAN of the `intruder` service account does not match the pattern, `release-tampered.txt` fails because the digest does not match, and the run without a pattern fails because the flag is required; all three exit with `1`.

## Step 5: Submit

```sh
astrona submit -c sections/section-020/module-02/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| A pattern of `.*` hard-coded in the program | The intruder's file passes, and the grader's narrower pattern is ignored |
| Hard-coding the two identities | It works for the first pattern, but the `ci-bot` only pattern still accepts the developer's file |
| Fixing only the pattern argument | A run without a pattern still accepts every file |
| Fixing only the empty-flag case | A given pattern is still compared as plain text, so every file is refused |
