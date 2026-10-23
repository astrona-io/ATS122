# Section 030: Signing And Verifying From Python

Build systems, package tools and release scripts are often written in Python. When they sign or check artifacts, calling a command-line tool works, but it is easy to get the flags wrong and hard to handle errors. sigstore-python is the Sigstore project's Python client: a command-line tool and a library that sign and verify Sigstore bundles.

This section uses sigstore-python against the private Sigstore stack in your cluster, first from the command line and then from Python code, and closes with the other language clients. The signer is the Kubernetes service account `ci-bot`, whose token Fulcio accepts as an identity token.

**Topic covered:** Signing and verifying with sigstore-python

## What you will learn

- The `sigstore sign` and `sigstore verify identity` commands, and the `--identity-token` and `--trust-config` options.
- What a client trust configuration is: a trusted root and a signing configuration in one file.
- Why the identity token's audience must be `sigstore`, and where ambient credentials come from.
- Signing from Python with `SigningContext`, `IdentityToken` and `sign_artifact`.
- Verifying from Python with `Verifier`, `Bundle` and an `Identity` policy.
- Which other Sigstore language clients exist and what to check before you use one.

## The learning path

The module starts at its landing page, which also launches the playground. The playground holds a Python pod with sigstore-python 4.5.1, running as the service account `ci-bot`, and a build output to sign.

1. The sigstore-python Command Line
2. Signing And Verifying In Python Code, followed by the lab **Sign And Verify A Build Output From Python**
3. The Other Language Clients
4. Summary

## Section capstone: Repair A Python Release Signing Step

A release step signs every file of a release folder from Python and checks the result. It fails before it signs anything, and even after that is fixed, cosign rejects its bundles and its own check rejects every file. The task is to find the three faults and fix them. Work it after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS122.git -c sections/section-030/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-030/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-122-capstone-030
```
