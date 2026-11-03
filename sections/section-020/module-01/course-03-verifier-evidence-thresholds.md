# Verifier Evidence Thresholds

A bundle can carry several kinds of evidence that the signing happened: a signed certificate timestamp from a certificate transparency log, an entry in a transparency log, and sometimes a timestamp from a timestamp authority. The verifier options of sigstore-go set how much of each kind of evidence the verifier demands. This part explains each option, what it protects against, and how the options fit together, so you can choose them on purpose instead of copying them.

## Why a certificate needs a trusted time

A Fulcio certificate is valid for only a few minutes. By the time anyone verifies a file, the certificate has long expired. A verifier therefore does not ask "is the certificate valid now?". It asks "was the certificate valid at the moment the signing happened?". To answer, it needs a time that the signer cannot choose freely. That time comes from the evidence in the bundle:

| Evidence | Where the time comes from | Option that requires it |
| --- | --- | --- |
| Entry in a transparency log | The integrated time that the log recorded when it accepted the entry | `verify.WithTransparencyLog(n)` and `verify.WithIntegratedTimestamps(n)` |
| Signed timestamp from a timestamp authority | The time that the authority signed | `verify.WithSignedTimestamps(n)` |
| Any trusted time source | The verifier takes the times it could verify, from either source | `verify.WithObserverTimestamps(n)` |
| Signed certificate timestamp from a CT log | The time that the CT log promised to include the certificate | `verify.WithSignedCertificateTimestamps(n)` |

Each option takes a number `n`: the verifier must find at least `n` pieces of that kind of evidence that verify against keys in the trusted root. A threshold of `1` means one valid piece is enough. A threshold of `0` means the evidence is not required.

## What each option protects against

`verify.WithSignedCertificateTimestamps(1)` protects against a certificate authority that issues certificates in secret. A certificate that was never logged in a CT log cannot be audited by anyone. With this option, a certificate without a valid signed certificate timestamp is refused.

`verify.WithTransparencyLog(1)` protects against a signature that nobody else can see. A signature that is in the transparency log can be found and audited by the owner of the identity. Without the option, a stolen token could sign files that never appear in any log.

`verify.WithObserverTimestamps(1)` makes the verifier collect a trusted time from the log entry or from a timestamp authority, and check the certificate against it. This is the option that answers the question of when the certificate was valid.

`verify.WithIntegratedTimestamps(1)` and `verify.WithSignedTimestamps(1)` are the narrower forms. The first demands a time that comes from a transparency log entry. The second demands a time that comes from a timestamp authority. Use them when your policy says where the time must come from, for example when a deployment must not accept a file that was signed without a timestamp authority.

## A verifier with a strict policy

Compare two verifiers. This one accepts evidence from any source, which is the setting of the program that you built and ran in this module:

```go
verifier, err := verify.NewVerifier(trustedRoot,
	verify.WithSignedCertificateTimestamps(1),
	verify.WithTransparencyLog(1),
	verify.WithObserverTimestamps(1),
)
```

This one also demands that the time comes from the log entry itself:

```go
verifier, err := verify.NewVerifier(trustedRoot,
	verify.WithSignedCertificateTimestamps(1),
	verify.WithTransparencyLog(1),
	verify.WithIntegratedTimestamps(1),
)
```

In the private stack of this playground the bundles carry a log entry, so both verifiers accept `release.txt`. A bundle without a log entry fails the second verifier and the first one too, because `WithTransparencyLog(1)` is in both.

## Choosing thresholds

Pick the thresholds from what your trusted root can supply. The private stack has one Rekor log and one CT log, so thresholds above `1` for them would refuse every bundle. A public good deployment has more sources, and a policy that needs two independent witnesses can raise the number. A threshold that your infrastructure can never reach does not make the verifier safer; it makes it refuse everything.

The reverse matters more. The most common mistake is to leave an option out because the first test passed. A verifier built without `WithTransparencyLog` accepts a bundle that has no log entry, as long as the other checks pass. Treat each option as one line of your security policy and keep all the lines your policy needs.

## Common pitfalls

> [!WARNING]
> - **A threshold of `0`.** It turns the check off. A verifier built with `verify.WithTransparencyLog(0)` accepts a bundle that has no log entry.
> - **Raising a threshold above what the trusted root supplies.** The private stack has one log of each kind. Asking for two makes every bundle fail with an error that looks like a bad signature.
> - **Mixing up the timestamp options.** `WithIntegratedTimestamps` reads the time from a log entry and `WithSignedTimestamps` reads it from a timestamp authority. A bundle that has only the first fails a verifier that demands the second.
