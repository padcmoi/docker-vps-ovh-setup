#!/usr/bin/env bash
# vscode-rg-repair: restores the ripgrep (rg) binaries inside the VSCode server
# tree (~/.vscode-server). VSCode ships one rg per server version and per
# extension; when they are missing the editor's search reports
# "spawn .../rg ENOENT". Reinstalls the system ripgrep into every expected
# location. Wired as ExecStopPost of vscode-rg-killer.service: stopping the
# killer undoes its deletions.
set -uo pipefail

TARGET_ROOT="${TARGET_ROOT:-/home/debian/.vscode-server}"
SOURCE_RG="${SOURCE_RG:-/usr/bin/rg}"

if [ ! -x "$SOURCE_RG" ]; then
  echo "vscode-rg-repair: no source binary at $SOURCE_RG (install ripgrep first: apt install ripgrep)" >&2
  exit 1
fi

if [ ! -d "$TARGET_ROOT" ]; then
  echo "vscode-rg-repair: $TARGET_ROOT does not exist, nothing to repair" >&2
  exit 0
fi

# The killer runs as root, so restored binaries would otherwise land root-owned
# inside a user home. Match the tree's own owner.
TREE_OWNER="$(stat -c '%u:%g' "$TARGET_ROOT" 2>/dev/null || true)"

installed=0
present=0

# VSCode uses two layouts: @vscode/ripgrep/bin/rg (older servers) and
# @vscode/ripgrep-universal/bin/<platform>/rg (current, also used by the Copilot
# extension). Deleting the binary leaves the directory behind, so enumerating
# leaf bin dirs finds both.
while IFS= read -r dir; do
  # Skip the parent bin/ of the universal layout: the binary lives one level
  # deeper, in bin/<platform>/.
  if [ -d "$dir/linux-x64" ] || [ -d "$dir/linux-arm64" ] || [ -d "$dir/darwin-x64" ]; then
    continue
  fi

  if [ -x "$dir/rg" ]; then
    present=$((present + 1))
    continue
  fi

  if install -m 755 "$SOURCE_RG" "$dir/rg"; then
    [ -n "$TREE_OWNER" ] && chown "$TREE_OWNER" "$dir/rg"
    echo "vscode-rg-repair: installed $dir/rg"
    installed=$((installed + 1))
  else
    echo "vscode-rg-repair: FAILED to install $dir/rg" >&2
  fi
done < <(find "$TARGET_ROOT" -type d \( -path '*ripgrep*/bin' -o -path '*ripgrep*/bin/*' \) 2>/dev/null)

echo "vscode-rg-repair: $installed restored, $present already present ($("$SOURCE_RG" --version | head -1))"
