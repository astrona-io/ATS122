# Section 020: Verifying Signatures From Go

A signature protects nothing until a program checks it. Command-line tools such as `cosign verify-blob` work well in a shell, but a deployment controller, a release gate or a package manager has to verify inside its own code. sigstore-go is the Go library the Sigstore project maintains for that job.

This section opens a Sigstore bundle, names every check a verifier makes, and then writes a verifier in Go that accepts the right signer and refuses everything else. The signatures come from the private Sigstore stack in your cluster, where Kubernetes service accounts are the signers.

**Topic covered:** Verifying Sigstore bundles from Go with sigstore-go

## What you will learn

- What a Sigstore bundle holds: the signature, the message digest, the certificate and the transparency log entry.
- What a trusted root holds, and why a verifier needs one.
- The checks a verifier makes: certificate chain, certificate transparency, transparency log, signature and identity.
- Loading a trusted root and a bundle with sigstore-go.
- Building a verifier with thresholds, and a policy with an artifact and a certificate identity.
- Why "verify without an identity" and "print a warning and carry on" turn a verifier into a rubber stamp.

## The learning path

The module starts at its landing page, which also launches the playground. The playground holds a Go pod with sigstore-go v1.3.0 and three example files: one signed by the developer, one changed after signing, and one signed by another service account.

1. What A Verifier Checks
2. Writing A Verifier With sigstore-go, followed by the lab **Make A Go Verifier Check Who Signed**
3. Summary

## Section capstone: Gate A Release Folder With sigstore-go

A release check written in Go is supposed to block a release when any file is not properly signed. It lets three bad files through: one without a bundle, one changed after signing, and one signed by the wrong service account. The task is to make the check report every file and fail the release. Work it after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS122.git -c sections/section-020/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-122-capstone-020
```
