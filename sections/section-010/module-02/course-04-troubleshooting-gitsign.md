# Troubleshooting Gitsign

When gitsign fails inside a Git command, Git shows only one generic line, and the reason stays hidden. A pipeline has no terminal, so there is nothing else to read. This part shows where gitsign writes the real error, breaks signing in two ways on purpose, and gives a short list of causes to check, in the order they usually happen.

## Where the real error is

When Git runs a signing program and the program fails, Git prints `error: gpg failed to sign the data` and `fatal: failed to write commit object`. These lines come from Git and name `gpg` for historical reasons, even when the program is gitsign. They say that the signing program returned an error, and nothing more.

gitsign can write its own messages to a file. Set `GITSIGN_LOG` (or the Git key `gitsign.logPath`) to a file path, and gitsign appends its status and error messages there. This is the first thing to do for any signing failure, because without a terminal gitsign shows its messages nowhere else. The file can hold identity details, so do not publish it.

## Break signing with a wrong address

The first fault is a Fulcio address that does not exist. In the workstation shell, set the working configuration, then point `GITSIGN_FULCIO_URL` at a name that cannot be resolved, only for one command, and ask gitsign to log:

<!-- astrona:playground:renew -->

```sh
cd /root/inventory-app
git config --local gpg.format x509
git config --local gpg.x509.program gitsign
git checkout -q -B practice/trouble main
printf 'trouble: one\n' >> src/app.txt
GITSIGN_LOG=/tmp/gitsign.log GITSIGN_TOKEN_PROVIDER=filesystem GITSIGN_REKOR_URL="$REKOR_URL" \
  GITSIGN_FULCIO_URL=http://fulcio.invalid git commit -a -S -m "Trouble one"
```

The commit fails with Git's generic error. Now read what gitsign wrote:

```sh
cat /tmp/gitsign.log
```

The file shows that gitsign could not reach the Fulcio address, with the name that failed. That is the real cause, and it was invisible until the log was on. The fix is the right address. Run the same commit again with `GITSIGN_FULCIO_URL="$FULCIO_URL"`, and it succeeds.

## Break signing with a wrong token

The second fault is a token that Fulcio refuses. On your machine, create a token for `developer` without the audience `sigstore`. The default audience is the Kubernetes API server, and Fulcio rejects it:

```sh
BAD_TOKEN="$(kubectl -n workstation create token developer)"
```

Sign one more commit in the workstation with that token and the `envvar` provider, and log the result:

```sh
kubectl -n workstation exec deploy/workstation -- env SIGSTORE_ID_TOKEN="$BAD_TOKEN" GITSIGN_TOKEN_PROVIDER=envvar sh -c '
  cd /root/inventory-app && printf "trouble: two\n" >> src/app.txt &&
  GITSIGN_LOG=/tmp/gitsign-token.log GITSIGN_FULCIO_URL="$FULCIO_URL" GITSIGN_REKOR_URL="$REKOR_URL" \
    git commit -a -S -m "Trouble two"; echo "exit code $?"; cat /tmp/gitsign-token.log'
```

The commit fails, and the log holds the answer from Fulcio: the token was not accepted, because of its audience. When you meet this error, decode the token and look at its `aud` claim. In the workstation shell, `jq -R 'split(".")[1] | @base64d | fromjson'` prints the claims of any token that you pipe into it. The fix is a token with `--audience sigstore`.

## The usual causes

The two faults above cover the most common classes. This table lists the causes in the order that they usually occur, with the quickest check for each one:

| Symptom | Likely cause | Check |
| --- | --- | --- |
| Git says `gpg failed to sign the data` and the log is empty | Git does not call gitsign | `git config --get gpg.format` is `x509` and `git config --get gpg.x509.program` is `gitsign` |
| gitsign waits, or tries to open a browser | The provider is `interactive` in a place with no browser | `GITSIGN_TOKEN_PROVIDER` or `gitsign.tokenProvider` is set |
| The log shows a connection error | The Fulcio or Rekor address is wrong or unreachable | `gitsign --version` prints the addresses in use |
| The log shows that the token was rejected | The audience, the issuer or the expiry of the token is wrong | Decode the token and read `aud`, `iss` and `exp` |
| Signing works, `gitsign verify` fails on the chain | gitsign does not trust the private Fulcio | `GITSIGN_FULCIO_ROOT` names the Fulcio certificate chain |
| Verification fails on the transparency log | gitsign does not trust the private Rekor, or the proof is missing | `SIGSTORE_REKOR_PUBLIC_KEY` names Rekor's public key, and `GITSIGN_REKOR_MODE` matches how the commit was signed |
| Verification says that the identity does not match | The commit is signed by another account, or no identity was passed | Run `gitsign verify` with `--certificate-identity-regexp='.*'` once, and read which identity signed |

The last check is a diagnostic and not a policy. The wildcard shows who really signed, so you can decide whether the commit or your expectation is wrong. Never keep the wildcard in a pipeline.

## Time and the ten-minute certificate

Fulcio certificates are valid for about ten minutes, so clocks matter. If a machine's clock is far from the real time, Fulcio or the verifier can see the certificate as not yet valid or already expired, and signing or verification fails with a time error. The proof in Rekor says when the signing happened, so a certificate that expired long ago is still accepted if the log entry shows it was valid at that moment. Check the date on the machine first, whenever the log mentions a time.

Online and offline Rekor modes show up here too. In online mode, `gitsign verify` looks the entry up in the Rekor server, so the server must be reachable and trusted. In offline mode, the proof is stored in the commit itself, so verification does not need the server, but a commit signed in online mode has no stored proof, and offline verification cannot succeed on it.

You can now find the cause of a gitsign failure from its own log, and match the common symptoms to a cause and a check. Together with the token providers, tag signing and history verification, that covers how a team runs gitsign without a person at a keyboard.

## Common pitfalls

> [!WARNING]
> - **Debugging only with Git's message.** `gpg failed to sign the data` carries no reason. Set `GITSIGN_LOG` and read the file.
> - **Leaving a wildcard identity in place.** `--certificate-identity-regexp='.*'` accepts every signer. Use it to look, never to decide.
> - **Setting only some of the trust variables.** A private instance needs the Fulcio chain, the Rekor key and the CT log key. One missing file gives a different error each time.
> - **Mixing Rekor modes.** A commit signed in online mode has no stored proof. Verify it in online mode, or sign it again in offline mode.
