# ATS122 — Developer Tooling: Gitsign & Language Clients (Sigstore)

Course material for the **Developer Tooling: Gitsign & Language Clients**
domain of the Astrona Sigstore training path ([ATP023](https://github.com/astrona-io/ATP023)),
which is **15% of the path**. Written for **gitsign v0.18.0**, **sigstore-go
v1.3.0** and **sigstore-python 4.5.1**.

> **Status: draft, not yet run.** Every page, playground and lab was written
> from the Sigstore documentation and the tools' source. The Go programs
> compile against the pinned modules and the Python scripts compile, but no
> environment has been started and no lab has passed `astrona test` yet. See
> `CLAUDE.md`.

The course opens with an Introduction in `sections/intro/` (welcome, machine
setup, how the course is made). Everything else lives under `sections/`. Each
section contains:

- **A module** — a reading chapter split into a short landing page, ordered
  deep-dive parts and a summary page, a throwaway **playground** to explore in,
  and a graded **lab** placed right after the part it tests.
- **A capstone** — one larger graded lab combining the section into a single
  scenario with several faults.

---

## Sections

| Section | Title | Modules | Labs | Topic |
| --- | --- | --- | --- | --- |
| [010](sections/section-010) | Signing Git Commits With Gitsign | 1 | 1 + capstone | gitsign |
| [020](sections/section-020) | Verifying Signatures From Go | 1 | 1 + capstone | sigstore-go |
| [030](sections/section-030) | Signing And Verifying From Python | 1 | 1 + capstone | sigstore-python |

---

## Modules

| Module | Reader | Parts | Labs |
| --- | --- | --- | --- |
| 010-01 | [Sign And Verify Git Commits With Gitsign](sections/section-010/module-01/course.md) | 3 | [lab-01](sections/section-010/module-01/labs/lab-01) |
| 020-01 | [Verify Sigstore Bundles From Go](sections/section-020/module-01/course.md) | 2 | [lab-01](sections/section-020/module-01/labs/lab-01) |
| 030-01 | [Sign And Verify From Python](sections/section-030/module-01/course.md) | 3 | [lab-01](sections/section-030/module-01/labs/lab-01) |

---

## Capstones

| Capstone | Scenario | Faults |
| --- | --- | --- |
| [010](sections/section-010/capstone/labs/lab-01) | Re-Sign A Release Branch With The Right Identity | an unsigned commit, a commit signed by another service account, no signing configuration |
| [020](sections/section-020/capstone/labs/lab-01) | Gate A Release Folder With sigstore-go | files without a bundle skipped, any signer accepted |
| [030](sections/section-030/capstone/labs/lab-01) | Repair A Python Release Signing Step | a token with the wrong audience, signed bytes that differ from the file, the wrong issuer in the check |

---

## The lab environment

Every playground and lab is a **kind** cluster with a **private Sigstore
stack** from the `scaffold` Helm chart 0.6.117: Fulcio, Rekor v1 on Trillian
and a certificate transparency log. Fulcio trusts the cluster's own Kubernetes
service account tokens, so signing is keyless and needs no browser: the
identities are the service accounts `developer`, `ci-bot` and `intruder` in the
namespace `workstation`. The bootstrap builds a trusted root, a signing
configuration and a client trust configuration for the private stack, and
mounts them at `/trust` in every pod.

The **workstation** pod has `cosign` v3.1.4, `gitsign` v0.18.0, `rekor-cli`,
`git`, `curl` and `jq`. Section 010 adds Gitea (`gitops/inventory-app`),
section 020 a Go 1.25 pod with sigstore-go, and section 030 a Python 3.13 pod
with sigstore-python. Allow about 6 GiB of memory.

The environment plumbing (config files, scripts, manifests) is generated; see
`CLAUDE.md`, "Generated files".

## Running a playground

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS122.git -c sections/<section>/<module>/playground
astrona destroy <name>
```

## Running a lab

Labs and capstones are graded. Read `question.md`, do the work, and submit:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS122.git -c sections/<section>/<module>/labs/lab-01
astrona submit -c sections/<section>/<module>/labs/lab-01
astrona destroy <name>
```

Each lab grades the **final state** with independent checks, and several of
them deliberately reject the plausible-but-wrong fix (a verifier that accepts
any signer, a swallowed verification error, signing with another identity,
changing a file to make a signature fit).
