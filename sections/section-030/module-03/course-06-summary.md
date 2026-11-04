# Summary

A workflow policy names a workflow file, a Git reference and the GitHub issuer, and anything looser accepts code nobody reviewed. A GitHub Actions job gets an identity token from GitHub with the issuer `https://token.actions.githubusercontent.com`. Fulcio turns it into a short-lived certificate whose subject alternative name is the workflow reference: the repository, the path `.github/workflows/` with the file name, and the Git reference. Extensions of the certificate add the issuer, the repository, the commit, the reference and the event that started the run. Older certificates use older object identifiers for some of these fields.

In sigstore-python, an `Identity` with the full workflow reference and the issuer accepts one workflow at one reference. A release gate keeps its signers as data, builds each identity with one function, and combines them with `AnyOf`. `AllOf` demands every signer for every file and refuses a good release. The command `sigstore verify github` fills in the issuer and offers options for the GitHub extensions, and `sigstore verify identity` with the full reference puts the whole policy in one reviewable value.

The Git reference decides who can produce a matching signature. A branch moves with every merge. A tag names one version, and it is a strong pin only when the repository controls who can create tags. A pull request signs with the reference of the pull request unless the policy refuses it. A reusable workflow puts the called file in the identity, so the repository that ran the job is in an extension. Regular expressions must be anchored with `^` and `$`, with the dots escaped.

sigstore-js and sigstore-java verify with the same four inputs as Python: a bundle, the content, a trusted root and an expected identity with its issuer. A failure arrives as a rejected promise or an exception and must stop the work. sigstore-rs and sigstore-ruby complete the six clients, and a shared conformance suite keeps them in agreement. When a client refuses a file, a second tool with the same trusted root tells you whether the bundle or the policy is at fault. The key facts to remember are these:

- The identity of a workflow is its file and its Git reference, never the repository alone.
- Always pair the identity with the GitHub issuer.
- Use `AnyOf` for a set of signers, and anchor every regular expression.
- A failed verification must stop the pipeline in every language.
- Check bundle version, identity support and private-instance support before choosing a client.

<!-- astrona:playground:destroy -->
