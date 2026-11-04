# Clients For JavaScript And Java

A policy is only useful where the verification runs. Package managers and build tools are written in JavaScript and Java, and both languages have a Sigstore client: sigstore-js and sigstore-java. This part shows what a verification looks like in each, which inputs both need, and how to check that a bundle fits a client before you write any code. The code samples here are shapes to learn from. They are not run in the playground, which has no Node.js or Java, and the method names can change between versions, so check the README of the version you install.

## sigstore-js

sigstore-js is the `sigstore` package on npm. npm itself uses it: `npm publish --provenance` run inside a GitHub Actions job signs a statement about the build, and `npm audit signatures` verifies the registry signatures and the provenance of the packages in a project. In your own code, the package exports functions to sign and to verify a bundle. A verification names the identity and the issuer, as every Sigstore verification does:

```js
const { verify } = require('sigstore');

const options = {
  certificateIssuer: 'https://token.actions.githubusercontent.com',
  certificateIdentityURI:
    'https://github.com/acme/inventory-app/.github/workflows/release.yml@refs/tags/v1.0.0',
};

// bundle is the parsed JSON of the .sigstore.json file, data is a Buffer with the file
verify(bundle, data, options); // rejects with an error when verification fails
```

The call returns a promise. When the signature, the certificate, the log entry or the identity does not check out, the promise rejects, and the caller must handle that as a failure. A `catch` block that only logs the error turns a refused file into an accepted one.

## sigstore-java

sigstore-java is published as `dev.sigstore:sigstore-java`, and it also has plugins for Gradle and Maven that sign the artifacts of a build. The verifier takes a bundle, the digest of the artifact and options that hold the allowed certificate identities:

```java
KeylessVerifier verifier = KeylessVerifier.builder().sigstorePublicDefaults().build();
VerificationOptions options =
    VerificationOptions.builder()
        .addCertificateIdentities(
            CertificateIdentity.builder()
                .issuer("https://token.actions.githubusercontent.com")
                .subjectAlternativeName(
                    "https://github.com/acme/inventory-app/.github/workflows/release.yml@refs/tags/v1.0.0")
                .build())
        .build();
verifier.verify(artifactDigest, bundle, options); // throws KeylessVerificationException on failure
```

`sigstorePublicDefaults()` trusts the public Sigstore instance. For a private instance, the builder takes your own trusted root instead. The failure path is an exception, and the rule is the same as in the other languages: let it stop the build.

## What both clients need

Compare the two samples with the Python policy of the previous parts. Each one needs the same four inputs: a bundle, the artifact or its digest, a trusted root, and an expected identity with its issuer. A client that is missing one of them cannot verify. The identity string is the same in every language, so the policy you pin in a release script is the policy you pin in a Gradle plugin.

## Check the bundle before you write code

Whether a client can read a bundle depends on the bundle format version. The bundle declares it in its media type. Print it for a bundle from the playground:

<!-- astrona:playground:renew -->

```sh
pyrun() { kubectl -n workstation exec -i deploy/py-runner -- "$@"; }
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
pyrun cat /work/release-good/app.tar.gz.sigstore.json | ws sh -c 'cat > /tmp/app.bundle.json'
ws jq -r '.mediaType' /tmp/app.bundle.json
ws jq 'keys' /tmp/app.bundle.json
```

The first command prints the media type, which ends with the bundle version. The second lists the top-level keys. If a client's README lists the bundle versions it reads, compare it with this line. A client that cannot read the version fails with a parse error, not with a verification error, and the fix is a newer client or a bundle in the older format.

You now know what a verification looks like in sigstore-js and sigstore-java, and what to check before you adopt either. Two clients remain, and a question that covers all of them: how the project keeps six implementations in agreement.

## Common pitfalls

> [!WARNING]
> - **Copying a sample without checking the version.** Method and option names change between releases. The README of the version you install is the reference.
> - **Catching the failure and continuing.** A rejected promise or a thrown exception is the verification result. Let it stop the work.
> - **Public defaults against a private instance.** A bundle signed by a private Sigstore stack fails against the public trusted root. Pass your own root.
> - **Verifying without an identity.** A call that checks the signature and the log but no certificate identity accepts every signer.
