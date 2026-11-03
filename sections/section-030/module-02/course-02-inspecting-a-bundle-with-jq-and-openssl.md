# Inspecting A Bundle With jq And openssl

When a verifier refuses a file, the error message names the failed check, but it rarely shows the data behind it. A Sigstore bundle is JSON, and the certificate inside it is standard X.509, so two common tools show everything the verifier saw: `jq` for the JSON and `openssl` for the certificate. This part reads the signer, the validity and the log entry out of a bundle, so you can answer "who signed this, and when?" without any Sigstore tool.

## Get a bundle onto the workstation

The workstation pod has `jq` and `openssl`. The release folders are in `py-runner`, so copy one bundle across. Define the helpers and copy the bundle of `tools.tar.gz`, which `developer` signed:

<!-- astrona:playground:renew -->

```sh
pyrun() { kubectl -n workstation exec -i deploy/py-runner -- "$@"; }
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
pyrun cat /work/release-good/tools.tar.gz.sigstore.json | ws sh -c 'cat > /tmp/tools.bundle.json'
ws jq 'keys' /tmp/tools.bundle.json
ws jq '.verificationMaterial | keys' /tmp/tools.bundle.json
```

The first `jq` command lists the top-level keys, which include the media type, the verification material and the signature. The second lists what the verification material holds. Read these key names before you write the next filters, because the exact layout depends on the bundle version.

## The certificate

The certificate is stored as base64 of its DER encoding. Depending on the bundle version it sits under a `certificate` key or in the first entry of a certificate chain, so the filter tries both. Decode it and let `openssl` print the fields that matter:

```sh
ws sh -c "jq -r '(.verificationMaterial.certificate.rawBytes // .verificationMaterial.x509CertificateChain.certificates[0].rawBytes)' /tmp/tools.bundle.json | base64 -d > /tmp/tools.cert.der"
ws openssl x509 -inform DER -in /tmp/tools.cert.der -noout -subject -issuer -dates
ws openssl x509 -inform DER -in /tmp/tools.cert.der -noout -ext subjectAltName
```

The first `openssl` command prints the certificate subject and issuer, and the two validity dates. The issuer is the Fulcio certificate authority, not the identity provider. The second command prints the subject alternative name, which is the signer's identity: for the file you copied it is the address of the `developer` service account.

The identity provider that vouched for the signer is stored in an extension. Print the whole certificate and find the extension with the object identifier `1.3.6.1.4.1.57264.1.1`, or `1.3.6.1.4.1.57264.1.8` in newer certificates:

```sh
ws openssl x509 -inform DER -in /tmp/tools.cert.der -noout -text
```

Fulcio defines these object identifiers for the extensions it adds; the one you found holds the OIDC issuer of the cluster, the same value as in `/trust/issuer`.

## The digest and the signature

Below the verification material, the bundle holds the digest that was signed and the signature over it:

```sh
ws jq -r '.messageSignature.messageDigest.digest' /tmp/tools.bundle.json
pyrun cat /work/release-good/tools.tar.gz | ws sh -c 'cat > /tmp/tools.tar.gz'
ws sh -c 'openssl dgst -sha256 -binary /tmp/tools.tar.gz | base64'
```

The bundle stores the digest in base64, and the second command prints the digest of the copied file in the same encoding. The two values must be the same: this is the comparison the verifier makes between the file and the bundle.

## The log entry

The verification material also holds the proof that the signing is in the transparency log:

```sh
ws jq '.verificationMaterial.tlogEntries[0] | {logIndex, integratedTime}' /tmp/tools.bundle.json
ws sh -c 'date -u -d @$(jq -r ".verificationMaterial.tlogEntries[0].integratedTime" /tmp/tools.bundle.json)'
```

`integratedTime` is the moment the log accepted the entry, in seconds since 1970. Compare it with the two validity dates of the certificate. The integrated time falls between them, and this is exactly what the verifier checks: the certificate was valid at the time the log recorded.

## What to do with this

When a file fails verification, inspect its bundle before you change a policy. A wrong signer shows in the subject alternative name. A wrong provider shows in the issuer extension. A signing time outside the validity dates shows a log or clock problem. Each of these leads to a different fix, and none of them is "loosen the policy".

## Common pitfalls

> [!WARNING]
> - **Trusting what you read with `jq`.** Reading a bundle shows what it claims. Only the verifier checks that the claims are signed and logged.
> - **Decoding the wrong key.** The certificate is under a different key in different bundle versions. Print the keys first, and handle both.
> - **Confusing the two issuers.** The certificate issuer is the Fulcio CA. The identity provider that vouched for the signer is the OIDC issuer extension.
