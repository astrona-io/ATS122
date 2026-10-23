# Sign And Verify Git Commits With Gitsign — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-122-playground-010-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A single sandbox environment with a private Sigstore stack (Fulcio, Rekor and a
CT log) and a workstation pod, which stays running so you can explore the
module's topic. Nothing to submit. Built from the Sigstore documentation and
not yet run (see the repository `CLAUDE.md`).

## Run it

```sh
astrona run -c .
astrona destroy ats-122-playground-010-01
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-122-playground-010-01`), not
the config path. `astrona submit` and `astrona test` do not apply.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition |
| `bootstrap/prepare.sh` | Helm, the private Sigstore stack, the workstation and the starting state |
| `manifests/scaffold-values.yaml` | Helm values for the scaffold chart |
| `manifests/lab-start.yaml` | The workstation pod and its service accounts |
| `manifests/gitea.yaml` | The in-cluster Git server and its tester pod |
| `docs/overview.md` | What the environment contains and ideas to try |
