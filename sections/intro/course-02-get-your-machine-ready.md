# Get Your Machine Ready

Every playground and lab in this course runs on your own machine, in a small Kubernetes cluster. A tool called `astrona` builds it for you, sets it up, grades your work and removes it again. This page gets your machine ready: first the tools you need, then the handful of `astrona` commands you will use every day, and last what to do when a start goes wrong.

## What you need

Every section needs the same set of tools. Install these before you start:

- **A container engine:** Docker or Podman. The cluster runs inside it.
- **`kind`:** runs Kubernetes inside the container engine.
- **`kubectl`:** talks to the cluster. Every Sigstore command in this course runs through `kubectl exec` in a pod, so you do not need `cosign`, `gitsign`, Go or Python on your machine.
- **`helm`:** installs the private Sigstore stack. Each playground and lab also puts Helm 3.22.1 in `/usr/local/bin` or `~/.local/bin`, so the version always matches the course.
- **The astrona command-line tool.**
- **A text editor:** you save Go and Python files on your machine and copy them into a pod.

The private Sigstore stack runs a database, a log server, Rekor, Fulcio and a certificate transparency log, so it needs memory. Give your container engine at least **6 GiB**. The playgrounds and labs also need **outbound internet** while they start: they download Helm, the Sigstore images and the client tools, and, in the Go and Python sections, the Go modules and the `sigstore` Python package. The first start of an environment can take ten minutes or more. Without outbound internet, the start fails with download errors that have nothing to do with Sigstore.

You do not have to check your tools by hand. Let `astrona` look at your machine for you:

```sh
astrona setup
```

`astrona setup` looks at what is missing, shows you each step it would take, and asks before it does anything. On macOS it can install `kind`, `kubectl` and Podman. Install `helm` yourself.

Later, you can check your machine at any time:

```sh
astrona check
```

## The commands you use every day

Once your machine is ready, you need only a handful of `astrona` commands. Each module page and lab page shows the exact command to copy, so you do not need to remember paths. This section walks through them in the order you meet them: sign in, start, pause, submit and clean up.

Labs from the course catalog are tied to your Astrona account, so you sign in first:

```sh
astrona login
```

Next you start a playground or a lab. Each module page and lab page shows the exact `astrona run` command for it. It looks like this:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS122.git -c sections/section-010/module-01/playground
```

When the cluster is ready, `kubectl` already points at it.

A chapter that sends you to a lab asks you to pause the playground first. Pausing frees your machine's memory but keeps everything you built:

```sh
astrona stop <name>
```

When the lab is done, start the playground again and carry on where you left off:

```sh
astrona start <name>
```

Inside a lab, you send your work for grading with `astrona submit`. The grader checks the live cluster. It verifies signatures with `gitsign` and `cosign` and runs your programs against good and bad files, so your fix has to actually work, not only make an error message go away. Each lab page shows the exact command:

```sh
astrona submit -c sections/section-010/module-01/labs/lab-01
```

You can submit as often as you like.

When you are done with a playground or a lab, remove it:

```sh
astrona destroy <name>
```

The name is the environment's name, printed by `astrona run` and shown on each page (for example `ats-122-playground-010-01`). It is not the folder path. To see what is on your machine, list it:

```sh
astrona list
```

> [!WARNING]
> **Run one environment at a time.** Each playground and lab is a whole cluster with its own Sigstore stack. Two running at once can use up your machine's memory, and it is easy to send a command to the wrong one. Pause or destroy the playground before you start the lab.

## When a start goes wrong

Sometimes a playground or lab does not start cleanly. Ask `astrona` what is wrong before you try anything else:

```sh
astrona doctor
```

It checks your machine, the lab's configuration and the running lab, and tells you how to fix what it finds.

If a start seems stuck, it is usually still pulling images or waiting for the log database to start. If it fails while it downloads something, check your network first, then the memory of your container engine. Remember also that a lab that starts with a commit or a program that fails verification is often broken on purpose: the lab's task tells you when that is the case. With your machine ready and these commands at hand, you can start the first module.
