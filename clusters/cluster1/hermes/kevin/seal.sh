#!/usr/bin/env bash
# Seals one key at a time into hermes-kevin-sealed-secret.yaml (created on first use,
# merged afterwards). The value is read silently and only ever passed to kubeseal, which
# fetches the controller's public cert. Commit the YAML afterwards.
#
#   ./seal.sh GOG_KEYRING_PASSWORD
#
# Keys used by the cell (non-Hermes containers only; Hermes' own keys go in its .env via the dashboard):
#   VAULT_COUCHDB_USER       CouchDB read-only member user (oc-vault-ro)
#   VAULT_COUCHDB_PASSWORD
#   GOG_KEYRING_PASSWORD     passphrase for gog's file keyring (any random string)
set -euo pipefail
cd "$(dirname "$0")"
KEY=${1:?usage: $0 KEY}
NS=hermes-kevin NAME=hermes-kevin-secrets OUT=hermes-kevin-sealed-secret.yaml
SEAL="kubeseal --controller-name sealed-secrets-controller --controller-namespace kube-system --format yaml"
read -r -s -p "$KEY: " VALUE; echo
[ -n "$VALUE" ] || { echo "empty value, nothing sealed"; exit 1; }
SECRET=$(kubectl -n "$NS" create secret generic "$NAME" --dry-run=client -o yaml --from-literal="$KEY=$VALUE")
if [ -f "$OUT" ]; then
  echo "$SECRET" | $SEAL --merge-into "$OUT"
else
  echo "$SECRET" | $SEAL > "$OUT"
fi
echo "sealed $KEY into $OUT"
