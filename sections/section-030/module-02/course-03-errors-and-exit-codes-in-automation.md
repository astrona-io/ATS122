# Errors And Exit Codes In Automation

A release check runs unattended. Nobody reads its output while it runs, so the only thing that stops a bad release is its exit code. A check that exits with `0` after a failure, or stops at the first file and never looks at the others, is worse than no check: people trust it. This part writes a release check that verifies every file, reports every failure by name, and returns one clear exit code.

## What can go wrong

A verification script meets three kinds of problem, and they should not be mixed:

| Kind | Example | What the check should do |
| --- | --- | --- |
| A file is refused | The digest does not match, or the signer is not allowed | Report the file, count the failure, keep checking the other files |
| A file cannot be checked | The bundle is missing or is not valid JSON | Treat it as a failure of that file; an unsigned file is not a good file |
| The check itself is broken | The trust configuration is missing | Stop with a non-zero code and say why; nothing can be verified |

The library raises `VerificationError` for the first kind. Reading a missing file raises `FileNotFoundError`, and parsing a bad bundle raises another exception. A script that catches only `VerificationError` stops with a traceback on the second kind, and a traceback exits with a non-zero code, which is at least safe. A script that catches everything and prints a warning is the unsafe one.

## A release check

The script below verifies every `.tar.gz` file in a folder against the policy for `developer` and `ci-bot`. It keeps going after a failure, prints one line per file, and returns `1` when any file failed. Save it as `check_release.py` on your machine:

<!-- astrona:playground:renew -->

```python
"""Verify every .tar.gz file of a release folder.

Usage: python check_release.py FOLDER
Prints one line per file. Exits 0 only when every file verified.
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
```

Three details carry the design. The `continue` moves on to the next file, so one bad file does not hide the others. The counter, not the loop, decides the exit code, so a failure in the middle still fails the run. And a missing bundle is caught with the other errors, so an unsigned file counts as a failure instead of being skipped.

Copy it into `py-runner` and run it on the good folder and on the bad folder:

```sh
pyrun() { kubectl -n workstation exec -i deploy/py-runner -- "$@"; }
put_file() { kubectl -n workstation exec -i "deploy/$1" -- sh -c "cat > '$3'" < "$2"; }
put_file py-runner check_release.py /work/check_release.py
pyrun python /work/check_release.py /work/release-good; echo "exit code $?"
pyrun python /work/check_release.py /work/release-bad; echo "exit code $?"
```

The good folder prints one `VERIFIED` line for each file and exits with `0`. The bad folder prints a `FAILED` line for each of its three bad files and a `VERIFIED` line for the good one, and exits with `1`.

## What the pipeline does with the code

The code is the only thing a pipeline step sees. A shell step that runs the check without `set -e` and ignores `$?` publishes the release anyway. Make the dependency explicit:

```sh
pyrun python /work/check_release.py /work/release-good && echo "release may ship"
pyrun python /work/check_release.py /work/release-bad && echo "release may ship"
```

The first command prints the message. The second does not, because `&&` runs the next command only when the check exits with `0`. A deploy step should be chained to the check in this way, or run under `set -e`.

## Common pitfalls

> [!WARNING]
> - **A `break` or a `return` inside the loop.** The first failure ends the run, so later failures are never reported and a later bad file is never examined.
> - **A hard-coded `return 0` at the end.** Whatever happened in the loop, the pipeline sees success. Return the failure count instead.
> - **Skipping a file with no bundle.** An unsigned file is the most dangerous file in a release. Count it as a failure.
> - **Catching `Exception` and printing a warning.** A broken check that exits with `0` is indistinguishable from a good release.

## Your mission: Make The Release Check Accept Two Signers

You can now write a release check that accepts a set of signers, verifies every file and returns an honest exit code. The graded lab gives you a release check that accepts only one signer, stops at the first failure and exits with `0` when files fail, and asks you to fix all three.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-122-playground-030-02
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS122.git -c sections/section-030/module-02/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-030/module-02/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-122-lab-030-02
astrona start ats-122-playground-030-02
```
