#!/usr/bin/env bash
# Builds the environment of `ats-122-lab-030-01`: the private Sigstore stack,
# the workstation pod and its trust material, py-runner.
#
# Graded lab bootstrap: this prepares the environment ONLY. It never does
# the task.
set -euo pipefail
# grep -q stops reading at the first match; under pipefail the command
# writing into the pipe then fails with SIGPIPE and a match looks like a
# failure. This wrapper reads all input instead and keeps grep's exit status.
grep() {
  local arg quiet=0 args=()
  for arg in "$@"; do
    case "$arg" in
      --quiet|--silent) quiet=1 ;;
      --*) args+=("$arg") ;;
      -*q*) quiet=1; [ "$arg" = "-q" ] || args+=("${arg//q/}") ;;
      *) args+=("$arg") ;;
    esac
  done
  if [ "$quiet" = 1 ]; then command grep "${args[@]}" >/dev/null; else command grep "$@"; fi
}

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

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "$ARCH" in x86_64) ARCH=amd64 ;; aarch64|arm64) ARCH=arm64 ;; esac
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Pin Helm rather than accepting whatever is on the machine.
have_helm=""
command -v helm >/dev/null 2>&1 && have_helm=$(helm version --template '{{.Version}}' 2>/dev/null | sed 's/^v//')
if [ "$have_helm" != "$HELM_VERSION" ]; then
  echo "[lab] Downloading Helm ${HELM_VERSION} (${OS}/${ARCH})..."
  curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-${OS}-${ARCH}.tar.gz" | tar -xz -C "$WORK"
  install -m 0755 "$WORK/${OS}-${ARCH}/helm" "$BIN_DIR/helm"
fi
helm version --short

MANIFEST_DIR="$(manifest_dir)"

# add_coredns_rewrite HOST TARGET: makes HOST resolve to TARGET inside the
# cluster. The answer is rewritten back to HOST: Go programs (git, gitsign and
# cosign included) ignore DNS answers whose name differs from the question.
add_coredns_rewrite() {
  local host="$1" target="$2" host_re target_re corefile
  if kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}' | grep -q "$host"; then
    return 0
  fi
  host_re="$(printf '%s' "$host" | sed 's/\./\\\\./g')"
  target_re="$(printf '%s' "$target" | sed 's/\./\\\\./g')"
  corefile="$(kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}' \
    | awk -v host="$host" -v host_re="$host_re" -v target="$target" -v target_re="$target_re" '
        /^[[:space:]]*kubernetes / && !done {
          print "    rewrite stop {"
          print "        name regex " host_re " " target
          print "        answer name " target_re " " host
          print "    }"
          done=1
        } {print}')"
  kubectl -n kube-system create configmap coredns --from-literal=Corefile="$corefile" \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n kube-system rollout restart deployment/coredns
  kubectl -n kube-system rollout status deployment/coredns --timeout=120s
}

# Lab-only: Fulcio reads this cluster's OIDC discovery document and keys
# without credentials, so unauthenticated clients may read them.
kubectl create clusterrolebinding sigstore-oidc-discovery \
  --clusterrole=system:service-account-issuer-discovery --group=system:unauthenticated \
  --dry-run=client -o yaml | kubectl apply -f -
