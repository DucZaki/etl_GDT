#!/usr/bin/env bash
# =============================================================================
# scripts/run-local.sh  -  macOS/Linux entry point for running this project
# on Apache Hop. Loads .env, then runs one or more pipelines.
#
# Usage:
#   ./scripts/run-local.sh                              # 01_check_local
#   ./scripts/run-local.sh pipelines/local/02_local_to_supabase.hpl
#   ./scripts/run-local.sh -a                           # run both local pipelines
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# --- load .env ---------------------------------------------------------------
if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

export HOP_IMPORT_ENVIRONMENT_VARIABLES=Y
# Avoid the macOS AWT deadlock during Google Drive OAuth in hop-run.
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} -Djava.awt.headless=true"

# --- resolve Hop home --------------------------------------------------------
HOP_HOME="${HOP_HOME:-/Users/minhduc/Downloads/apache-hop-2.19.0/hop}"
HOP_RUN="$HOP_HOME/hop-run.sh"
if [[ ! -x "$HOP_RUN" ]]; then
  echo "hop-run.sh not found at $HOP_RUN (set HOP_HOME in .env)" >&2
  exit 1
fi

PROJECT="${HOP_PROJECT_NAME:-etl_GDT}"
LOG_LEVEL="${ETL_LOG_LEVEL:-BASIC}"

run_one() {
  local pipeline="$1"
  if [[ ! -f "$pipeline" ]]; then
    echo "Pipeline not found: $pipeline" >&2
    exit 1
  fi
  echo "=== $(date '+%Y-%m-%d %H:%M:%S') :: $pipeline ==="
  SYS_PROPS="SUPABASE_HOST=${SUPABASE_HOST},SUPABASE_PORT=${SUPABASE_PORT},SUPABASE_DB=${SUPABASE_DB},SUPABASE_USER=${SUPABASE_USER},SUPABASE_PASSWORD=${SUPABASE_PASSWORD},SUPABASE_SSLMODE=${SUPABASE_SSLMODE}"
  "$HOP_RUN" -j "$PROJECT" -f "$ROOT/$pipeline" -r local -l "$LOG_LEVEL" -s "$SYS_PROPS"
}

if [[ "${1:-}" == "-a" || "${1:-}" == "--all" ]]; then
  run_one "pipelines/local/01_check_local.hpl"
  run_one "pipelines/local/02_local_to_supabase.hpl"
else
  run_one "${1:-pipelines/local/01_check_local.hpl}"
fi

echo "=== ALL PIPELINES FINISHED OK ==="
