# Testing A Verifier With Broken Bundles

A verifier that accepts a good bundle has passed only half of its test. The other half is proof that it refuses every bad one, and for each bad one it must refuse for the right reason. This part builds bad bundles from the good one with `jq`, runs the verifier from the earlier program against them, and shows what each failure means.

## Look at the bundle first

A bundle is JSON, so `jq` can read and change it. Open a shell variable for the workstation pod, which has `jq`, and list the top-level keys of the developer's bundle:

<!-- astrona:playground:renew -->

```sh
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
ws jq 'keys' /tmp/data/release.txt.sigstore.json
ws jq '.verificationMaterial | keys' /tmp/data/release.txt.sigstore.json
```

The first command lists the top-level keys of the bundle. The second lists the keys of `verificationMaterial`, which holds the certificate and the evidence of the signing. The signature itself is in a separate key next to it. Read the output before you write the next filter, because the exact key names depend on the bundle version.

## Build three broken bundles

Each broken bundle changes one thing. Define a helper that reads a filter, applies it to the developer's bundle on the workstation and writes the result into `go-runner`:

```sh
break_bundle() {
  ws jq "$1" /tmp/data/release.txt.sigstore.json \
    | kubectl -n workstation exec -i deploy/go-runner -- sh -c "cat > '$2'"
}
```

The first broken bundle has no transparency log entries:

```sh
break_bundle '.verificationMaterial.tlogEntries = []' /tmp/no-tlog.json
```

The second keeps the signature but changes one character of it. The jq filter below reads the signature value and replaces its first character:

```sh
break_bundle '.messageSignature.signature |= ("A" + .[1:])' /tmp/bad-signature.json
```

The third removes the signature completely:

```sh
break_bundle 'del(.messageSignature)' /tmp/no-signature.json
```

If a filter fails because a key has another name in your bundle, use the key names that the two commands printed. The idea stays the same: change one part and keep the rest.

## Run the verifier on each one

Run the verifier from the earlier program against each broken bundle with the correct file and the correct identity. Define the command once:

```sh
gorun() { kubectl -n workstation exec -i deploy/go-runner -- "$@"; }
check() {
  gorun sh -c "/work/verify-blob/verify-blob --trusted-root /trust/trusted_root.json \
    --bundle '$1' --artifact /work/data/release.txt \
    --identity https://kubernetes.io/namespaces/workstation/serviceaccounts/developer \
    --issuer \"\$(cat /trust/issuer)\"; echo \"exit code \$?\""
}
check /tmp/no-tlog.json
check /tmp/bad-signature.json
check /tmp/no-signature.json
```

All three must print `FAILED` and exit code `1`. The error text tells you which check caught the change: a missing log entry is refused by the transparency log threshold, a changed signature is refused by the signature check, and a bundle with no signature is refused when the bundle is loaded or verified. Read each message; if two different breakages give the same message, your test cannot tell the checks apart.

## What a complete test set contains

Build a test set that covers each check once, so that a change in the verifier shows which check stopped working:

| Case | Expected result | Check that must catch it |
| --- | --- | --- |
| Good file, expected signer | Accepted | None |
| Changed file, original bundle | Refused | Digest of the file against the bundle |
| File from another signer | Refused | Certificate identity in the policy |
| Bundle without log entries | Refused | Transparency log threshold |
| Bundle with a changed signature | Refused | Signature check |

A verifier that passes only the first row is no better than one that accepts everything. Add the table to your test script and run it after every change, including the dependency updates that change sigstore-go itself.

## Common pitfalls

> [!WARNING]
> - **Testing only the good path.** A verifier that accepts everything passes that test. Always include files that must fail.
> - **Changing two things in one broken bundle.** You can no longer tell which check refused it. Change exactly one part per case.
> - **Reading only the exit code.** A verifier can exit with `1` because the file is missing, not because the check worked. Read the error text of each failure.
