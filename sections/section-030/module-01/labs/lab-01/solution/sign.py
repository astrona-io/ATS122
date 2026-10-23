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
