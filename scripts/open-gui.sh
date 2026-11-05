#!/usr/bin/env bash
# =============================================================================
# scripts/open-gui.sh  -  open Apache Hop GUI directly in this project.
# Usage: ./scripts/open-gui.sh [pipeline-or-workflow-file]
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

export HOP_IMPORT_ENVIRONMENT_VARIABLES=Y

# Pass Supabase values as JVM system properties so ${SUPABASE_*} placeholders
# in metadata/rdbms/supabase.json resolve (single source of truth: .env).
HOP_OPTIONS="${HOP_OPTIONS:-} -DSUPABASE_HOST=${SUPABASE_HOST} -DSUPABASE_PORT=${SUPABASE_PORT} -DSUPABASE_DB=${SUPABASE_DB} -DSUPABASE_USER=${SUPABASE_USER} -DSUPABASE_PASSWORD=${SUPABASE_PASSWORD} -DSUPABASE_SSLMODE=${SUPABASE_SSLMODE}"
export HOP_OPTIONS

HOP_HOME="${HOP_HOME:-/Users/minhduc/Downloads/apache-hop-2.19.0/hop}"
HOP_GUI="$HOP_HOME/hop-gui.sh"
if [[ ! -x "$HOP_GUI" ]]; then
  echo "hop-gui.sh not found at $HOP_GUI (set HOP_HOME in .env)" >&2
  exit 1
fi

PROJECT="${HOP_PROJECT_NAME:-etl_GDT}"
FILE="${1:-pipelines/local/02_local_to_supabase.hpl}"

exec "$HOP_GUI" -project="$PROJECT" -file="$ROOT/$FILE"
