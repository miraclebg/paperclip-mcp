#!/usr/bin/env bash
# Stop and remove the paperclip-mcp LaunchAgent installed by install-launchagent.sh.
set -euo pipefail

LABEL="com.paperclip-mcp.server"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$PLIST"
echo "Removed $LABEL (logs kept in ~/Library/Logs/paperclip-mcp)"
