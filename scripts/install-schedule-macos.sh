#!/usr/bin/env bash
# =============================================================================
# scripts/install-schedule-macos.sh  -  register a launchd job that runs the
# ETL workflow every N minutes (default: ETL_SCHEDULE_MINUTES or 15).
#
# Usage:
#   ./scripts/install-schedule-macos.sh
#   ETL_SCHEDULE_MINUTES=30 ./scripts/install-schedule-macos.sh
#   ./scripts/install-schedule-macos.sh --uninstall
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PLIST="$HOME/Library/LaunchAgents/com.etl_gdt.workflow.plist"
LABEL="com.etl_gdt.workflow"

if [[ "${1:-}" == "--uninstall" ]]; then
  if [[ -f "$PLIST" ]]; then
    launchctl unload "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
    echo "Uninstalled $LABEL"
  else
    echo "Nothing to uninstall ($PLIST not found)"
  fi
  exit 0
fi

MINUTES="${ETL_SCHEDULE_MINUTES:-15}"
if [[ ! "$MINUTES" =~ ^[0-9]+$ ]] || [[ "$MINUTES" -lt 1 ]]; then
  echo "ETL_SCHEDULE_MINUTES must be a positive integer" >&2
  exit 1
fi

mkdir -p "$HOME/Library/LaunchAgents" "$ROOT/logs"

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${ROOT}/scripts/run-workflow.sh</string>
  </array>
  <key>WorkingDirectory</key>
  <string>${ROOT}</string>
  <key>StartInterval</key>
  <integer>$((MINUTES * 60))</integer>
  <key>RunAtLoad</key>
  <false/>
  <key>StandardOutPath</key>
  <string>${ROOT}/logs/schedule.log</string>
  <key>StandardErrorPath</key>
  <string>${ROOT}/logs/schedule.log</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin</string>
  </dict>
</dict>
</plist>
PLIST

# Reload (unload first if already loaded)
launchctl unload "$PLIST" 2>/dev/null || true
if launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null; then
  echo "Installed $LABEL (every ${MINUTES} min) via launchctl bootstrap"
else
  launchctl load -w "$PLIST"
  echo "Installed $LABEL (every ${MINUTES} min) via launchctl load"
fi

echo "Plist: $PLIST"
echo "Log:   $ROOT/logs/schedule.log"
echo "Uninstall: ./scripts/install-schedule-macos.sh --uninstall"