ISSUER="$(kubectl get --raw /.well-known/openid-configuration | sed -n 's/.*"issuer":"\([^"]*\)".*/\1/p')"
echo "[lab] Service account token issuer: ${ISSUER}"

# Fulcio trusts exactly this issuer, as the "kubernetes" issuer type.
# Fulcio v1.9.0 trusts the cluster CA for a kubernetes issuer only when the
# configuration also lists https://kubernetes.default.svc.
{
  echo "fulcio:"
  echo "  config:"
  echo "    contents:"
  echo "      OIDCIssuers:"
  echo "        \"https://kubernetes.default.svc\":"
  echo "          IssuerURL: \"https://kubernetes.default.svc\""
  echo "          ClientID: sigstore"
  echo "          Type: kubernetes"
  if [ "$ISSUER" != "https://kubernetes.default.svc" ]; then
    echo "        \"$ISSUER\":"
    echo "          IssuerURL: \"$ISSUER\""
    echo "          ClientID: sigstore"
    echo "          Type: kubernetes"
  fi
} > "$WORK/fulcio-issuer.yaml"

echo "[lab] Installing the private Sigstore stack (scaffold chart ${SCAFFOLD_CHART_VERSION}); this takes several minutes..."
helm repo add sigstore https://sigstore.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update sigstore >/dev/null
helm upgrade --install sigstore sigstore/scaffold --version "$SCAFFOLD_CHART_VERSION" \
  --namespace sigstore-system --create-namespace \
  --values "$MANIFEST_DIR/scaffold-values.yaml" --values "$WORK/fulcio-issuer.yaml" \
  --timeout 20m
for ns in trillian-system ctlog-system rekor-system fulcio-system; do
  for _ in $(seq 1 120); do kubectl get namespace "$ns" >/dev/null 2>&1 && break; sleep 5; done
done
for ns in trillian-system ctlog-system rekor-system fulcio-system; do
  kubectl -n "$ns" wait --for=condition=complete job --all --timeout=900s >/dev/null 2>&1 || true
  for deployment in $(kubectl -n "$ns" get deployment -o name); do
    kubectl -n "$ns" rollout status "$deployment" --timeout=900s
  done
done

echo "[lab] Starting the workstation pod..."
# lab-start.yaml is also listed under bootstrap.manifests in config.yaml, so it
# may already be applied. kubectl apply is idempotent.
kubectl apply -f "$MANIFEST_DIR/lab-start.yaml"
kubectl -n workstation rollout status deployment/workstation --timeout=600s
for _ in $(seq 1 60); do
  ws sh -c 'command -v git >/dev/null && test -x /tools/cosign && test -x /tools/gitsign' 2>/dev/null && break
  sleep 5
done

echo "[lab] Building the trust material of the private instance..."
for _ in $(seq 1 60); do
  kubectl -n ctlog-system get secret ctlog-public-key -o jsonpath='{.data.public}' 2>/dev/null | base64 -d > "$WORK/ctfe.pub" 2>/dev/null || true
  [ -s "$WORK/ctfe.pub" ] && break
  sleep 5
done
ws mkdir -p /tmp/trust
ws sh -c 'cat > /tmp/trust/ctfe.pub' < "$WORK/ctfe.pub"
ws env ISSUER="$ISSUER" FULCIO_URL="$FULCIO_URL" REKOR_URL="$REKOR_URL" CTLOG_URL="$CTLOG_URL" sh -s <<'EOS'
set -e
cd /tmp/trust
until curl -fsS "$FULCIO_URL/api/v1/rootCert" -o fulcio.pem; do sleep 5; done
until curl -fsS "$REKOR_URL/api/v1/log/publicKey" -o rekor.pub; do sleep 5; done
START="2026-01-01T00:00:00Z"
cosign trusted-root create \
  --fulcio "url=$FULCIO_URL,certificate-chain=fulcio.pem" \
  --rekor "url=$REKOR_URL,public-key=rekor.pub,start-time=$START" \
  --ctfe "url=$CTLOG_URL,public-key=ctfe.pub,start-time=$START" \
  --out trusted_root.json
cosign signing-config create \
  --fulcio "url=$FULCIO_URL,api-version=1,start-time=$START,operator=astrona-lab" \
  --rekor "url=$REKOR_URL,api-version=1,start-time=$START,operator=astrona-lab" \
  --rekor-config ANY \
  --oidc-provider "url=$ISSUER,api-version=1,start-time=$START,operator=astrona-lab" \
  --out signing_config.json
jq -n --slurpfile root trusted_root.json --slurpfile signing signing_config.json \
  '{mediaType: "application/vnd.dev.sigstore.clienttrustconfig.v0.1+json", trustedRoot: $root[0], signingConfig: $signing[0]}' \
  > trust_config.json
printf '%s\n' "$ISSUER" > issuer
EOS
for file in fulcio.pem rekor.pub ctfe.pub trusted_root.json signing_config.json trust_config.json issuer; do
  ws cat "/tmp/trust/$file" > "$WORK/trust-$file"
done
kubectl -n workstation create configmap sigstore-trust \
  --from-file=fulcio.pem="$WORK/trust-fulcio.pem" \
  --from-file=rekor.pub="$WORK/trust-rekor.pub" \
  --from-file=ctfe.pub="$WORK/trust-ctfe.pub" \
  --from-file=trusted_root.json="$WORK/trust-trusted_root.json" \
  --from-file=signing_config.json="$WORK/trust-signing_config.json" \
  --from-file=trust_config.json="$WORK/trust-trust_config.json" \
  --from-file=issuer="$WORK/trust-issuer" \
  --dry-run=client -o yaml | kubectl apply -f -
# A mounted ConfigMap reaches a running pod within about a minute.
for _ in $(seq 1 60); do
  ws test -s /trust/trusted_root.json 2>/dev/null && break
  sleep 5
done

echo "[lab] Waiting for sigstore-python in py-runner..."
kubectl -n workstation rollout status deployment/py-runner --timeout=900s
for _ in $(seq 1 120); do
  pyrun test -f /tmp/ready 2>/dev/null && break
  sleep 5
done
pyrun mkdir -p /work

echo "[lab] Environment ready."
