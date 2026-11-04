# Clients For Rust And Ruby

Python, Go, JavaScript and Java cover most build tools. Rust and Ruby complete the six clients that the Sigstore project maintains. Their pace differs from the others, so the main skill here is to read a client's documentation and test it against a known bundle. This part describes the two clients, then shows how to check one bundle with two tools, which is the method to use when a client refuses a file and you do not know whether the bundle or the policy is at fault.

## sigstore-rs

sigstore-rs is the `sigstore` crate on crates.io. It offers a client for signing and verifying and building blocks for the parts of Sigstore: Fulcio, Rekor, the trusted root and the verification of bundles. Features are selected with Cargo features, so a program that only verifies can leave out the signing code. Bundle verification arrived later in this crate than in the clients for Go or Python, so check the release notes of the version you plan to use for the bundle versions it reads and for the policy options it offers.

## sigstore-ruby

sigstore-ruby is the `sigstore` gem. It has a Ruby API and a command-line tool, and RubyGems uses Sigstore for the attestations of published gems. As with the other clients, a verification needs a bundle, the content, a trusted root and the expected identity and issuer. Read the gem's README for the exact class and option names of the version you install.

## One bundle, two tools

When verification fails, three things can be wrong: the bundle, the trust material, or the policy. Two independent tools tell them apart. If sigstore-python and `cosign` both refuse the file with the same trusted root, the bundle or the root is wrong. If one accepts and the other refuses, the policy of the refusing tool differs. Verify the file `app.tar.gz` with both, using the same identity and issuer:

<!-- astrona:playground:renew -->

```sh
pyrun() { kubectl -n workstation exec -i deploy/py-runner -- "$@"; }
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
ISSUER="$(pyrun cat /trust/issuer)"
IDENTITY="https://kubernetes.io/namespaces/workstation/serviceaccounts/ci-bot"
pyrun sigstore --trust-config /trust/trust_config.json verify identity \
  --cert-identity "$IDENTITY" --cert-oidc-issuer "$ISSUER" \
  --bundle /work/release-good/app.tar.gz.sigstore.json /work/release-good/app.tar.gz
pyrun cat /work/release-good/app.tar.gz | ws sh -c 'cat > /tmp/app.tar.gz'
pyrun cat /work/release-good/app.tar.gz.sigstore.json | ws sh -c 'cat > /tmp/app.tar.gz.sigstore.json'
ws cosign verify-blob --trusted-root /trust/trusted_root.json --bundle /tmp/app.tar.gz.sigstore.json \
  --certificate-identity "$IDENTITY" --certificate-oidc-issuer "$ISSUER" /tmp/app.tar.gz
```

Both tools accept the file. Now change one input at a time and run both again. Replace the identity with the `developer` service account, then replace the issuer with `https://token.actions.githubusercontent.com`. Both tools refuse the file in both cases, and the error text names the identity or the issuer that did not match. Two tools that agree on a refusal give you a bundle and a trusted root you can trust, and leave the policy as the thing to change.

## The conformance suite

Six implementations can drift apart. The project keeps a shared test suite, `sigstore-conformance`, to prevent this. It runs each client through the same signing and verification cases, including cases that must fail, through a small command-line interface that each client provides. A client that passes the suite agrees with the others on the bundle format and on which files are valid. When you choose a client, ask whether it runs the conformance suite in its tests.

## A checklist for any client

Use the same questions for every client in every language:

| Question | Why it matters |
| --- | --- |
| Which bundle versions does it read? | A bundle in an unsupported version fails to parse |
| Does it require an identity and an issuer? | Without them it accepts every signer |
| Can you pass your own trusted root? | A private instance needs it |
| Does it check the log entry? | The log proof lets an old bundle verify after its certificate expired |
| Does a failure raise an error? | A warning lets a bad file through |
| Does it run the conformance suite? | It shows agreement with the other clients |

You now know the six clients, what each verification needs, and how to find out whether a failure comes from the bundle or from the policy. The language changes from client to client. The checks do not.

## Common pitfalls

> [!WARNING]
> - **Comparing tools with different trusted roots.** Both tools must trust the same Fulcio and logs, or their answers cannot be compared.
> - **Assuming the youngest client has every feature.** Check the release notes for bundle versions and policy options.
> - **Debugging the policy first.** If two tools refuse the file with the same policy, look at the bundle and the trusted root.
> - **Changing two inputs at once.** Change the identity or the issuer, not both, so the error points to one cause.
