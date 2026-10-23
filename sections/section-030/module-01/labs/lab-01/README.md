---
estimated_duration: 25m
---

# Sign And Verify A Build Output From Python

- **ID:** LAB
- **Slug:** ats-122-lab-030-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona graded lab

Graded lab on a private Sigstore stack in the cluster. Read `question.md` for
the task; `solution.md` is the walkthrough. Built from the Sigstore
documentation and not yet run (see the repository `CLAUDE.md`).

## Run it

```sh
astrona run -c .
astrona submit
astrona destroy ats-122-lab-030-01
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-122-lab-030-01`), not
the config path.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition, bootstrap and grading |
| `question.md` | The task |
| `solution.md` | Step-by-step walkthrough |
| `prerequisites.md` | Assumed knowledge and what the environment provides |
| `bootstrap/01-install-sigstore.sh` | Helm, the private Sigstore stack, the workstation and the trust material |
| `bootstrap/02-seed-state.sh` | The starting state of the task |
| `manifests/` | Helm values and the workstation (and runner) pods |
| `solution/apply.sh` | Reference solution used by `astrona test` |
| `testing/wait-for-sigstore.sh` | Waits until the stack answers |
| `validation/` | Grading scripts, one per check |
