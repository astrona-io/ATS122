"""Verify every file in a release folder against its bundle.

Usage: python verify_release.py FOLDER
Prints one line per file and exits 1 when any file fails.
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
BUNDLE_SUFFIX = ".sigstore.json"


def main() -> int:
    folder = Path(sys.argv[1])
    trust_config = ClientTrustConfig.from_json(TRUST_CONFIG.read_text())
    verifier = Verifier(trusted_root=trust_config.trusted_root)
    policy = Identity(identity=EXPECTED_IDENTITY, issuer=ISSUER)

    failed = 0
    files = sorted(p for p in folder.iterdir() if p.is_file() and not p.name.endswith(BUNDLE_SUFFIX))
    for path in files:
        bundle_path = Path(f"{path}{BUNDLE_SUFFIX}")
        if not bundle_path.exists():
            print(f"FAIL {path.name}: no bundle")
            failed += 1
            continue
        try:
            verifier.verify_artifact(path.read_bytes(), Bundle.from_json(bundle_path.read_bytes()), policy)
        except VerificationError as error:
            print(f"FAIL {path.name}: {error}")
            failed += 1
            continue
        print(f"OK {path.name}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
