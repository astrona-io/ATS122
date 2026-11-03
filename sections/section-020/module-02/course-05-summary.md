# Summary

A verifier proves only what its policy asks for, so the policy is the security decision. The certificate identity names the signers you accept, either as exact values or as regular expressions for the issuer and for the subject alternative name. An exact value names one signer. A pattern names a group, and it must be anchored at both ends and have its dots escaped, or it also matches signers you did not intend. An empty pattern must stop the program, not widen it.

When verification succeeds, the result records what was proved: the signer, the issuer and the trusted times the verifier used. Logging the signer from the result, not the pattern from the flag, gives an audit trail that names who actually signed. A successful result says that the evidence matches the policy; it says nothing about the safety of the file.

The trusted root holds the anchors a verifier believes: the certificate authorities, the transparency logs, the certificate transparency logs and the timestamp authorities. Every entry has a validity window, and the verifier checks the window at the time of signing. Old keys stay in the root with a closed window so that old bundles keep verifying. The root must come from a place an attacker cannot write.

The artifact policy ties the bundle to the file. The key facts to remember are these:

- Anchor every identity pattern and escape its dots; `.*` is the same as no check.
- Pin the issuer as well as the subject alternative name.
- Read the signer from the verification result, and never use the result when the error is not nil.
- Close the validity window of a rotated key and keep its entry in the trusted root.
- Hand the verifier the file or a trusted digest; skip the artifact only when no decision depends on the answer.

<!-- astrona:playground:destroy -->
