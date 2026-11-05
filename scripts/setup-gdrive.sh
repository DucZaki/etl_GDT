#!/usr/bin/env bash
# =============================================================================
# scripts/setup-gdrive.sh  -  point Hop's Google Drive VFS config at the
# working OAuth client (etltest-513514) and verify the token exists.
# Run once after cloning / on a new machine.
# =============================================================================
set -euo pipefail

HOP_HOME="${HOP_HOME:-/Users/minhduc/Downloads/apache-hop-2.19.0/hop}"
CONFIG="$HOP_HOME/config/hop-config.json"
CRED="${GDRIVE_CREDENTIALS_FILE:-/Users/minhduc/.hop/gdrive/client_secret_etltest.json}"
TOKENS="${GDRIVE_TOKENS_FOLDER:-/Users/minhduc/.hop/gdrive/tokens}"

if [[ ! -f "$CRED" ]]; then
  echo "Credentials file not found: $CRED" >&2
  exit 1
fi
if [[ ! -f "$TOKENS/StoredCredential" ]]; then
  echo "OAuth token not found: $TOKENS/StoredCredential" >&2
  echo "Run the OAuth flow first (see docs/runbook.md)." >&2
  exit 1
fi

python3 - "$CONFIG" "$CRED" "$TOKENS" <<'PY'
import json, sys
config, cred, tokens = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(config))
d.setdefault("googleDrive", {})
d["googleDrive"]["credentialsFile"] = cred
d["googleDrive"]["tokensFolder"] = tokens
json.dump(d, open(config, "w"), indent=2)
print("Updated", config)
print("  credentialsFile =", cred)
print("  tokensFolder    =", tokens)
PY