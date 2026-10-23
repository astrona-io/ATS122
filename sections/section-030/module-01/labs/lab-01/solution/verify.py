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
