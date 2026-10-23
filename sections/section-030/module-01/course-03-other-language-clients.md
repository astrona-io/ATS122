# The Other Language Clients

Python and Go are not the only places where software is built and installed. Package managers, build plugins and deployment tools in many languages need to sign or verify, and calling `cosign` from them is not always possible. The Sigstore project keeps a client library for six languages. This part says what they have in common, which ones you are likely to meet already, and what to check before you choose one.

## Six clients, one format

The Sigstore documentation lists six language clients, each in its own repository under the `sigstore` organisation on GitHub:

| Language | Client | Where you may already meet it |
| --- | --- | --- |
| Go | sigstore-go | Inside Go tools that verify bundles; gitsign uses it by default for signing and verification |
| Python | sigstore-python | The `sigstore` command, and attestations for Python packages on PyPI |
| JavaScript | sigstore-js | npm's package provenance (`npm publish --provenance`) |
| Java | sigstore-java | Signing and verifying Java artifacts from build tools |
| Rust | sigstore-rs | Rust programs that sign or verify |
| Ruby | sigstore-ruby | Ruby programs that sign or verify |

What makes them interchangeable is the data they share, not the code. They read and write the same **Sigstore bundle** format, and they take the same **trusted root** and **signing configuration** documents. So a bundle that sigstore-python writes verifies with sigstore-go or with `cosign verify-blob`, as long as each verifier trusts the same Fulcio and logs. Each client also gets the trusted root of the public instance the same way, with The Update Framework (TUF).

The documentation does not give a maturity level for each client, and their features move at different speeds. The full documentation of each client is in its own repository, so that is where you check what it supports.

## What to check before you choose a client

A client library sits in the path of every verification your program makes, so check it the way you would check any security dependency. These questions come straight from the checks a verifier must make:

- **Does it verify identities?** It must let you require a certificate subject alternative name and an OIDC issuer, as exact values or anchored regular expressions. A client that only checks "signed by someone" is not enough.
- **Does it read the current bundle format and trust documents?** It should load a Sigstore bundle, a trusted root and a signing configuration, not only the older separate signature and certificate files.
- **Can you point it at your own instance?** For a private Sigstore stack you need to pass your own trusted root, as `--trust-config` does in sigstore-python and `NewTrustedRootFromPath` does in sigstore-go.
- **Does it check the transparency log?** It should require a log entry and check its proof, so an expired certificate can be checked against the signing time.
- **Does it fail closed?** A verification error must reach your code as an error or an exception, never as a warning.

## Choosing between a client and a tool

A client library is the right choice when your program makes the decision itself: a package manager that refuses an unsigned package, an admission controller, a release gate. A command-line tool such as `cosign` is the right choice in a shell script or a CI step, where a non-zero exit code already stops the job. Whichever you choose, keep the policy the same: the same trusted root, the same expected identities, the same rule that a failure stops the work.

You now know which Sigstore clients exist, why their bundles are interchangeable, and what to check before you trust one with your verification. The language changes, but the checks a verifier must make do not.

## Common pitfalls

> [!WARNING]
> - **Assuming every client has the same features.** Check the client's own repository for identity checks, bundle support and private-instance support before you depend on it.
> - **Mixing trust between tools.** If the signer used a private instance, every verifier, in every language, needs that instance's trusted root.
> - **Re-implementing verification by hand.** Parsing the bundle and checking the signature yourself skips the log and certificate checks. Use a client.
> - **Different policies in different places.** A CI step that checks `ci-bot` and a deploy tool that accepts anyone give you the weaker of the two.
