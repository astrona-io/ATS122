# Writing style for this repo

All study text here (course pages, lab docs, READMEs, comments in YAML and
scripts) is for people learning a technical subject, often for a
certification exam. Many of them are not native English speakers and have no
university degree.

## Technical documentation in plain English

This is technical documentation. Say exactly what the system does, with the
real technical terms, in clear and simple English. Never hide a concept
behind a metaphor, a made-up name or a vague word: the reader must learn the
words they will meet in the product, the logs and the exam.

Strict guidelines:

1. Use the correct technical term every time (request, response, pod,
   namespace, Service, sidecar proxy, certificate, mTLS, JWT, listener). The
   first time a term appears in a file, define it in one plain sentence that
   says what it is and what it does. Spell out every acronym on first use.
2. No metaphors or analogies in explanations. Not "the communications
   officer", but "the sidecar proxy (Envoy)"; not "a signal", but "a
   request"; not "the planet", but "the namespace".
3. Simple sentences. Target a Flesch-Kincaid Grade Level of 8 or 9 for the
   prose around the terms. Keep sentences direct; split long sentences into
   two. No corporate buzzwords.
4. Use short paragraphs (max 3-4 sentences per paragraph).
5. Use the active voice ("istiod sends the configuration", not "the
   configuration is sent").

## How this applies to course material

- **Know which file you are in.** A module has a short landing page, a few
  deep-dive parts and a summary page. The landing page is a map: goals, what
  to know first, the order of the parts. The real teaching goes in the parts.
  The summary closes the module. A lab
  has a task, a step-by-step solution and a short intro. Keep each file to its
  job. Do not add "Prerequisite: ... Next: ..." navigation lines to pages;
  the landing page and the course outline already give the order.
- **Keep each part short.** One idea per part, about 5 to 8 minutes of
  reading and at most about 8 command blocks, so a learner can finish it with
  the playground in one sitting of about 15 minutes. Split at a natural seam
  where each half ends with something the learner has seen work. Never split
  only to hit a number. When you split, renumber the files, fix every "Part N"
  reference in the module and `astrona.yaml`.
- **Read like a book, not like a web page.** Each part reads as a chapter of
  a technical book. Open with a short paragraph on the problem it solves and
  why it matters. Link each paragraph to the next with a transition sentence.
  Close with a paragraph that sums up what the reader now knows and the
  question still open, before `## Common pitfalls` and the mission. Write
  explanations as prose; keep bullets for real lists (fields, ordered steps,
  options). Use `##` only when the topic changes and `###` only inside a long
  section, never for a single command. Weave hands-on steps into the text:
  one or two sentences on what to run and why, the command, the real output,
  then a sentence or two on what it shows.
- **The module ends with a summary.** The last page of every module is
  `course-0N-summary.md` with the title `# Summary`: a few short prose
  paragraphs on what the reader learned, organised by idea, optionally with
  one short list of key facts. It names no parts, modules, sections or
  chapters, and has no links, lab table, quiz or commands. Its last line is
  `<!-- astrona:playground:destroy -->` on its own line; the platform turns it
  into the step that removes the playground.
- **Every heading gets an intro.** A `##` section that has `###`
  subsections starts with one to three sentences that say what the section
  is about and why it matters, before the first `###`. Never put a `###`
  directly under a `##`.
- **Every module stands on its own.** Never refer to other sections or
  modules: no "see section 040", "as module 3 showed", "you met this in
  section 000", and no links to pages in another module. If the reader needs
  a fact from elsewhere, state the fact directly in one or two sentences.
  This also goes for parts of the same module: never write "Part 2 shows",
  "from Part 1" or "as in Part 3". Say the fact itself ("the commands below
  need the `scout` `DestinationRule` applied"). This includes the summary.
  The landing page does not have a "Where this fits" section.
- **Write words out in full.** Do not use informal short forms in prose:
  write "communications", "configuration", "repository", "administrator",
  "for example" and "that is", never "comms", "config", "repo", "admin",
  "e.g." or "i.e.". Names in code, commands and file paths stay as they are.
- **Exam terms stay.** The product's own names are what the reader must learn
  (for example a resource kind, a field, a command). Use them as they are and
  define each one in plain technical words the first time it appears in a
  file. Spell out acronyms on first use, with a short plain meaning.
- **The space theme is only for examples.** Space appears in two places and
  nowhere else: the names of the example workloads (the Starfleet: `bridge`,
  `scout`, `shuttle`, `probe`, the `starfleet` and `outpost` namespaces) and
  the short scenario that opens a lab task or a practice exercise (for
  example "the `drifter` in `outpost` must keep reaching the probe"). The
  explanation around an example is plain technical text: write "the
  `shuttle` pod sends a request to the `probe` Service", never "the shuttle
  sends a signal to the probe ship". Do not address the reader as an
  astronaut, and do not use space metaphors (communications officer, mission
  control, badge, airlock, guest list, star chart) for Istio or Kubernetes
  concepts. Titles of pages and labs name the technical task ("Require mTLS
  With PeerAuthentication"), not a space story.
- **Show one real example before the rule.** Start with a concrete case the
  reader can run, then give the general rule.
- **Say which part does the work.** Readers often mix up the parts of a system
  that sit close together. Whenever something happens, say which component
  did it.
- **Never change code to fit the style.** Commands, configuration files, field
  names, resource names, log lines and command output stay exactly as they
  are. They were run and checked on a real system. Never make up command
  output. If you shorten it, say that you did.
- **Prose only.** The grade-level and sentence rules apply to explanations.
  They do not apply to code blocks, tables of field names or reference lists
  (those may stay short and dense).
- **Keep the page furniture the same.** Hands-on steps are part of the prose
  (see "Read like a book"), not boxes or headings of their own. A `> [!TIP]` box is
  only for a real tip: advice the reader can reuse beyond this one step (a
  habit, a shortcut, how to spot a problem, an exam habit). Everything else
  is a normal sentence: notes about the current step ("if the log line is
  old, run it again"), background facts, optional extra steps, and plain
  information. Never a command snippet, never two in a row, and most pages
  need zero or one tip. Each part ends with a
  `## Common pitfalls` `> [!WARNING]` block for that part only. Use a Mermaid
  diagram for a flow, an order or a state change, keep it under about 12
  boxes, and follow it with one sentence that says what it shows.
- **Labs come right after the part they practise.** Do not collect all
  graded labs at the end of a module. In `astrona.yaml`, put each lab (its
  `question.md` reading and the `lab` entry) right after the reading part it
  tests. If a part teaches a gradeable skill and no lab covers it, create a
  new lab. That part then ends with a `## Your mission: <lab title>` section:
  one sentence on what the reader can now do, one on what the mission asks,
  then pause the playground (`astrona stop <playground name>`), the
  `astrona run` and `astrona submit` commands, and finally
  `astrona destroy <lab name>` plus `astrona start <playground name>`.
- **Renew the playground before hands-on work.** Every reading part that
  runs commands has `<!-- astrona:playground:renew -->` exactly once, on its
  own line, right before the first hands-on step (the first "Save this as"
  or the first command block), so the playground timer is reset before the
  learner needs the playground. Not on landing pages (they carry
  `<!-- astrona:playground -->`), summary pages (they carry
  `<!-- astrona:playground:destroy -->`) or pages without commands.
- **Mermaid without HTML.** The platform renders Mermaid with HTML labels
  switched off, so `<br/>` and any other HTML tag break the drawing. Rules:
  - One line per box, no `<br/>`, no HTML. Keep the box to the thing's name
    (`"scout-v2"`, `"istiod"`, `"Service: scout"`).
  - Put the logic on the arrows: `E -->|"version: v2"| P2`,
    `I -->|"CDS"| C`, `A -->|"end-user: jason"| B`. Keep edge labels short.
  - Quote every label. Prefer `flowchart TB`; use `LR` only for a short chain.
  - Sequence diagrams: short participant aliases (`participant S as shuttle`)
    and short message text.
  - Anything longer (cluster names, full hostnames) goes in the sentence under
    the diagram.
- **Every course starts with an Introduction.** It lives in `sections/intro/`
  and is the first entry in `astrona.yaml` (`id: module-intro`, title
  "Introduction"). It has exactly these four pages, in this order:
  - `README.md`, `# Introduction`: what the introduction covers and its three
    pages, named in prose (no links), ending with the topic the course starts
    with.
  - `course-01-welcome.md`, `# Welcome To The Course`: who the course is for,
    the exam domain and what the reader can do at the end, the words the
    course uses, the example app, how the course is laid out and how to read
    a page.
  - `course-02-get-your-machine-ready.md`, `# Get Your Machine Ready`: the
    tools to install, the `astrona` commands used every day, and what to do
    when a start goes wrong.
  - `course-03-how-this-course-is-made.md`, `# How This Course Is Made`: how
    content is written and checked, the maintainers, how to report a mistake,
    and the license.
  The Introduction teaches no product content and has no playground, labs or
  summary. Its only links are the repository's contributors page, issues
  page and license.
- **No links to other course files.** A course page (every reading listed in
  `astrona.yaml`, the playground guide `docs/overview.md`, and a lab's
  `question.md` and `solution.md`) never links to or points the reader at
  another page or file of the repository: no links to parts, summaries,
  labs, `question.md`, other modules, sections or the Introduction, and no
  "see `practice.md`" or "open `config.yaml`". The platform shows the pages in
  the order of `astrona.yaml`, so a link only adds a second, often wrong,
  path. Name a thing in plain words when the reader needs it ("the task is on
  the next page"), and state a fact on the page itself instead of sending the
  reader somewhere else. Repository files for authors (the root `README.md`,
  a lab's or playground's `README.md`) may link.
- **No links to outside sources.** Course pages, labs and playground docs do
  not link to or point at outside websites (the one exception is the
  `resources` field of a lab entry in `astrona.yaml`) (official docs, GitHub, blogs,
  RFCs), and they have no "Reference" or "Official docs" lists. Everything the
  reader needs is explained on the page itself. Not affected: addresses the
  reader actually uses in a command or browser (`http://127.0.0.1:9080`,
  `curl https://httpbin.org`), and the Introduction's contributors and
  "report a mistake" links.
- **Configuration goes to a file first.** Whenever the reader should apply
  YAML (course parts, playground docs, labs), use three separate steps:
  1. "Save this as `virtualservice-scout.yaml`:" followed by a plain
     ` ```yaml ` block with only the YAML. No `cat > file <<'EOF'`, no
     `kubectl apply -f - <<EOF`, no shell around it.
  2. "Apply it:" followed by a ` ```sh ` block with only
     `kubectl apply -f virtualservice-scout.yaml`.
  3. "Then check the result:" followed by the check commands, if any.
  The file name says the kind and the object. If a value must come from the
  reader's cluster (an IP address), use a placeholder like `<PARTNER>` in the
  YAML and say how to get the value (`echo $PARTNER`); never put shell
  variables inside YAML. Apply an object the first time its YAML appears; do
  not show it once "to read" and paste it again later. Never tell the reader
  to apply something from the playground's `examples/` folder: they start the
  playground with `astrona run`, so that folder is not on their machine.
- **Helpers have readable names.** Shell helper functions and variables use
  names that say what they do (`check_route`, `count_versions`,
  `$SERVICE_URL`), never single letters.


## About this repo (ATS122 only)

Everything above is general and can be copied to other course repositories. This
section is only true for this one.

### What the student is trying to learn

- **The goal:** master the **Developer Tooling: Gitsign & Language Clients**
  domain of the **Sigstore** training path (`ATP023`). It is 15% of the path.
  There is no official Sigstore certification exam; the path's domains and
  weights are Astrona's own, set in `ATP023/path.yaml`.
- **What the domain really tests:** signing and verifying where developers
  work: sign Git commits keylessly with `gitsign`, prove who signed a commit
  with `gitsign verify`, and sign and verify artifacts from code with
  `sigstore-go` and `sigstore-python`. Every explanation should lead to a
  command or a program the reader can run, and every fix should be proved with
  a verification that passes for the right signer and fails for the wrong one.
- **The three topics:** Git commit signing with gitsign, verification from Go
  with sigstore-go, and signing and verification from Python with
  sigstore-python (plus the other language clients in prose).
- **The sections:**

  | Section | Title | Topic |
  | --- | --- | --- |
  | 010 | Signing Git Commits With Gitsign | gitsign |
  | 020 | Verifying Signatures From Go | sigstore-go |
  | 030 | Signing And Verifying From Python | sigstore-python |

- **The versions:** `gitsign` **v0.18.0**, `cosign` **v3.1.4**, `rekor-cli`
  v1.5.5 (workstation pod), `sigstore-go` **v1.3.0** on `golang:1.25.14-alpine`
  (sigstore-go v1.3.0 needs Go 1.25.8 or later), `sigstore-python` **4.5.1** on
  `python:3.13.17-slim`. The private Sigstore stack is the `scaffold` Helm
  chart **0.6.117** (Fulcio chart 2.11.4 with Fulcio v1.9.0, Rekor chart 1.8.7
  with Rekor v1.5.4 on Trillian, CT log chart 0.2.69) and Helm **3.22.1**, on
  a single-node `kind` cluster. Do not teach fields, flags or output from
  other versions without saying so.
- **The main sources:** the Sigstore documentation, <https://docs.sigstore.dev/>,
  and the source of each tool at its pinned tag: `sigstore/gitsign` v0.18.0
  (README and `internal/`), `sigstore/sigstore-go` v1.3.0 (`pkg/verify`,
  `pkg/root`, `pkg/bundle`), `sigstore/sigstore-python` v4.5.1
  (`sigstore/_cli.py`, `sigstore/sign.py`, `sigstore/verify/`,
  `sigstore/models.py`), `sigstore/cosign` v3.1.4 (`doc/`), and
  `sigstore/helm-charts` at `scaffold-0.6.117`. Sigstore is an Open Source
  Security Foundation (OpenSSF) project under the Linux Foundation; it is not
  a CNCF project.

### Status: built, not yet run

The first version of this repository was written from the Sigstore
documentation and source **without a live run**. No playground or lab has been
started, and no `astrona test` has passed yet. The Go programs compile and pass
`go vet` against the pinned modules, and the Python scripts compile; nothing
has run against a Sigstore stack. Until a maintainer runs them:

- Pages describe results in words. Do not add `text` output blocks until the
  output comes from a real run, and then paste it exactly.
- Treat every lab as unverified. Run `astrona validate` and `astrona test` on
  each one, one cluster at a time, before the course goes past `maturity:
  draft`.
- Remove this subsection when every lab has passed `astrona test`.

The riskiest assumptions, to check first on a live run:

1. Fulcio accepts the `kind` cluster's service account tokens. The bootstrap
   reads the issuer from `/.well-known/openid-configuration`, configures it as
   a `kubernetes` issuer in Fulcio, and binds
   `system:service-account-issuer-discovery` to `system:unauthenticated`
   (lab-only) so Fulcio can read the discovery document and keys.
2. `gitsign` signs and verifies against the private stack with the
   `filesystem` (or `envvar`) token provider, offline Rekor mode, and trust
   from `GITSIGN_FULCIO_ROOT`, `SIGSTORE_REKOR_PUBLIC_KEY` and
   `SIGSTORE_CT_LOG_PUBLIC_KEY_FILE`, without reaching the public TUF root.
3. The trust material built with `cosign trusted-root create` and
   `cosign signing-config create` is accepted by sigstore-go and
   sigstore-python (`ClientTrustConfig` with plain `http://` service URLs and
   Rekor API version 1).
4. sigstore-python's `Identity` policy matches the URI subject alternative
   name of a Kubernetes identity and the issuer extension Fulcio v1.9 writes.
5. The CT log public key Secret is `ctlog-public-key` (key `public`) in
   `ctlog-system`, and Fulcio serves its chain at `/api/v1/rootCert`.

### Terms, not metaphors

| Term | First-use definition (example wording) |
| --- | --- |
| gitsign | A Git signing program that signs commits and tags keylessly with a short-lived Fulcio certificate and records them in Rekor |
| `gpg.format x509` / `gpg.x509.program gitsign` | The Git settings that make Git call an X.509 signing program, and name gitsign as that program |
| `commit.gpgsign` / `tag.gpgsign` | Git settings that sign every new commit or tag without the `-S` flag |
| `gpgsig` header | The part of a Git commit object that holds its signature; for gitsign a PEM-encoded signature with the certificate |
| `gitsign verify` | Verifies a commit's signature, its Rekor entry and the identity in its certificate (`--certificate-identity`, `--certificate-oidc-issuer`) |
| `git verify-commit` | Git's own check; with gitsign it checks the signature and the log entry but not who signed, and gitsign prints a warning |
| Online / offline Rekor mode | Online: only the commit hash is logged and verification searches Rekor. Offline: the log proof is stored in the commit, so verification needs no search |
| Credential cache | gitsign's optional cache (`system` keyring or the `gitsign-credential-cache` socket) that reuses one certificate for its lifetime |
| Token provider | Where gitsign or cosign gets the OIDC identity token: `interactive`, `filesystem`, `envvar`, `github-actions` and others |
| Language client | A library that signs or verifies Sigstore bundles from code: sigstore-go, sigstore-python, sigstore-java, sigstore-js, sigstore-rs, sigstore-ruby |
| Trusted root | The JSON document with the Fulcio certificate chain and the Rekor and CT log keys a verifier trusts |
| Signing config | The JSON document that names the Fulcio, Rekor, OIDC and timestamp services a signer uses |
| Client trust configuration | sigstore-python's file that holds a trusted root and a signing config together (`--trust-config`) |
| Certificate identity | The subject alternative name (SAN) of a Fulcio certificate plus its OIDC issuer extension; the "who" a verifier checks |
| Kubernetes service account identity | Fulcio's SAN for a service account token: `https://kubernetes.io/namespaces/<namespace>/serviceaccounts/<name>` |

### The example workloads

| Name | What it is |
| --- | --- |
| Private Sigstore stack (namespaces `fulcio-system`, `rekor-system`, `ctlog-system`, `trillian-system`) | The `scaffold` chart. Fulcio at `http://fulcio-server.fulcio-system.svc`, Rekor v1 at `http://rekor-server.rekor-system.svc`, CT log at `http://ctlog.ctlog-system.svc/sigstorescaffolding`. Lab-only, plain HTTP |
| `workstation` (namespace `workstation`) | `alpine:3.22` with `cosign`, `gitsign`, `rekor-cli`, `git`, `curl`, `jq`, `openssl`. Runs as the service account `developer`; its token (audience `sigstore`) is at `/var/run/sigstore/cosign/oidc-token`; the trust material is in `/trust` |
| ConfigMap `sigstore-trust` (namespace `workstation`) | `fulcio.pem`, `rekor.pub`, `ctfe.pub`, `trusted_root.json`, `signing_config.json`, `trust_config.json`, `issuer`; built at start, mounted at `/trust` |
| Service accounts `developer`, `ci-bot`, `intruder` (namespace `workstation`) | The identities. `intruder` exists so labs can show a valid signature from the wrong signer |
| Gitea (section 010 only) | `gitea/gitea:28.2.0-rootless`, repository `gitops/inventory-app` at `http://gitea.localtest.me:3000/gitops/inventory-app.git`; lab-only user `gitops` / `gitops-password`; cloned at `/root/inventory-app` in the workstation |
| `go-runner` (section 020 only) | `golang:1.25.14-alpine`, the module in `/work/verify-blob` (or `/work/verify-release`), example files in `/work/data` |
| `py-runner` (section 030 only) | `python:3.13.17-slim` with `sigstore==4.5.1`, runs as `ci-bot` with a token at `/var/run/sigstore/cosign/oidc-token`; `/work` is a persistent volume |

Pages use these helpers, defined on the page that needs them:

```sh
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
put_file() { kubectl -n workstation exec -i "deploy/$1" -- sh -c "cat > '$3'" < "$2"; }
```

Interactive work uses a shell: `kubectl -n workstation exec -it deploy/workstation -- sh`
(or `deploy/go-runner`, `deploy/py-runner`).

### Environment facts the text must respect

- **Keyless signing without a person.** Fulcio trusts this cluster's service
  account tokens (issuer type `kubernetes`), so every identity is a service
  account. The issuer URL depends on the cluster; pages read it with
  `cat /trust/issuer` and never hard-code it.
- **The public-good instance is optional and ungraded.** Signing with
  `fulcio.sigstore.dev` opens a browser login. Pages may show it as an optional
  step on the reader's own machine, with their own repository, never in a lab.
- **Gitsign configuration in the workstation.** The pod sets
  `GITSIGN_REKOR_MODE=offline` and the trust variables `GITSIGN_FULCIO_ROOT`,
  `SIGSTORE_REKOR_PUBLIC_KEY` and `SIGSTORE_CT_LOG_PUBLIC_KEY_FILE`. It does
  **not** set the Fulcio or Rekor URL or the token provider: setting those is
  part of the labs (`git config gitsign.fulcio`, `gitsign.rekor`,
  `gitsign.tokenProvider`).
- **GitHub does not show gitsign commits as verified.** The Sigstore root is
  not in GitHub's trust store, and a short-lived certificate needs the log
  entry to prove it was valid at signing time (gitsign README, v0.18.0). Gitea
  does not verify them either. Say so where a page mentions hosting.
- **No key material in the repository.** Every key is generated or issued in
  the environment.
- **CoreDNS:** copy the `rewrite stop` block (with the answer name rewritten
  back) as the generated scripts do; never the one-line `rewrite name` form.
- **Many environments start broken on purpose** (unsigned or wrongly signed
  commits, a verifier that accepts any signer, a token with the wrong audience).
  The fault is the material. Never "fix" it in the bootstrap.
- **The environment is heavy.** The scaffold stack runs MySQL, Trillian,
  Rekor, Redis, Fulcio and a CT log: allow about 6 GiB of memory and ten
  minutes or more for the first start.

### Generated files

The environment plumbing is generated by `gen.py` (with `lib.py`,
`manifests.py`, `envs.py`) in the author's scratchpad, not kept in this
repository: every `config.yaml`, author `README.md`, `prerequisites.md`,
`bootstrap/*.sh`, `solution/*`, `testing/*.sh`, `validation/*.sh` and
`manifests/*` under `playground/` and `labs/`. The scripts repeat the same
helper block; when you change a helper, change it in every environment.
Learner pages (`course*.md`, `docs/overview.md`, `question.md`, `solution.md`)
are hand-written.

### Where things are in this repo

The layout is the same as every Astrona course: `astrona.yaml`, `README.md`,
`sections/intro/`, `sections/section-0N0/README.md`, module pages
(`course.md`, `course-0N-*.md`), `playground/` (`config.yaml`,
`bootstrap/prepare.sh`, `manifests/`, `docs/overview.md`), labs
(`config.yaml`, `README.md`, `prerequisites.md`, `question.md`,
`solution.md`, `bootstrap/01-install-sigstore.sh`,
`bootstrap/02-seed-state.sh`, `manifests/`, `solution/apply.sh`,
`testing/wait-for-sigstore.sh`, `validation/validate-*.sh`) and one capstone
per section.

### Lab metadata in `astrona.yaml`

`training:` block: id `ATS122`, domain `Developer Tooling: Gitsign & Language
Clients`, weight `15`. Lab entries carry `title`, `path`, `difficulty`,
`estimated_duration`, `topic`, `task_kind`, `tags`, `learning_goals`,
`resources`, in that order, as in ATS016.

- `topic`: exactly one of `gitsign`, `commit-verification`, `go-client`,
  `python-client`, `trust-config`.
- `task_kind`: `build`, `troubleshooting` or `migration`.
- `tags`: 4 to 8, only from this list: `gitsign`, `git-config`,
  `commit-signing`, `gitsign-verify`, `rebase`, `keyless`, `fulcio`, `rekor`,
  `offline-verification`, `service-account-token`, `oidc-audience`,
  `trusted-root`, `signing-config`, `trust-config`, `bundle`, `sigstore-go`,
  `sigstore-python`, `cosign-verify-blob`, `certificate-identity`,
  `release-gate`.
- `resources`: 1 to 4 pages on `docs.sigstore.dev`, the project repositories
  on `github.com/sigstore`, `pkg.go.dev` or `sigstore.github.io`. The only
  place outside links are allowed.

### Running things

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS122.git -c sections/section-010/module-01/playground
astrona destroy ats-122-playground-010-01
astrona run --git ssh://git@github.com/astrona-io/ATS122.git -c sections/section-010/module-01/labs/lab-01
astrona submit -c sections/section-010/module-01/labs/lab-01
astrona destroy ats-122-lab-010-01
astrona test -c sections/section-010/module-01/labs/lab-01   # authors
```

Names: `ats-122-playground-<section>-<module>`, `ats-122-lab-<section>-<module>`,
`ats-122-capstone-<section>`. Graders check **behaviour** (`gitsign verify`
passes with the expected identity, a verifier program accepts the right signer
and refuses a changed file and the wrong signer, `cosign verify-blob` accepts a
bundle a Python script wrote) and reject the plausible but wrong fix
(verifying without an identity, swallowing a verification error, signing with
another service account, changing a file's content to make a signature fit).
A lab's `question.md` and `solution.md` must match what its `validation/`
scripts check.

### Where to find trusted sources

- **gitsign:** <https://github.com/sigstore/gitsign> (README at v0.18.0:
  configuration table, environment variables, verification, the GitHub FAQ)
- **Language clients:** <https://docs.sigstore.dev/language_clients/language_client_overview/>,
  <https://docs.sigstore.dev/language_clients/go/>,
  <https://docs.sigstore.dev/language_clients/python/>,
  <https://pkg.go.dev/github.com/sigstore/sigstore-go/pkg/verify>,
  <https://sigstore.github.io/sigstore-python/>
- **Bundles and verification:** <https://docs.sigstore.dev/about/bundle/>,
  <https://docs.sigstore.dev/cosign/verifying/verify/>
- **Fulcio identities:** <https://docs.sigstore.dev/certificate_authority/oidc-in-fulcio/>
- **Private stacks:** `sigstore/scaffolding` and `sigstore/helm-charts` on GitHub.
