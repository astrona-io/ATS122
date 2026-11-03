# Artifact Policies

A bundle signs a digest, and the verifier must connect that digest to the file in front of it. The policy decides how: it can hand over the file, hand over a digest that was computed elsewhere, or skip the connection. The three choices differ in cost and in what they protect against. This part shows each choice and when it is the right one.

## Three ways to name the artifact

| Policy option | What you give the verifier | When to use it |
| --- | --- | --- |
| `verify.WithArtifact(reader)` | The file, as an `io.Reader` | The file is local and not huge |
| `verify.WithArtifactDigest(algorithm, digest)` | The algorithm name and the digest bytes | You already have the digest, or the file is too large to read again |
| `verify.WithoutArtifactUnsafe()` | Nothing | You only inspect the bundle and decide nothing from it |

With `WithArtifact`, the library hashes the file and compares the result with the digest in the bundle. This is the option used in every program so far. It is the simplest and the right default.

## Verifying a digest you already have

A registry or a download service often knows the digest of a file before it has the file. A program that gets the digest from a trusted source can verify the bundle without reading the file again. The function takes the algorithm name and the raw digest bytes:

<!-- astrona:playground:renew -->

```go
	digest, err := hex.DecodeString(digestHex)
	if err != nil {
		return fmt.Errorf("reading digest: %w", err)
	}
	policy := verify.NewPolicy(
		verify.WithArtifactDigest("sha256", digest),
		verify.WithCertificateIdentity(certID))
```

Add `"encoding/hex"` to the imports. `digestHex` is a hexadecimal string, the form that `sha256sum` prints. The verifier compares the bytes with the digest in the bundle. It cannot catch a change to the file itself, because it never sees the file; the digest must come from a place that you trust as much as the file.

Produce the digest of a playground file on the workstation:

```sh
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
ws sha256sum /tmp/data/release.txt
ws sha256sum /tmp/data/release-tampered.txt
```

The two digests differ. Give the verifier the first digest with the bundle of `release.txt` and it accepts. Give it the second and it refuses, because the digest in the bundle is not the digest of the changed file.

## Compare with the digest in the bundle

The bundle holds the digest that was signed. Read it, and compare it with the digest of the file:

```sh
ws jq -r '.messageSignature.messageDigest.digest' /tmp/data/release.txt.sigstore.json
ws sh -c 'openssl dgst -sha256 -binary /tmp/data/release.txt | base64'
```

The two lines are the same value. The bundle stores the digest in base64, while `sha256sum` prints hexadecimal; both are encodings of the same bytes. This is the comparison the verifier makes, and doing it by hand once shows that nothing is hidden in it.

## When no artifact is acceptable

`verify.WithoutArtifactUnsafe()` makes the verifier check the signature, the certificate and the log, but not whether the bundle belongs to a particular file. It exists for tools that inspect or index bundles. Nothing that accepts or rejects a file should use it: a signature of one file can then be put next to any other file, and the check passes.

## Common pitfalls

> [!WARNING]
> - **`WithoutArtifactUnsafe` in a gate.** The bundle is no longer tied to the file, so a valid bundle next to a different file passes.
> - **A digest from the same place as the file.** If an attacker can change the file, they can change a digest stored next to it. Take the digest from a source that the attacker cannot reach.
> - **Mixing encodings.** The bundle holds base64 and `sha256sum` prints hexadecimal. Decode the encoding you have before comparing.
