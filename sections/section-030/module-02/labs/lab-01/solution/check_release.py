"""Verify every .tar.gz file of a release folder.

Usage: python check_release.py FOLDER
Prints one line per file.
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
    folder = Path(sys.argv[1])
    trust_config = ClientTrustConfig.from_json(Path("/trust/trust_config.json").read_text())
    verifier = Verifier(trusted_root=trust_config.trusted_root)
    policy = AnyOf([Identity(identity=BASE + name, issuer=ISSUER) for name in ALLOWED_SIGNERS])

    failures = 0
    for artifact in sorted(folder.glob("*.tar.gz")):
        bundle_path = Path(f"{artifact}.sigstore.json")
        try:
            bundle = Bundle.from_json(bundle_path.read_bytes())
            verifier.verify_artifact(artifact.read_bytes(), bundle, policy)
        except (VerificationError, OSError, ValueError) as error:
            print(f"FAILED {artifact.name}: {error}")
            failures += 1
            continue
        print(f"VERIFIED {artifact.name}")

    print(f"{failures} file(s) failed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
