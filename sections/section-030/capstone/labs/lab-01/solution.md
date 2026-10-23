# Solution: Repair A Python Release Signing Step

Work the task yourself first. Running `astrona submit -c sections/section-030/capstone/labs/lab-01` after a step tells you which checks pass.

The grader checks three things: the token audience of `py-runner`, that every bundle `sign_release.py` writes verifies with cosign as `ci-bot`, and that `verify_release.py` passes the signed folder and fails a changed copy.

## Step 1: Run the signing step and read the error

Define the helpers on your machine and run the script:

```sh
pyrun() { kubectl -n workstation exec -i deploy/py-runner -- "$@"; }
put_file() { kubectl -n workstation exec -i "deploy/$1" -- sh -c "cat > '$3'" < "$2"; }
pyrun python /work/sign_release.py /work/release
```

The script stops with an error from `IdentityToken`: the token's audience is not the expected one. Look at the token's `aud` claim and at the Deployment:

```sh
pyrun python -c 'import base64, json; part = open("/var/run/sigstore/cosign/oidc-token").read().split(".")[1]; print(json.loads(base64.urlsafe_b64decode(part + "=" * (-len(part) % 4)))["aud"])'
kubectl -n workstation get deployment py-runner \
  -o jsonpath='{.spec.template.spec.volumes[?(@.name=="oidc")].projected.sources[0].serviceAccountToken.audience}'
```

Both say `kubernetes`. Fulcio and sigstore-python need `sigstore`.

## Step 2: Fix the token audience

The audience is set in the projected volume of the Deployment. Change it, and wait for the new pod and its sigstore-python install:

```sh
kubectl -n workstation edit deployment py-runner
```

In the editor, under `volumes`, find the volume `oidc` and change `audience: kubernetes` to `audience: sigstore`, then save. Then check the rollout and wait until the pod is ready:

```sh
kubectl -n workstation rollout status deployment/py-runner --timeout=900s
kubectl -n workstation wait --for=condition=Ready pod -l app=py-runner --timeout=600s
```

The Deployment uses the `Recreate` strategy and `/work` is a persistent volume, so the release folder and the scripts are still there.

## Step 3: Find why the bundles do not verify

Run the signing script again, copy one file and its bundle to the workstation, and check them with cosign:

```sh
pyrun python /work/sign_release.py /work/release
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
pyrun cat /work/release/app.bin | ws sh -c 'cat > /tmp/app.bin'
pyrun cat /work/release/app.bin.sigstore.json | ws sh -c 'cat > /tmp/app.bin.sigstore.json'
ws sh -c 'cosign verify-blob --trusted-root /trust/trusted_root.json --bundle /tmp/app.bin.sigstore.json \
  --certificate-identity https://kubernetes.io/namespaces/workstation/serviceaccounts/ci-bot \
  --certificate-oidc-issuer "$(cat /trust/issuer)" /tmp/app.bin'
```

cosign rejects it because the digest does not match the file. Read the script:

```sh
pyrun cat /work/sign_release.py > sign_release.py
```

It signs `path.read_text().strip().encode()`: the file read as text, with the trailing blank lines stripped. Those are different bytes from the file on disk. Change that line to sign the bytes exactly:

```python
            bundle = signer.sign_artifact(path.read_bytes())
```

## Step 4: Find why the check rejects the folder

Read the verification script:

```sh
pyrun cat /work/verify_release.py > verify_release.py
```

The issuer is hard-coded as `https://oauth2.sigstore.dev/auth`, the issuer of the public instance's browser login. The certificates of this cluster carry the cluster's own issuer. Read it from the trust material instead:

```python
ISSUER = Path("/trust/issuer").read_text().strip()
```

## Step 5: Copy the scripts back, sign and verify

```sh
put_file py-runner sign_release.py /work/sign_release.py
put_file py-runner verify_release.py /work/verify_release.py
pyrun python /work/sign_release.py /work/release
pyrun python /work/verify_release.py /work/release; echo "exit code $?"
pyrun sh -c 'rm -rf /tmp/changed && cp -r /work/release /tmp/changed && printf x >> /tmp/changed/app.bin'
pyrun python /work/verify_release.py /tmp/changed; echo "exit code $?"
```

The signed folder passes with exit code `0`, and the changed copy fails with `1`. Run the cosign check from Step 3 again: it now reports the signature as verified.

## Step 6: Submit

```sh
astrona submit -c sections/section-030/capstone/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Passing a token from `kubectl create token ci-bot --audience sigstore` | It works once, but the release step in the pod still has the wrong audience |
| Stripping the files on disk so the text matches | The task forbids changing the release; the files you ship would differ from the files you built |
| Removing the issuer from the `Identity` policy | Any issuer is then accepted for that identity |
| Signing from the workstation | The certificates name `developer`, and cosign's identity check as `ci-bot` fails |
