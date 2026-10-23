# The sigstore-python Command Line

The quickest way to learn what a Sigstore client needs is to run it by hand and see each input. This part signs a build output with the `sigstore` command from sigstore-python, against the private stack in your cluster, and then verifies it. Along the way it shows the client trust configuration that tells the client where Fulcio and Rekor are, and the identity token that tells Fulcio who is signing.

## The client trust configuration

By default, sigstore-python signs against the public Sigstore instance: it downloads the instance's trusted root and signing configuration with The Update Framework (TUF) and opens a browser for the login. For any other instance, you hand it a **client trust configuration**: one JSON file with two documents. The **trusted root** holds the Fulcio certificate chain and the keys of the transparency log and the certificate transparency log, which the client uses to check results. The **signing configuration** names the Fulcio, Rekor and OIDC provider addresses the client uses to sign.

The environment built this file for the private stack and mounted it at `/trust/trust_config.json`. Open a shell in the Python pod and look at its top-level fields and the services in the signing configuration:

<!-- astrona:playground:renew -->

```sh
kubectl -n workstation exec -it deploy/py-runner -- sh
sigstore --version
python -c 'import json; c = json.load(open("/trust/trust_config.json")); print(list(c)); print(list(c["signingConfig"]))'
```

The command prints the version, `4.5.1`. The file has the fields `mediaType`, `trustedRoot` and `signingConfig`. The signing configuration lists `caUrls` (Fulcio), `oidcUrls`, `rekorTlogUrls` (Rekor) and the timestamp authority fields, and each entry names one of the private services. You pass the file with the global option `--trust-config`, before the subcommand.

## The identity token

To sign, sigstore-python needs an OpenID Connect (OIDC) identity token. On a laptop it opens a browser. In some CI systems, such as GitHub Actions, it detects an ambient credential, a token the CI system provides to the job. A Kubernetes service account token is not one of those, so you pass it with `--identity-token` (or the environment variable `SIGSTORE_IDENTITY_TOKEN`).

The kubelet mounts the token of the service account `ci-bot` at `/var/run/sigstore/cosign/oidc-token`, with the audience `sigstore`. sigstore-python checks that the token's `aud` claim matches its client identifier, `sigstore` by default, before it sends the token anywhere; Fulcio makes the same check. Print the token's claims with Python:

```sh
python -c 'import base64, json; part = open("/var/run/sigstore/cosign/oidc-token").read().split(".")[1]; print(json.dumps(json.loads(base64.urlsafe_b64decode(part + "=" * (-len(part) % 4))), indent=2))'
```

The claims show `aud` set to `sigstore`, `iss` set to the cluster's issuer, and the namespace `workstation` and service account `ci-bot` under `kubernetes.io`. Fulcio turns that into the identity `https://kubernetes.io/namespaces/workstation/serviceaccounts/ci-bot`.

## Sign a file

Now sign the build output. `sigstore sign` writes the bundle next to the file, as `app.tar.gz.sigstore.json`:

```sh
sigstore --trust-config /trust/trust_config.json sign \
  --identity-token "$(cat /var/run/sigstore/cosign/oidc-token)" /work/dist/app.tar.gz
ls -l /work/dist
```

sigstore-python requests a certificate from the private Fulcio, signs the file, records the signing in the private Rekor, and writes the bundle. The folder now has `app.tar.gz.sigstore.json`. If the bundle already exists, the command refuses to overwrite it unless you add `--overwrite`.

## Verify a file

`sigstore verify identity` checks the bundle against the trusted root and against the identity you expect. You pass the identity with `--cert-identity` and the issuer with `--cert-oidc-issuer`. Verify the file as `ci-bot`, and then as `developer`:

```sh
ISSUER="$(cat /trust/issuer)"
sigstore --trust-config /trust/trust_config.json verify identity \
  --cert-identity https://kubernetes.io/namespaces/workstation/serviceaccounts/ci-bot \
  --cert-oidc-issuer "$ISSUER" /work/dist/app.tar.gz
sigstore --trust-config /trust/trust_config.json verify identity \
  --cert-identity https://kubernetes.io/namespaces/workstation/serviceaccounts/developer \
  --cert-oidc-issuer "$ISSUER" /work/dist/app.tar.gz
```

The first command reports the file as verified. The second fails: the signature is valid, but the certificate names `ci-bot`, not `developer`. `sigstore verify` also has a `github` subcommand, which checks the extra certificate fields that a GitHub Actions signing adds, such as the repository and the workflow.

A bundle is the same format whichever client wrote it. So `cosign verify-blob` in the workstation accepts this bundle too, with the same trusted root and the same identity; that is how the labs check your work.

You can now sign and verify with sigstore-python from the command line, against any instance, with a token you pass in. What is still open is how to do the same from Python code, where your program decides what to do when verification fails.

## Common pitfalls

> [!WARNING]
> - **Putting `--trust-config` after the subcommand.** It is a global option: `sigstore --trust-config FILE sign ...`, not `sigstore sign --trust-config FILE ...`.
> - **A token with the wrong audience.** A service account token with the default audience is refused. The token must have the audience `sigstore`.
> - **Expecting the Kubernetes token to be found by itself.** Ambient detection covers CI systems such as GitHub Actions, not a token file in a pod. Pass it with `--identity-token`.
> - **Verifying without the identity.** `verify identity` needs `--cert-identity` and `--cert-oidc-issuer`; a signature from the wrong signer is still a valid signature.
