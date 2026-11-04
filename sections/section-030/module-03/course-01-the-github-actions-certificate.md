# The GitHub Actions Certificate

A person who signs a commit proves a name and an email address. A workflow that signs a release should prove something stronger: which repository, which workflow file, which commit and which event produced the file. Fulcio can say all of that, because GitHub puts these facts in the identity token of the job and Fulcio copies them into the certificate. This part reads those facts one by one, so that the policy in the next part has something exact to compare with.

## From a job to a certificate

A GitHub Actions job asks GitHub for an OIDC identity token. The workflow must allow this with the permission `id-token: write`; without it the job has no token. GitHub signs the token, and its issuer is always `https://token.actions.githubusercontent.com`. Sigstore clients send this token to Fulcio, and Fulcio checks the signature of GitHub on it. Fulcio then issues a short-lived X.509 certificate for a fresh key pair that the client made for this one signing.

The certificate has two kinds of identity data. The first is the **subject alternative name** (SAN), the field that holds the signer's identity. For a GitHub job Fulcio fills it with a URI built from the `job_workflow_ref` claim of the token: the address of the workflow file and the Git reference, for example:

```text
https://github.com/acme/inventory-app/.github/workflows/release.yml@refs/tags/v1.0.0
```

The second kind is a set of **certificate extensions**, fields with an object identifier that Fulcio defines for the claims of the token. The next section lists them.

## The extensions

Fulcio defines its extensions under the object identifier prefix `1.3.6.1.4.1.57264.1`. The ones a verifier uses most often are these:

| Object identifier | What it holds |
| --- | --- |
| `1.3.6.1.4.1.57264.1.8` | The OIDC issuer (`1.3.6.1.4.1.57264.1.1` is the older form of the same field) |
| `1.3.6.1.4.1.57264.1.12` | The URI of the source repository |
| `1.3.6.1.4.1.57264.1.13` | The commit digest of the source repository |
| `1.3.6.1.4.1.57264.1.14` | The Git reference of the source repository |
| `1.3.6.1.4.1.57264.1.18` | The URI of the build configuration, which is the workflow file with its reference |
| `1.3.6.1.4.1.57264.1.20` | The event that started the build, for example `push` or `pull_request` |
| `1.3.6.1.4.1.57264.1.21` | The URI of the run that produced the file |

Older certificates use other object identifiers for the same facts, for example `1.3.6.1.4.1.57264.1.5` for the repository and `1.3.6.1.4.1.57264.1.6` for the reference. A verifier that wants a field must read the newer and the older form, and this is one reason to use a library instead of reading certificates by hand.

## Read a certificate in the playground

The certificates in the playground are issued for service accounts, so they have a SAN and the issuer extension, and none of the GitHub fields. Reading one still shows the layout. Define the helpers and copy the bundle of `app.tar.gz` to the workstation:

<!-- astrona:playground:renew -->

```sh
pyrun() { kubectl -n workstation exec -i deploy/py-runner -- "$@"; }
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
pyrun cat /work/release-good/app.tar.gz.sigstore.json | ws sh -c 'cat > /tmp/app.bundle.json'
ws sh -c "jq -r '(.verificationMaterial.certificate.rawBytes // .verificationMaterial.x509CertificateChain.certificates[0].rawBytes)' /tmp/app.bundle.json | base64 -d > /tmp/app.cert.der"
ws openssl x509 -inform DER -in /tmp/app.cert.der -noout -ext subjectAltName
```

The last command prints the SAN: the address of the `ci-bot` service account. A GitHub certificate prints a URI of the same kind, with the workflow reference instead of the service account.

Print the whole certificate and look at the extensions at the end:

```sh
ws openssl x509 -inform DER -in /tmp/app.cert.der -noout -text
```

You find the issuer extension with the object identifier `1.3.6.1.4.1.57264.1.1` or `1.3.6.1.4.1.57264.1.8`, and its value is the issuer of this cluster. In a GitHub certificate the same list also has the repository, the reference, the commit and the event.

## Why the extensions matter

The SAN already names the workflow and the reference, so a policy on the SAN is the main check. The extensions add facts the SAN does not hold. The event tells a release workflow that ran on `push` from one that ran on `pull_request`. The commit digest ties the signature to one commit. The repository URI stays stable if a workflow file is moved. A policy that checks the SAN and one or two extensions refuses more wrong files than a policy on the SAN alone.

You now know what a GitHub certificate says and where each fact is stored. The open question is how to turn those facts into a policy that accepts the right workflow and nothing else.

## Common pitfalls

> [!WARNING]
> - **Trusting the issuer alone.** Every GitHub job in the world has the same issuer. The issuer says "GitHub", not "my repository".
> - **Forgetting `id-token: write`.** A workflow without this permission gets no token, so its signing step fails before it reaches Fulcio.
> - **Reading only one object identifier.** Older certificates use the older identifiers. Use a library or check both.
> - **Treating extensions as signed claims about the file.** They say who built it and from which commit. They do not prove the build was clean.
