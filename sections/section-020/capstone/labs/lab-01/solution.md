# Solution: Gate A Release Folder With sigstore-go

Work the task yourself first. Running `astrona submit -c sections/section-020/capstone/labs/lab-01` after a step tells you which checks pass.

The grader builds `/work/verify-release`, runs it on the candidate folder (exit code `1`, `FAIL` for exactly `docs.txt`, `notes.txt` and `plugin.bin`, `OK` for the rest) and on the clean folder (exit code `0`).

## Step 1: See what the gate lets through

Define the helpers on your machine, build the program and run it on the candidate:

```sh
gorun() { kubectl -n workstation exec -i deploy/go-runner -- "$@"; }
put_file() { kubectl -n workstation exec -i "deploy/$1" -- sh -c "cat > '$3'" < "$2"; }
gorun sh -c 'cd /work/verify-release && go build -o verify-release .'
gorun sh -c '/work/verify-release/verify-release --trusted-root /trust/trusted_root.json \
  --dir /work/release-candidate \
  --identity https://kubernetes.io/namespaces/workstation/serviceaccounts/developer \
  --issuer "$(cat /trust/issuer)"; echo "exit code $?"'
gorun ls /work/release-candidate
```

The folder has five files, `app.bin`, `config.json`, `docs.txt`, `notes.txt` and `plugin.bin`, and bundles for four of them. The program reports only `notes.txt` as failing, does not mention `docs.txt` at all, and passes `plugin.bin`.

## Step 2: Find the two faults

Copy the program to your machine and read `run`:

```sh
gorun cat /work/verify-release/main.go > main.go
```

Two parts are wrong. Before verifying a file, the loop checks with `os.Stat` whether a bundle exists and silently `continue`s when it does not, so `docs.txt` is never reported. And the identity is built as `verify.NewShortCertificateIdentity(issuer, "", "", ".*")`: the subject alternative name is the regular expression `.*`, which matches any signer, so `plugin.bin`, signed by `intruder`, passes. The `--identity` flag is read and never used.

## Step 3: Fix the program

Build the identity from the flag:

```go
	certID, err := verify.NewShortCertificateIdentity(issuer, "", identity, "")
```

and delete the block that skips files without a bundle, so the loop starts directly with the call to `verifyFile`:

```go
	for _, name := range names {
		if err := verifyFile(verifier, certID, filepath.Join(dir, name)); err != nil {
			fmt.Printf("FAIL %s: %v\n", name, err)
			failed++
			continue
		}
		fmt.Printf("OK %s\n", name)
	}
```

`verifyFile` already loads `<file>.sigstore.json` and returns a "no usable bundle" error when it is missing, so `docs.txt` now fails with a reason. Copy the file back and build:

```sh
put_file go-runner main.go /work/verify-release/main.go
gorun sh -c 'cd /work/verify-release && go build -o verify-release .'
```

## Step 4: Run it on both folders

```sh
for folder in release-candidate release-clean; do
  gorun sh -c "/work/verify-release/verify-release --trusted-root /trust/trusted_root.json --dir /work/$folder --identity https://kubernetes.io/namespaces/workstation/serviceaccounts/developer --issuer \"\$(cat /trust/issuer)\"; echo \"$folder: exit code \$?\""
done
```

On the candidate, the program prints `OK` for `app.bin` and `config.json`, `FAIL` for `docs.txt` (no bundle), `notes.txt` (the digest does not match) and `plugin.bin` (no certificate identity matched), and exits with code `1`. On the clean folder it prints `OK` twice and exits with code `0`.

## Step 5: Submit

```sh
astrona submit -c sections/section-020/capstone/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Deleting `docs.txt` from the folder | The task forbids changing the folder; a real gate cannot delete what it does not like |
| Listing the bad files by name in the code | The next release has other files, and the gate checks nothing |
| A SAN regular expression for any service account in `workstation` | `intruder` lives in `workstation` too, so `plugin.bin` still passes |
| Exiting `0` with a printed list of failures | The release step that runs the gate only reads the exit code |
