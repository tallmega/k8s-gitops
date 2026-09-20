#!/usr/bin/env bash
# One-time secret bootstrap for the Kyrie OpenClaw cell. Run locally, then commit
# the two files it writes. Nothing here is sent anywhere except kubeseal (which only
# fetches the controller's public cert) and the files in this directory.
set -euo pipefail
cd "$(dirname "$0")"
NS=openclaw-kyrie
SEAL="kubeseal --controller-name sealed-secrets-controller --controller-namespace kube-system --format yaml"

read -r -s -p "Anthropic API key for Kyrie: " ANTHROPIC; echo
read -r -s -p "OpenAI API key for Kyrie (optional fallback, Enter to skip): " OPENAI; echo
TOKEN=$(openssl rand -hex 32)

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
ssh-keygen -q -t ed25519 -N "" -C "openclaw-kyrie-gateway" -f "$TMP/id_ed25519"

kubectl -n "$NS" create secret generic openclaw-kyrie-secrets --dry-run=client -o yaml \
  --from-literal=OPENCLAW_GATEWAY_TOKEN="$TOKEN" \
  --from-literal=ANTHROPIC_API_KEY="$ANTHROPIC" \
  --from-literal=OPENAI_API_KEY="$OPENAI" \
  --from-file=SANDBOX_SSH_KEY="$TMP/id_ed25519" \
  | $SEAL > openclaw-kyrie-sealed-secret.yaml

# The public key is not sensitive; a plain Secret keeps it in the same namespace.
kubectl -n "$NS" create secret generic openclaw-kyrie-sandbox-authorized-key --dry-run=client -o yaml \
  --from-file=authorized_key="$TMP/id_ed25519.pub" > openclaw-kyrie-sandbox-authorized-key.yaml

echo
echo "Wrote openclaw-kyrie-sealed-secret.yaml and openclaw-kyrie-sandbox-authorized-key.yaml"
echo "Gateway token for https://claw-kyrie.tallflix.ca (store it in your password manager, it is not shown again):"
echo "  $TOKEN"
