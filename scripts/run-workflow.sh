#!/usr/bin/env bash
# =============================================================================
# scripts/run-workflow.sh  -  run the end-to-end Apache Hop workflow.
#
# Flow: read Google Drive xlsx -> load staging -> validate/clean -> upsert DB.
# Everything runs inside Hop (pipeline action + SQL action); no manual SQL.
#
# Usage:
#   ./scripts/run-workflow.sh              # Drive -> Supabase
#   ./scripts/run-workflow.sh --local      # local xlsx -> Supabase (no Drive)
# =============================================================================
set -euo pipefail

# Prevent overlapping runs (macOS has no flock by default).
LOCK_DIR="/tmp/etl_gdt_workflow.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "Another ETL run is already in progress; exiting." >&2
  exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

export HOP_IMPORT_ENVIRONMENT_VARIABLES=Y
# Avoid the macOS AWT deadlock during Google Drive OAuth in hop-run.
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} -Djava.awt.headless=true"

HOP_HOME="${HOP_HOME:-/Users/minhduc/Downloads/apache-hop-2.19.0/hop}"
HOP_RUN="$HOP_HOME/hop-run.sh"
if [[ ! -x "$HOP_RUN" ]]; then
  echo "hop-run.sh not found at $HOP_RUN (set HOP_HOME in .env)" >&2
  exit 1
fi

PROJECT="${HOP_PROJECT_NAME:-etl_GDT}"
LOG_LEVEL="${ETL_LOG_LEVEL:-BASIC}"
WORKFLOW="workflows/etl_drive_to_db.hwf"

if [[ "${1:-}" == "--local" ]]; then
  WORKFLOW="workflows/etl_local_to_db.hwf"
  shift
fi

if [[ ! -f "$WORKFLOW" ]]; then
  echo "Workflow not found: $WORKFLOW" >&2
  exit 1
fi

echo "=== $(date '+%Y-%m-%d %H:%M:%S') :: $WORKFLOW ==="
# metadata/rdbms/supabase.json uses ${SUPABASE_*} placeholders sourced from .env
SYS_PROPS="SUPABASE_HOST=${SUPABASE_HOST},SUPABASE_PORT=${SUPABASE_PORT},SUPABASE_DB=${SUPABASE_DB},SUPABASE_USER=${SUPABASE_USER},SUPABASE_PASSWORD=${SUPABASE_PASSWORD},SUPABASE_SSLMODE=${SUPABASE_SSLMODE}"
"$HOP_RUN" -j "$PROJECT" -f "$ROOT/$WORKFLOW" -r local -l "$LOG_LEVEL" -s "$SYS_PROPS"

echo "=== WORKFLOW FINISHED OK ==="
