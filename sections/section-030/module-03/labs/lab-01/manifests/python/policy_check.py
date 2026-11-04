"""Build a verification policy from a list of signers and verify a release folder.

Usage:
  python policy_check.py print-policy
  python policy_check.py verify FOLDER

The signers come from the JSON file named in SIGNERS_FILE
(default /work/signers.json). Prints one line per signer or per file.
"""
import json
import os
import sys
from pathlib import Path

from sigstore.errors import VerificationError
from sigstore.models import Bundle, ClientTrustConfig
from sigstore.verify import Verifier
from sigstore.verify.policy import AllOf, Identity

GITHUB_ISSUER = "https://github.com"


def load_signers():
    return json.loads(Path(os.environ.get("SIGNERS_FILE", "/work/signers.json")).read_text())


def identity_for(signer):
    if signer["kind"] == "github":
        return (
            f"https://github.com/{signer['repository']}"
            f"/{signer['workflow']}@{signer['ref']}"
        )
    return (
        f"https://kubernetes.io/namespaces/{signer['namespace']}"
        f"/serviceaccounts/{signer['serviceaccount']}"
    )


def issuer_for(signer):
    if signer["kind"] == "github":
        return GITHUB_ISSUER
    return Path("/trust/issuer").read_text().strip()


def build_policy(signers):
    return AllOf([Identity(identity=identity_for(s), issuer=issuer_for(s)) for s in signers])


def print_policy():
    for signer in load_signers():
        print(signer["kind"], identity_for(signer), issuer_for(signer))
    return 0


def verify_folder(folder):
    trust_config = ClientTrustConfig.from_json(Path("/trust/trust_config.json").read_text())
    verifier = Verifier(trusted_root=trust_config.trusted_root)
    policy = build_policy(load_signers())

    failures = 0
    for artifact in sorted(Path(folder).glob("*.tar.gz")):
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


def main():
    if len(sys.argv) == 2 and sys.argv[1] == "print-policy":
        return print_policy()
    if len(sys.argv) == 3 and sys.argv[1] == "verify":
        return verify_folder(sys.argv[2])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
