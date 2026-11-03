# Reading The Verification Result

When `verifier.Verify` returns no error, it also returns a result: a record of what the verifier proved. Most programs ignore it and print "OK". That wastes the most useful part of the call, because the result is how a program logs who signed a file, which provider vouched for them, and when the signing happened. This part shows which fields to read and what each one means.

## What Verify returns

`verifier.Verify(bundle, policy)` returns two values: a pointer to a result and an error. When the error is not `nil`, the result is not usable and the file must be refused. When the error is `nil`, every check you asked for has passed and the result describes the evidence:

| Field | Type | What it tells you |
| --- | --- | --- |
| `result.Signature.Certificate.SubjectAlternativeName` | string | The signer that the certificate names |
| `result.Signature.Certificate.Issuer` | string | The identity provider that vouched for the signer |
| `result.VerifiedTimestamps` | list | The trusted times the verifier used, each with a type and a time |

The first two fields are the values that your policy compared. Reading them back is not redundant: when the policy is a pattern, the result is the only place that tells you which signer matched.

## Log the signer, not the pattern

Compare two log lines for the same accepted file:

```text
verified release.txt with pattern ^https://kubernetes\.io/namespaces/workstation/serviceaccounts/(developer|ci-bot)$
verified release.txt signed by https://kubernetes.io/namespaces/workstation/serviceaccounts/developer
```

The first line says what the policy allowed. The second line says who actually signed. An audit trail needs the second line, because it is the one that can be compared with a list of people later. Print the SAN and the issuer from the result, not the flag values.

## Print the trusted times

Add a loop to the end of `run`, after the successful verification:

<!-- astrona:playground:renew -->

```go
	for _, ts := range result.VerifiedTimestamps {
		fmt.Printf("time source %s: %s\n", ts.Type, ts.Timestamp.UTC().Format(time.RFC3339))
	}
```

Add `"time"` to the imports, rebuild, and run the verifier on `release.txt`. Each line names where a trusted time came from and what it was. With the thresholds of the private stack the list holds the time from the Rekor entry.

Compare the printed time with the log entry in the bundle, which you can read on the workstation:

```sh
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
ws jq '.verificationMaterial.tlogEntries[0].integratedTime' /tmp/data/release.txt.sigstore.json
```

The value is in seconds since the Unix epoch, and the verifier printed the same moment in a readable format. Their equality shows that the time the verifier trusts is the time the log recorded, not a time the signer wrote.

## What the result does not tell you

A successful result does not say that the file is safe, only that it was signed by an identity your policy accepts, at a time that the log confirms. It also does not tell you that the signer still has access today. A certificate lives for minutes, and the verification is about the moment of signing. If a service account was removed yesterday, a file it signed last month still verifies. To act on that, keep your own list of identities that are no longer accepted and check the SAN from the result against it.

## Common pitfalls

> [!WARNING]
> - **Using the result when `err` is not `nil`.** The result can be empty or incomplete. Return the error first and only read the result afterwards.
> - **Logging the policy instead of the signer.** An audit line that holds the pattern cannot tell you which signer matched.
> - **Reading a successful result as "the file is safe".** It means the signer and the evidence match your policy, and nothing about what is inside the file.
