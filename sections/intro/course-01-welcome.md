# Welcome To The Course

This course trains you for the **Developer Tooling: Gitsign & Language Clients** part of the Astrona **Sigstore** training path. That part is 15% of the path. This page tells you who the course is for, what you can do at the end, which words and example setup it uses, and how its pages fit together.

## Who this course is for

You know your way around Kubernetes: namespaces, Deployments, service accounts, `kubectl exec` and `kubectl logs`. You use Git every day: you branch, commit, rebase and push. You can read a short Go program and a short Python script. You do not need to know Sigstore well yet. Each new idea is explained the first time it appears.

## What you can do at the end

Sigstore is a set of services and tools that sign software and record every signature in a public log. This course is about the tools a developer uses directly: the Git signer gitsign and the Sigstore libraries for Go and Python. It does not ask you to remember words. It asks you to sign something, verify it, and prove that a check passes for the right signer and fails for the wrong one.

The first topic is **signing Git commits with gitsign**. You will learn to:

- Explain how gitsign signs a commit with a short-lived certificate and records it in the transparency log.
- Configure Git and gitsign to sign every commit of a repository.
- Verify who signed a commit with `gitsign verify`, and re-sign commits that have the wrong signer.

Signatures only help if a program checks them, so the second topic is **verifying signatures from Go**. You will learn to:

- Name every check a Sigstore verifier makes, from the certificate chain to the signer's identity.
- Write a verifier with the `sigstore-go` library that accepts the right signer and refuses everything else.

The third topic is **signing and verifying from Python**. You will learn to:

- Sign and verify with the `sigstore` command of sigstore-python.
- Sign and verify from Python code with an identity token and a trust configuration.
- Say which other language clients exist and what to check before you use one.

Everything is written for **gitsign v0.18.0**, **sigstore-go v1.3.0** and **sigstore-python 4.5.1**.

## The words this course uses

The pages use Sigstore's, Git's and Kubernetes' own terms, because those are the words you meet in the tools, the logs and the documentation. Each term gets a short, plain definition the first time it appears on a page. A few terms come back on almost every page, so here they are up front.

**Keyless signing** means signing with a key that exists only for one signing and a certificate that names who signed. **Fulcio** is Sigstore's certificate authority: it gives out those short-lived X.509 certificates. **Rekor** is Sigstore's transparency log: an append-only record of every signing. An **OIDC identity token** is a signed token from an OpenID Connect (OIDC) provider that says who you are; Fulcio puts that identity into the certificate.

The proof of a signing travels in one file, and a verifier needs two things to check it:

| Item | What it is |
| --- | --- |
| Sigstore bundle | One JSON file with the signature, the certificate and the transparency log proof |
| Trusted root | The keys and certificates a verifier trusts: Fulcio's certificate chain and the log keys |
| Certificate identity | The signer named in the certificate, plus the OIDC issuer that vouched for it |

## The example setup in your playground

Every playground and lab runs a **private Sigstore stack** in a small Kubernetes cluster: Fulcio, Rekor and a certificate transparency log. It is private, so nothing you sign leaves your machine. In this stack, Fulcio accepts the cluster's own **service account tokens** as identity tokens. So every signer is a Kubernetes service account, and its identity in a certificate looks like `https://kubernetes.io/namespaces/workstation/serviceaccounts/developer`.

You work in the **workstation** pod. It runs as the service account `developer` and has `cosign`, `gitsign`, `git`, `curl` and `jq`. Two more service accounts exist: `ci-bot`, which signs build outputs, and `intruder`, which signs things it should not, so you can see a valid signature from the wrong signer. Depending on the section, a Git server (Gitea), a Go pod or a Python pod join the workstation.

Many labs start with something broken on purpose: a commit with the wrong signer, a verifier that accepts anyone, a token with the wrong audience. That is the material, not a fault in the course.

## How the course is laid out

The course has three sections. It starts where every developer signs first, in Git, and then moves into code.

| Section | What it covers |
| --- | --- |
| 010 | Signing Git Commits With Gitsign |
| 020 | Verifying Signatures From Go |
| 030 | Signing And Verifying From Python |

Each section has one module, and each module teaches one skill. A module brings together four kinds of material:

| What | What it is for | Graded? |
| --- | --- | --- |
| **Reading** | A short landing page, a few chapters that teach one idea each, and a summary | No |
| **Playground** | A small cluster on your own machine, to try everything you read | No |
| **Lab** | A cluster in a starting state, a task, and a grader that checks your work | Yes |
| **Capstone** | The last lab in a section, with several faults at once | Yes |

The best order is simple: read the chapters with the playground open next to them, take each lab when a chapter sends you to it, and finish each section with its capstone. The next part of this page explains how a module's pages guide you through that order.

## How to read a page

A module starts with a **landing page**. It says what the module teaches, what you should know first, and the order of its chapters. At the bottom of the landing page you start the module's playground, and you keep it running while you read.

The chapters (the parts of a module) read like the chapters of a technical book. Each one opens with the problem it solves, explains one idea in connected paragraphs, and closes with what you now know. The hands-on steps sit right in the text: a sentence or two on what to run and why, the command, and then what the result shows. Run each step in your playground as you reach it.

Every chapter ends with a box of common pitfalls, the mistakes people make most often with what the chapter taught, and how to spot them. Now and then a page also has a tip box with a habit or shortcut you can use again, well beyond that page. The two boxes look like this:

> [!TIP]
> **A tip.** A habit or shortcut you can use again, well beyond this one page.

> [!WARNING]
> **Common pitfalls.** The mistakes people make most often with what you just learned, and how to spot them. Every chapter ends with one.

When a graded lab tests what a chapter taught, that chapter ends with a **Your mission** section. It tells you what the lab asks, then gives every command you need, in order: pause the playground with `astrona stop`, start the lab with `astrona run`, and send your work for grading with `astrona submit`. Solve the lab on your own before you look at its solution. When the lab is done, remove it with `astrona destroy` and start the playground again with `astrona start`.

The last page of every module is the **Summary**. It sums up what you learned in a few short paragraphs, organised by idea. It also ends the module's hands-on work: the Summary page removes the playground, so your machine is clean before the next module.

One rule holds on every page. Code blocks are exactly what you type. Never change a command to make it "look right". If the result is different from what the page describes, that difference is the lesson.
