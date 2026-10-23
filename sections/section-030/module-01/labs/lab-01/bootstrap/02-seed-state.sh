#!/usr/bin/env bash
# Creates the starting state of `ats-122-lab-030-01`.
#
# The fault is the material: this script never fixes it.
set -euo pipefail

export PATH="/usr/local/bin:$HOME/.local/bin:$PATH"
HELM_VERSION="3.22.1"
SCAFFOLD_CHART_VERSION="0.6.117"
FULCIO_URL="http://fulcio-server.fulcio-system.svc"
REKOR_URL="http://rekor-server.rekor-system.svc"
CTLOG_URL="http://ctlog.ctlog-system.svc/sigstorescaffolding"
GIT_URL="http://gitea.localtest.me:3000/gitops/inventory-app.git"
GIT_USER="gitops"
GIT_PASSWORD="gitops-password"
REPO="inventory-app"
DEVELOPER_ID="https://kubernetes.io/namespaces/workstation/serviceaccounts/developer"
CI_BOT_ID="https://kubernetes.io/namespaces/workstation/serviceaccounts/ci-bot"
INTRUDER_ID="https://kubernetes.io/namespaces/workstation/serviceaccounts/intruder"

# ws CMD...: runs a command in the workstation pod (cosign, gitsign, git, jq).
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
# gorun CMD...: runs a command in the go-runner pod (Go 1.25).
gorun() { kubectl -n workstation exec -i deploy/go-runner -- "$@"; }
# pyrun CMD...: runs a command in the py-runner pod (Python 3.13, sigstore 4.5.1).
pyrun() { kubectl -n workstation exec -i deploy/py-runner -- "$@"; }

# issuer: prints the OIDC issuer of this cluster's service account tokens.
issuer() { kubectl -n workstation get configmap sigstore-trust -o jsonpath='{.data.issuer}' | tr -d '\n'; }

# token_for SA: prints a one-hour token for a service account in the
# namespace workstation, with the audience "sigstore" that Fulcio expects.
token_for() { kubectl -n workstation create token "$1" --audience sigstore --duration 1h; }

# sign_blob_as SA FILE: signs FILE (a path in the workstation pod) as the
# service account SA and writes FILE.sigstore.json next to it.
sign_blob_as() {
  local token
  token="$(token_for "$1")"
  ws cosign sign-blob --yes \
    --signing-config /trust/signing_config.json --trusted-root /trust/trusted_root.json \
    --identity-token "$token" --bundle "$2.sigstore.json" "$2" >/dev/null 2>&1
}

# send_file POD SRC DST: writes the local file SRC to DST in POD. kubectl exec
# can drop the end of a large stdin, so the sizes are compared and the copy is
# repeated until the whole file has arrived.
send_file() {
  local want got
  want="$(wc -c < "$2" | tr -d ' ')"
  for _ in 1 2 3 4 5; do
    kubectl -n workstation exec -i "deploy/$1" -- sh -c "mkdir -p \"\$(dirname '$3')\" && cat > '$3'" < "$2" &&
      got="$(kubectl -n workstation exec "deploy/$1" -- sh -c "wc -c < '$3'" | tr -d ' ')" &&
      [ "$got" = "$want" ] && return 0
    sleep 1
  done
  echo "ERROR: $2 did not arrive whole at $1:$3." >&2
  return 1
}
# copy_from_ws POD SRC DST: copies a file from the workstation pod to POD.
# The file goes through a local temporary file, not a pipe between two
# kubectl exec calls: if the receiving side ends early, the pipe fails with
# SIGPIPE (exit 141) and hides the real error.
copy_from_ws() {
  local tmp; tmp="$(mktemp)"
  ws cat "$2" > "$tmp" && send_file "$1" "$tmp" "$3"
  local rc=$?; rm -f "$tmp"; return $rc
}
# copy_to_ws POD SRC DST: copies a file from POD to the workstation pod.
copy_to_ws() {
  local tmp; tmp="$(mktemp)"
  kubectl -n workstation exec -i "deploy/$1" -- cat "$2" > "$tmp" && send_file workstation "$tmp" "$3"
  local rc=$?; rm -f "$tmp"; return $rc
}

