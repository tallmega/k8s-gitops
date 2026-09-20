#!/usr/bin/env bash
# One-time secret bootstrap for the Kevin OpenClaw cell. Run locally, then commit
# the two files it writes. Nothing here is sent anywhere except kubeseal (which only
# fetches the controller's public cert) and the files in this directory.
set -euo pipefail
cd "$(dirname "$0")"
NS=openclaw-kevin
SEAL="kubeseal --controller-name sealed-secrets-controller --controller-namespace kube-system --format yaml"

read -r -s -p "Anthropic API key for Kevin (optional, Enter to skip): " ANTHROPIC; echo
read -r -s -p "OpenAI API key for Kevin: " OPENAI; echo
[ -n "$OPENAI" ] || { echo "OpenAI key is required for this cell"; exit 1; }
TOKEN=$(openssl rand -hex 32)

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
ssh-keygen -q -t ed25519 -N "" -C "openclaw-kevin-gateway" -f "$TMP/id_ed25519"

kubectl -n "$NS" create secret generic openclaw-kevin-secrets --dry-run=client -o yaml \
  --from-literal=OPENCLAW_GATEWAY_TOKEN="$TOKEN" \
  --from-literal=ANTHROPIC_API_KEY="$ANTHROPIC" \
  --from-literal=OPENAI_API_KEY="$OPENAI" \
  --from-file=SANDBOX_SSH_KEY="$TMP/id_ed25519" \
  | $SEAL > openclaw-kevin-sealed-secret.yaml

# The public key is not sensitive; a plain Secret keeps it in the same namespace.
kubectl -n "$NS" create secret generic openclaw-kevin-sandbox-authorized-key --dry-run=client -o yaml \
  --from-file=authorized_key="$TMP/id_ed25519.pub" > openclaw-kevin-sandbox-authorized-key.yaml

echo
echo "Wrote openclaw-kevin-sealed-secret.yaml and openclaw-kevin-sandbox-authorized-key.yaml"
echo "Gateway token for https://claw-kevin.tallflix.ca (store it in your password manager, it is not shown again):"
echo "  $TOKEN"
