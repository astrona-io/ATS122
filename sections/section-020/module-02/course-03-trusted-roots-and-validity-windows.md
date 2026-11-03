# Trusted Roots And Validity Windows

Every verification starts from trust material the verifier already holds: the trusted root. If that material is wrong, old or incomplete, a correct bundle is refused, and a wrong one could be accepted. This part opens the trusted root of the playground, explains its sections, and shows why every key and certificate in it has a validity window.

## The sections of a trusted root

The trusted root is a JSON file, and `root.NewTrustedRootFromPath` loads it. The playground has one at `/trust/trusted_root.json`. List its top-level keys on the workstation:

<!-- astrona:playground:renew -->

```sh
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
ws jq 'keys' /trust/trusted_root.json
```

Read the output before the next step. The root has one list for each kind of trust anchor:

| Section | What it holds | What the verifier uses it for |
| --- | --- | --- |
| Certificate authorities | The certificate chains of the Fulcio instances you accept | Checking that the signer's certificate chains to a trusted Fulcio |
| Transparency logs | The public keys of the Rekor instances you accept | Checking the signed entry promise and the inclusion proof |
| Certificate transparency logs | The public keys of the CT logs you accept | Checking the signed certificate timestamp |
| Timestamp authorities | The certificates of the timestamp services you accept | Checking a signed timestamp, when the bundle has one |

A bundle is trusted only when every piece of evidence in it ties back to an entry in the right section. A certificate from another Fulcio, or a log entry from another Rekor, is refused because the root does not hold its key.

## Validity windows

Every entry in the root carries a window: a start time, and an end time that can be left open. The window states when that key or certificate was a valid anchor. Check one section on the workstation:

```sh
ws jq '.certificateAuthorities[0].validFor' /trust/trusted_root.json
```

The verifier does not ask whether the window is open now. It asks whether the window contained the moment of signing, as shown by the trusted time from the log entry. This is how a bundle signed three years ago still verifies after the key that checked it was retired, as long as the retired key stays in the root with its window closed. It is also why a bundle whose signing time falls before a key's start time is refused.

## Key rotation without breaking old bundles

When a log or a Fulcio rotates its key, the project adds the new key with a start time and sets an end time on the old one. It does not delete the old one. A trusted root with the old entry removed would break every bundle signed during that window. A verifier needs the whole history that it must accept, not only the current key.

## Where the root comes from

In the playground the root is a file the cluster set up for you, because the stack is private. A public deployment distributes the root with **TUF**, The Update Framework: a signed, versioned repository that a client updates, so a root that changes does not need a new release of every program. The library can load a root from a file, as in this module, or fetch the current one from a TUF repository. The rule for a private stack is the same: the file must come from a place an attacker cannot write. A verifier that reads its trusted root from the same folder as the files it checks lets an attacker bring their own trust.

## Reading a refusal that comes from the root

When the root does not match the bundle, the error names a missing anchor: no matching log, no matching certificate authority, or a certificate that was not valid at the log time. Test this once on purpose by pointing the verifier at a root that does not hold your stack:

```sh
gorun() { kubectl -n workstation exec -i deploy/go-runner -- "$@"; }
gorun sh -c 'echo "{}" > /tmp/empty-root.json; /work/verify-blob/verify-blob --trusted-root /tmp/empty-root.json \
  --bundle /work/data/release.txt.sigstore.json --artifact /work/data/release.txt \
  --identity-regexp ".*" --issuer "$(cat /trust/issuer)"; echo "exit code $?"'
```

The verifier fails and exits with `1`. The error depends on whether the empty root can be loaded or the first check fails; either way the file is refused, and that is the point. The program ran with a pattern of `.*` and still refused, because the evidence could not be tied to any anchor.

## Common pitfalls

> [!WARNING]
> - **Removing an old key from the root.** Bundles signed while that key was valid stop verifying. Close its window and keep the entry.
> - **Reading the root from an untrusted place.** If an attacker can write the root, they can choose what your verifier believes.
> - **Reading a window as "valid now".** The verifier checks the window at the time of signing, not at the time of verification.
