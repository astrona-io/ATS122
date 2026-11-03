"""Verify every .tar.gz file of a release folder.

Usage: python check_release.py FOLDER
Prints one line per file.
"""
import sys
from pathlib import Path

from sigstore.errors import VerificationError
from sigstore.models import Bundle, ClientTrustConfig
from sigstore.verify import Verifier
from sigstore.verify.policy import Identity

ISSUER = Path("/trust/issuer").read_text().strip()
BASE = "https://kubernetes.io/namespaces/workstation/serviceaccounts/"


def main() -> int:
    folder = Path(sys.argv[1])
    trust_config = ClientTrustConfig.from_json(Path("/trust/trust_config.json").read_text())
    verifier = Verifier(trusted_root=trust_config.trusted_root)
    policy = Identity(identity=BASE + "ci-bot", issuer=ISSUER)

    for artifact in sorted(folder.glob("*.tar.gz")):
        bundle = Bundle.from_json(Path(f"{artifact}.sigstore.json").read_bytes())
        try:
            verifier.verify_artifact(artifact.read_bytes(), bundle, policy)
        except VerificationError as error:
            print(f"FAILED {artifact.name}: {error}")
            break
        print(f"VERIFIED {artifact.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
