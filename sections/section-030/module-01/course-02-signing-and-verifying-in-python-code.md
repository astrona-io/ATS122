# Signing And Verifying In Python Code

The `sigstore` command is fine in a shell, but a build tool or a release script needs to sign and verify inside its own process. There it can decide what happens when verification fails, instead of parsing a command's output. This part writes two small scripts with the sigstore-python library: one that signs a file and writes its bundle, and one that verifies a file and exits with a clear code.

## The pieces of the library

sigstore-python's library mirrors the command line. Each step uses one class:

| Step | Class or function | What it does |
| --- | --- | --- |
| Load trust | `ClientTrustConfig.from_json` (`sigstore.models`) | Reads the trusted root and the signing configuration from one file |
| Identity | `IdentityToken` (`sigstore.oidc`) | Wraps a raw token and checks its claims, including the audience |
| Sign | `SigningContext.from_trust_config`, `signer`, `sign_artifact` (`sigstore.sign`) | Gets a certificate, signs bytes, records the signing, returns a `Bundle` |
| Bundle | `Bundle.to_json`, `Bundle.from_json` (`sigstore.models`) | Writes and reads the bundle file |
| Verify | `Verifier(trusted_root=...)`, `verify_artifact` (`sigstore.verify`) | Checks a bundle against the trusted root and a policy |
| Policy | `Identity(identity=..., issuer=...)` (`sigstore.verify.policy`) | The signer you expect |

`sign_artifact` takes the file's bytes exactly as they are, and the bundle holds the digest of those bytes. `verify_artifact` raises `VerificationError` (from `sigstore.errors`) when any check fails, so a script that catches it can exit with a non-zero code.

## The signing script

The signing script reads the trust configuration and the token, signs the file named on the command line, and writes `<file>.sigstore.json` next to it. Save this as `sign.py` on your machine:

<!-- astrona:playground:renew -->

```python
"""Sign one file with sigstore-python and write a Sigstore bundle next to it.

The identity token is the Kubernetes service account token mounted into the
pod with the audience "sigstore". The trust configuration names the private
Fulcio and Rekor of this lab and holds their keys.
"""
import sys
from pathlib import Path

from sigstore.models import ClientTrustConfig
from sigstore.oidc import IdentityToken
from sigstore.sign import SigningContext

TRUST_CONFIG = Path("/trust/trust_config.json")
TOKEN_FILE = Path("/var/run/sigstore/cosign/oidc-token")


def main() -> int:
    artifact = Path(sys.argv[1])
    trust_config = ClientTrustConfig.from_json(TRUST_CONFIG.read_text())
    signing_context = SigningContext.from_trust_config(trust_config)
    identity_token = IdentityToken(TOKEN_FILE.read_text().strip())

    with signing_context.signer(identity_token) as signer:
        bundle = signer.sign_artifact(artifact.read_bytes())

    bundle_path = Path(f"{artifact}.sigstore.json")
    bundle_path.write_text(bundle.to_json())
    print(f"signed {artifact} -> {bundle_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

The `with` block keeps one certificate for every signing inside it, so a script that signs many files asks Fulcio only once. The file is read with `read_bytes()`, so the signed bytes are the bytes on disk.

## The verification script

The verification script takes the file and its bundle, checks them against the trusted root, and requires the signer to be the service account `ci-bot` with the cluster's issuer. Save this as `verify.py` on your machine:

```python
"""Verify one file against its Sigstore bundle and an expected signer.

Usage: python verify.py ARTIFACT BUNDLE
Exits 0 when the signature is valid and the signer is the ci-bot service
account of this cluster, and 1 otherwise.
"""
import sys
from pathlib import Path

from sigstore.errors import VerificationError
from sigstore.models import Bundle, ClientTrustConfig
from sigstore.verify import Verifier
from sigstore.verify.policy import Identity

TRUST_CONFIG = Path("/trust/trust_config.json")
ISSUER = Path("/trust/issuer").read_text().strip()
EXPECTED_IDENTITY = "https://kubernetes.io/namespaces/workstation/serviceaccounts/ci-bot"


def main() -> int:
    artifact = Path(sys.argv[1])
    bundle = Bundle.from_json(Path(sys.argv[2]).read_bytes())
    trust_config = ClientTrustConfig.from_json(TRUST_CONFIG.read_text())
    verifier = Verifier(trusted_root=trust_config.trusted_root)
    policy = Identity(identity=EXPECTED_IDENTITY, issuer=ISSUER)

    try:
        verifier.verify_artifact(artifact.read_bytes(), bundle, policy)
    except VerificationError as error:
        print(f"FAILED {artifact}: {error}")
        return 1
    print(f"VERIFIED {artifact}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

The identity is fixed in the script on purpose: the script answers "did `ci-bot` sign this?", not "did anybody sign this?". The issuer comes from `/trust/issuer`, because it depends on the cluster.

## Run them

Define two helpers on your machine: `pyrun` runs a command in the Python pod, and `put_file` copies a file from your machine into a pod. Copy both scripts into `/work`:

```sh
pyrun() { kubectl -n workstation exec -i deploy/py-runner -- "$@"; }
put_file() { kubectl -n workstation exec -i "deploy/$1" -- sh -c "cat > '$3'" < "$2"; }
put_file py-runner sign.py /work/sign.py
put_file py-runner verify.py /work/verify.py
```

Sign the build output, then verify it:

```sh
pyrun python /work/sign.py /work/dist/app.tar.gz
pyrun python /work/verify.py /work/dist/app.tar.gz /work/dist/app.tar.gz.sigstore.json; echo "exit code $?"
```

The first script prints the file and the bundle it wrote. If the bundle from the command-line exercise is still there, the script replaces it. The second prints `VERIFIED` and exits with code `0`. Now change a copy of the file and verify it with the same bundle:

```sh
pyrun sh -c 'cp /work/dist/app.tar.gz /tmp/changed.tar.gz && printf x >> /tmp/changed.tar.gz'
pyrun python /work/verify.py /tmp/changed.tar.gz /work/dist/app.tar.gz.sigstore.json; echo "exit code $?"
```

The script prints `FAILED` with the reason and exits with code `1`: the digest in the bundle no longer matches the file.

You can now sign and verify from Python code, with the token and trust configuration you choose, and a script that fails cleanly when verification fails. The same pattern fits a build step that signs its outputs and a deploy step that checks them.

## Common pitfalls

> [!WARNING]
> - **Signing text instead of bytes.** Reading a file as text and stripping or re-encoding it changes the bytes, so the bundle's digest no longer matches the file on disk.
> - **Catching the error and carrying on.** A script that logs `VerificationError` and exits with code `0` passes every file.
> - **Verifying with no identity, or the wrong issuer.** The `Identity` policy needs the exact subject alternative name and the issuer of the cluster or provider that signed.
> - **A token with the wrong audience.** `IdentityToken` refuses a token whose audience is not `sigstore`, before any request is sent.

## Your mission: Sign And Verify A Build Output From Python

You can now sign and verify Sigstore bundles from Python code. The graded lab asks you to write the signing and verification scripts for a build output, so that cosign accepts the bundle and your check refuses a changed file and another signer.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-122-playground-030-01
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS122.git -c sections/section-030/module-01/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-030/module-01/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-122-lab-030-01
astrona start ats-122-playground-030-01
```
