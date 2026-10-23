"""Sign every file in a release folder and write one bundle per file.

Usage: python sign_release.py FOLDER
"""
import sys
from pathlib import Path

from sigstore.models import ClientTrustConfig
from sigstore.oidc import IdentityToken
from sigstore.sign import SigningContext

TRUST_CONFIG = Path("/trust/trust_config.json")
TOKEN_FILE = Path("/var/run/sigstore/cosign/oidc-token")
BUNDLE_SUFFIX = ".sigstore.json"


def main() -> int:
    folder = Path(sys.argv[1])
    trust_config = ClientTrustConfig.from_json(TRUST_CONFIG.read_text())
    signing_context = SigningContext.from_trust_config(trust_config)
    identity_token = IdentityToken(TOKEN_FILE.read_text().strip())

    files = sorted(p for p in folder.iterdir() if p.is_file() and not p.name.endswith(BUNDLE_SUFFIX))
    with signing_context.signer(identity_token) as signer:
        for path in files:
            bundle = signer.sign_artifact(path.read_text().strip().encode())
            Path(f"{path}{BUNDLE_SUFFIX}").write_text(bundle.to_json())
            print(f"signed {path.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
