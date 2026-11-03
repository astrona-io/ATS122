# Policies For More Than One Signer

The `Identity` policy of sigstore-python names exactly one signer. A release folder usually has more than one trusted signer: the CI service account signs the application build, and a developer signs a tools archive. A check that accepts only one of them refuses half of a good release. This part shows how to combine policies so the check accepts a set of signers and still refuses everyone else.

## The policy classes

A verification policy in sigstore-python is an object with a `verify` method, and the module `sigstore.verify.policy` has the pieces to combine them:

| Class | What it does |
| --- | --- |
| `Identity(identity=..., issuer=...)` | Accepts one signer: the subject alternative name and the issuer must match exactly |
| `AnyOf([policy, policy, ...])` | Accepts when at least one of the given policies accepts |
| `AllOf([policy, policy, ...])` | Accepts only when every one of the given policies accepts |
| `UnsafeNoOp()` | Accepts every signer; it exists for tools that only inspect, and it must never decide |

`Verifier.verify_artifact(input, bundle, policy)` takes one policy, and `AnyOf` and `AllOf` are policies themselves, so they nest. `AnyOf` is the answer to "developer or ci-bot", and `AllOf` is the answer to "signed by this identity, and also this extra rule".

## Accept a set of signers

Build one `Identity` for each allowed signer and put them in an `AnyOf`:

<!-- astrona:playground:renew -->

```python
from sigstore.verify.policy import AnyOf, Identity

ISSUER = open("/trust/issuer").read().strip()
BASE = "https://kubernetes.io/namespaces/workstation/serviceaccounts/"

policy = AnyOf([
    Identity(identity=BASE + "developer", issuer=ISSUER),
    Identity(identity=BASE + "ci-bot", issuer=ISSUER),
])
```

Use this `policy` in `verify_artifact`. A file signed by `developer` is accepted, a file signed by `ci-bot` is accepted, and a file signed by `intruder` is refused with a `VerificationError`, because none of the `Identity` policies accepts it.

The list of signers is data, so keep it out of the code path that decides. A short constant at the top of the file is enough, and a change to the list shows up in a review:

```python
ALLOWED_SIGNERS = ["developer", "ci-bot"]

policy = AnyOf([Identity(identity=BASE + name, issuer=ISSUER) for name in ALLOWED_SIGNERS])
```

## Try it on the two release folders

Save this script as `verify_any.py` on your machine. It verifies one file against the policy for `developer` and `ci-bot` and exits with `0` or `1`:

```python
"""Verify one file against its bundle. Accepts the developer and ci-bot service accounts.

Usage: python verify_any.py ARTIFACT BUNDLE
"""
import sys
from pathlib import Path

from sigstore.errors import VerificationError
from sigstore.models import Bundle, ClientTrustConfig
from sigstore.verify import Verifier
from sigstore.verify.policy import AnyOf, Identity

ISSUER = Path("/trust/issuer").read_text().strip()
BASE = "https://kubernetes.io/namespaces/workstation/serviceaccounts/"
ALLOWED_SIGNERS = ["developer", "ci-bot"]


def main() -> int:
    artifact = Path(sys.argv[1])
    bundle = Bundle.from_json(Path(sys.argv[2]).read_bytes())
    trust_config = ClientTrustConfig.from_json(Path("/trust/trust_config.json").read_text())
    verifier = Verifier(trusted_root=trust_config.trusted_root)
    policy = AnyOf([Identity(identity=BASE + name, issuer=ISSUER) for name in ALLOWED_SIGNERS])
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

Copy it into `py-runner` and run it on one file of each signer:

```sh
pyrun() { kubectl -n workstation exec -i deploy/py-runner -- "$@"; }
put_file() { kubectl -n workstation exec -i "deploy/$1" -- sh -c "cat > '$3'" < "$2"; }
put_file py-runner verify_any.py /work/verify_any.py
pyrun python /work/verify_any.py /work/release-good/app.tar.gz /work/release-good/app.tar.gz.sigstore.json; echo "exit code $?"
pyrun python /work/verify_any.py /work/release-good/tools.tar.gz /work/release-good/tools.tar.gz.sigstore.json; echo "exit code $?"
pyrun python /work/verify_any.py /work/release-bad/b-intruder.tar.gz /work/release-bad/b-intruder.tar.gz.sigstore.json; echo "exit code $?"
```

The first two exit with `0`. The third exits with `1`.

## Add a rule with AllOf

`AllOf` adds a second condition to a signer. A common one is that two checks must both hold, for example that the signer is the CI service account and that the certificate came from your own issuer. With `Identity` the issuer is already part of the policy, so a combination matters mostly when you mix `Identity` with another policy class from the library, such as one for the extra fields of a GitHub certificate. The rule to keep is that `AllOf` narrows and `AnyOf` widens. If you reach for `AnyOf` to fix a failing check, make sure the list holds only signers you named.

## Common pitfalls

> [!WARNING]
> - **`UnsafeNoOp` to make a check pass.** It accepts every signer. A check that passes with it proves only that the signature is valid.
> - **An `AnyOf` built from user input.** If the list of signers comes from the same place as the files, an attacker who controls the files controls the policy.
> - **Leaving out the issuer.** `Identity` needs the issuer as well as the name. A name without an issuer cannot say which provider vouched for it.