# commit_as SA MESSAGE: in /root/inventory-app in the workstation pod, adds
# MESSAGE as a line of src/app.txt and commits it. SA is "none" (unsigned),
# "developer" (the pod's own token) or another service account name.
commit_as() {
  local token=""
  if [ "$1" != none ] && [ "$1" != developer ]; then token="$(token_for "$1")"; fi
  ws env SA="$1" MSG="$2" TOKEN="$token" FULCIO_URL="$FULCIO_URL" REKOR_URL="$REKOR_URL" sh -s <<'EOS'
set -e
cd /root/inventory-app
printf '%s\n' "$MSG" >> src/app.txt
git add src/app.txt
case "$SA" in
  none) git -c commit.gpgsign=false commit -q -m "$MSG" ;;
  developer) GITSIGN_FULCIO_URL="$FULCIO_URL" GITSIGN_REKOR_URL="$REKOR_URL" GITSIGN_TOKEN_PROVIDER=filesystem \
      git -c gpg.format=x509 -c gpg.x509.program=gitsign commit -q -S -m "$MSG" ;;
  *) GITSIGN_FULCIO_URL="$FULCIO_URL" GITSIGN_REKOR_URL="$REKOR_URL" GITSIGN_TOKEN_PROVIDER=envvar SIGSTORE_ID_TOKEN="$TOKEN" \
      git -c gpg.format=x509 -c gpg.x509.program=gitsign commit -q -S -m "$MSG" ;;
esac
EOS
}

# verify_branch BASE TIP IDENTITY: clones the repository fresh in the
# workstation and runs `gitsign verify` on every commit BASE..TIP. Prints one
# line per bad commit and a last line "COUNT <n> BAD <m>".
verify_branch() {
  ws env GIT_URL="$GIT_URL" BASE="$1" TIP="$2" IDENTITY="$3" ISSUER="$(issuer)" \
    FULCIO_URL="$FULCIO_URL" REKOR_URL="$REKOR_URL" sh -s <<'EOS'
rm -rf /tmp/grade
if ! git clone -q "$GIT_URL" /tmp/grade 2>/dev/null; then echo "COUNT 0 BAD 1"; exit 0; fi
cd /tmp/grade
if ! git rev-parse -q --verify "origin/$TIP" >/dev/null; then echo "branch $TIP not found"; echo "COUNT 0 BAD 1"; exit 0; fi
count=0; bad=0
for sha in $(git rev-list "origin/$BASE..origin/$TIP"); do
  count=$((count + 1))
  if ! GITSIGN_FULCIO_URL="$FULCIO_URL" GITSIGN_REKOR_URL="$REKOR_URL" \
      gitsign verify --certificate-identity="$IDENTITY" --certificate-oidc-issuer="$ISSUER" "$sha" >/dev/null 2>&1; then
    echo "not signed by $IDENTITY: $(git log -1 --format='%h %s' "$sha")"
    bad=$((bad + 1))
  fi
done
echo "COUNT $count BAD $bad"
EOS
}

# manifest_dir: prints the folder that holds this environment's manifests.
manifest_dir() {
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for candidate in "$here/../manifests" "./manifests" "$here/manifests"; do
    [ -d "$candidate" ] && { echo "$candidate"; return 0; }
  done
  echo "manifests"
}

# record_baseline KEY VALUE / baseline KEY: values the graders compare against,
# kept in the ConfigMap lab-baseline in the namespace workstation.
record_baseline() {
  # Create the ConfigMap only once; applying a one-key ConfigMap would erase
  # the values recorded before it.
  kubectl -n workstation get configmap lab-baseline >/dev/null 2>&1 || \
    kubectl -n workstation create configmap lab-baseline >/dev/null
  kubectl -n workstation patch configmap lab-baseline --type merge \
    -p "{\"data\":{\"$1\":\"$2\"}}" >/dev/null
}
baseline() { kubectl -n workstation get configmap lab-baseline -o jsonpath="{.data.$1}"; }

# put_file POD SRC DST: copies a file from this machine into POD.
put_file() { send_file "$@"; }

echo "[seed] Creating the build output and a file signed by another identity..."
pyrun sh -c 'mkdir -p /work/dist && head -c 4096 /dev/urandom > /work/dist/app.tar.gz && head -c 2048 /dev/urandom > /work/dist/other.tar.gz'
copy_to_ws py-runner /work/dist/other.tar.gz /tmp/other.tar.gz
sign_blob_as intruder /tmp/other.tar.gz
copy_from_ws py-runner /tmp/other.tar.gz.sigstore.json /work/dist/other.tar.gz.sigstore.json

echo "[lab] /work/dist/app.tar.gz in py-runner has no signature yet."
