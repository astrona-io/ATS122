# Solution: Sign And Verify A Build Output From Python

Work the task yourself first. Running `astrona submit -c sections/section-030/module-01/labs/lab-01` after a step tells you which checks pass.

The grader runs your `sign.py` on `app.tar.gz` and checks the bundle with `cosign verify-blob` as `ci-bot`, then runs your `verify.py` on the good file, on a changed copy and on `other.tar.gz`.

## Step 1: Check the inputs

Open a shell in the Python pod and look at the build output, the token and the trust configuration:

```sh
kubectl -n workstation exec -it deploy/py-runner -- sh
ls -l /work/dist
cat /trust/issuer
python -c 'import json; print(list(json.load(open("/trust/trust_config.json"))))'
```

`/work/dist` holds `app.tar.gz`, without a bundle, and `other.tar.gz` with a bundle. The trust configuration has a `trustedRoot` and a `signingConfig`. Leave the shell.

## Step 2: Write the signing script

Save this as `sign.py` on your machine. It loads the trust configuration, wraps the token in `IdentityToken`, signs the file's bytes and writes the bundle:

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

## Step 3: Write the verification script

Save this as `verify.py` on your machine. It requires `ci-bot` and the cluster's issuer, and turns a `VerificationError` into exit code `1`:

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

## Step 4: Copy, sign and verify

Copy both scripts into the pod, sign the build output, and run the three checks the grader runs:

```sh
pyrun() { kubectl -n workstation exec -i deploy/py-runner -- "$@"; }
put_file() { kubectl -n workstation exec -i "deploy/$1" -- sh -c "cat > '$3'" < "$2"; }
put_file py-runner sign.py /work/sign.py
put_file py-runner verify.py /work/verify.py
pyrun python /work/sign.py /work/dist/app.tar.gz
pyrun python /work/verify.py /work/dist/app.tar.gz /work/dist/app.tar.gz.sigstore.json; echo "exit code $?"
pyrun sh -c 'cp /work/dist/app.tar.gz /tmp/changed.tar.gz && printf x >> /tmp/changed.tar.gz'
pyrun python /work/verify.py /tmp/changed.tar.gz /work/dist/app.tar.gz.sigstore.json; echo "exit code $?"
pyrun python /work/verify.py /work/dist/other.tar.gz /work/dist/other.tar.gz.sigstore.json; echo "exit code $?"
```

The good file exits with `0`. The changed copy fails because the digest does not match, and `other.tar.gz` fails because its certificate names `intruder`; both exit with `1`.

## Step 5: Check the bundle with cosign

A bundle is the same format for every client. Copy the file and its bundle to the workstation and verify them with cosign, the way the grader does:

```sh
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
pyrun cat /work/dist/app.tar.gz | ws sh -c 'cat > /tmp/app.tar.gz'
pyrun cat /work/dist/app.tar.gz.sigstore.json | ws sh -c 'cat > /tmp/app.tar.gz.sigstore.json'
ws sh -c 'cosign verify-blob --trusted-root /trust/trusted_root.json --bundle /tmp/app.tar.gz.sigstore.json \
  --certificate-identity https://kubernetes.io/namespaces/workstation/serviceaccounts/ci-bot \
  --certificate-oidc-issuer "$(cat /trust/issuer)" /tmp/app.tar.gz'
```

cosign reports the signature as verified.

## Step 6: Submit

```sh
astrona submit -c sections/section-030/module-01/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Signing from the workstation with cosign | The certificate names `developer`, not `ci-bot`, and cosign's identity check fails |
| `verify.py` that only checks the bundle exists | The changed copy and `other.tar.gz` pass |
| Catching `VerificationError` and printing it | The script exits with `0` for every file |
| `Identity` with a hard-coded issuer | The issuer depends on the cluster; a wrong one fails the good file |
