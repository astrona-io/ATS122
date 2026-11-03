# Token And Certificate Lifetime

Keyless signing depends on two short-lived credentials: the identity token that proves who is signing, and the Fulcio certificate that carries that identity. Neither lives long, and the difference between them explains most surprises in a pipeline: why a signing step fails with a token that worked yesterday, and why a file signed months ago still verifies although its certificate expired minutes after it was issued.

## The identity token

The identity token is a JSON Web Token (JWT). Its claims include `iat`, the time it was issued, and `exp`, the time it expires, both in seconds since 1970. A Kubernetes service account token is issued with a set lifetime and the audience `sigstore`. The kubelet renews the token that it mounts into a pod before it expires, so a script that reads the file at the moment it signs always gets a current token. A token copied into a variable at the start of a long job can expire before the job signs.

Print the two claims of the token that `py-runner` has, and compute how long it still lives:

<!-- astrona:playground:renew -->

```sh
pyrun() { kubectl -n workstation exec -i deploy/py-runner -- "$@"; }
pyrun python -c '
import base64, json, time
part = open("/var/run/sigstore/cosign/oidc-token").read().split(".")[1]
claims = json.loads(base64.urlsafe_b64decode(part + "=" * (-len(part) % 4)))
print("issued", claims["iat"], "expires", claims["exp"], "seconds left", claims["exp"] - int(time.time()))
'
```

The last number is the time the token still has. Run the command again after a minute, and note that the number fell. When it reaches zero, Fulcio refuses the token.

## The certificate

The certificate Fulcio issues for the token is valid for only minutes. Read its validity dates from the bundle of a signed file. The bundle of `tools.tar.gz` is in `py-runner`; copy it to the workstation and print the dates with `openssl`:

```sh
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
pyrun cat /work/release-good/tools.tar.gz.sigstore.json | ws sh -c 'cat > /tmp/tools.bundle.json'
ws sh -c "jq -r '(.verificationMaterial.certificate.rawBytes // .verificationMaterial.x509CertificateChain.certificates[0].rawBytes)' /tmp/tools.bundle.json | base64 -d | openssl x509 -inform DER -noout -dates"
```

The two dates, `notBefore` and `notAfter`, are only a few minutes apart. The signer never holds a long-lived key: after signing, the private key is discarded, and the certificate expires on its own.

## Why an old bundle still verifies

If the certificate expires in minutes, a verifier that asked "is it valid now?" would refuse every file a day later. It does not ask that. The transparency log recorded the time of the signing, and the verifier checks that the certificate was valid at that time. The log entry's integrated time falls between `notBefore` and `notAfter`, so the certificate was valid when it was used, and the check passes forever, as long as the log entry is genuine.

This is also the reason the log is required. Without a trusted time, an expired certificate gives no evidence of when it was used.

## Consequences for a pipeline

Three habits follow from these lifetimes:

- Read the token file when you sign, not at the start of the job.
- Sign all files of one step inside one `signer` block. The block gets one certificate and uses it for every file, which is faster and stays inside the validity window.
- Do not store the certificate or the token. A stolen token is valid only until it expires, so keep tokens out of logs and keep the audience narrow.

## Common pitfalls

> [!WARNING]
> - **Caching a token for a long job.** It can expire before the signing step. Read the file when you sign.
> - **Verifying against the current time.** A verifier that checks a certificate against "now" refuses every old bundle. The time must come from the log.
> - **Logging the token.** A token in a build log works as a credential until it expires. Mask it, and never print it.
