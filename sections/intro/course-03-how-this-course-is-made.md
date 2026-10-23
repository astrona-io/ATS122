# How This Course Is Made

You will trust a course more when you know how it is built. This page tells you how the content is written and checked, who is behind it, and how you can help make it better.

## How the content is written

The course targets fixed versions of its tools. Everything is written for **gitsign v0.18.0**, **sigstore-go v1.3.0**, **sigstore-python 4.5.1** and **cosign v3.1.4**, against a private Sigstore stack installed with the `scaffold` Helm chart 0.6.117. When a page says how a tool behaves, it means that version.

Facts come from real sources. They are checked against the Sigstore documentation and against the source code of each tool at its pinned version: the gitsign README and code, the sigstore-go packages, and the sigstore-python command line and library. Each page then explains everything you need on the page itself, so you never have to leave the course to look something up.

Results are described honestly. When a page shows command output, it comes from a real run, and if the output is shortened, the page says so. If there was no real run to copy from, the page describes the result in words instead of making up output. The Go programs in this course are compiled and checked against the pinned libraries before they are published.

The same care goes into the graded labs, because their graders check behaviour. A grader verifies your commits with `gitsign verify`, runs your verifier against a good file, a changed file and a file from the wrong signer, and checks a bundle your script wrote with `cosign`. Many graders also reject the fix that only hides the problem, such as a verifier that accepts any signer. Each lab also has a reference solution that is meant to be run against its own grader, so the grader is known to accept a correct answer.

The pages are written in plain English, for people who are not native English speakers and have no university degree. Words are written out in full, and each technical term gets a short, plain definition the first time it appears. The pages use the real technical terms, not metaphors, because those are the words you meet in the tools and the documentation.

Finally, large parts of this course are drafted and edited with the help of AI tools. A maintainer reviews every change before it is published, and the technical checks above apply to all content, however it was written.

## Maintainers

A small group of people builds and looks after the course. The core maintainer is **Paris Nakita Kejser** ([@parisnakitakejser](https://github.com/parisnakitakejser)).

Many others have helped along the way. Every person who has changed the course is listed on the GitHub contributors page:
[github.com/astrona-io/ATS122/graphs/contributors](https://github.com/astrona-io/ATS122/graphs/contributors)

## Found a mistake? Report it

Even with these checks, mistakes slip through. If a command fails, a page says something wrong, or a lab grades a correct answer as wrong, please tell us. Every report makes the course better for the next learner. A good report takes four steps:

1. Open a new issue on GitHub: [github.com/astrona-io/ATS122/issues](https://github.com/astrona-io/ATS122/issues).
2. Say which page or lab it is (the file path is the easiest, for example `sections/section-010/module-01/labs/lab-01`).
3. Paste the command you ran and what you saw. Leave out tokens, private keys or anything else private. An identity token is a credential until it expires, so never paste one from a real system.
4. Say what you expected to happen instead.

Want to fix it yourself? Pull requests are welcome on the same repository.

## License

The course is published under the [Apache License 2.0](https://github.com/astrona-io/ATS122/blob/main/LICENSE). You are welcome to use it, share it and build on it under the terms of that license.
