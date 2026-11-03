# Summary

A release check must look at every file, accept only the signers you named, and tell the pipeline when anything failed. In sigstore-python, `Identity` names one signer by subject alternative name and issuer. `AnyOf` accepts when one of several policies accepts, `AllOf` accepts only when all of them do, and policies nest. The list of allowed signers is a short, reviewed list in the code, never input that comes with the files. `UnsafeNoOp` accepts every signer and must not decide anything.

A bundle is JSON and its certificate is standard X.509, so `jq` and `openssl` show what the verifier saw: the signer in the subject alternative name, the identity provider in an extension of the certificate, the digest that was signed, and the log entry with its integrated time. Reading a bundle shows what it claims; only the verifier checks that the claims are signed and logged. Inspect before you change a policy, because a wrong signer, a wrong provider and a time outside the validity dates each need a different fix.

An unattended check is judged by its exit code. A refused file, a missing bundle and a broken check are different problems, and all of them must end in a non-zero code. The loop continues after a failure so every bad file is reported, a counter decides the exit code, and a file without a bundle counts as a failure.

Identity tokens and Fulcio certificates both live for a short time. The verifier checks the certificate against the time recorded in the transparency log, not against the present, so old bundles keep verifying. The key facts to remember are these:

- Use `AnyOf` for a set of signers and keep the issuer in every `Identity`.
- Never let one failure hide the others, and never end a failing run with a zero exit code.
- Count a file without a bundle as a failure.
- Read the token when you sign, and keep tokens out of logs.
- A certificate that expired minutes after issue is still valid for a bundle, because the log time falls inside its window.

<!-- astrona:playground:destroy -->
