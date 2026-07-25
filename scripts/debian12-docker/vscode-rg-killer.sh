#!/usr/bin/env bash
# vscode-rg-killer: continuously removes the ripgrep (rg) binaries shipped inside
# the VSCode server tree (~/.vscode-server). These spawn heavy recursive file-index
# scans that saturate this VPS. Deleting the binary prevents respawns; running
# processes are intentionally left to exit on their own (no auto-kill of IDE procs).
set -uo pipefail

TARGET_ROOT="/home/debian/.vscode-server"
INTERVAL="${INTERVAL:-10}"

while true; do
  # Kill any running ripgrep process first (VSCode/Copilot spawn these and they
  # saturate the VPS, load average >200). SIGKILL, no mercy.
  pkill -9 -x rg 2>/dev/null || true
  pkill -9 -f '/rg( |$)' 2>/dev/null || true

  if [ -d "$TARGET_ROOT" ]; then
    # Delete the binaries so VSCode/Copilot cannot respawn them. Matches any binary
    # named 'rg' under a *ripgrep* directory (@vscode/ripgrep-universal and
    # @github/copilot), across all VSCode server versions (Stable-<hash> changes
    # on every update).
    find "$TARGET_ROOT" -type f -name rg -path '*ripgrep*' -delete 2>/dev/null || true
  fi
  sleep "$INTERVAL"
done
