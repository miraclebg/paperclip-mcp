#!/usr/bin/env bash
# Install paperclip-mcp as a per-user macOS LaunchAgent: it starts at login, runs in the
# background and is restarted by launchd if it exits.
#
#   scripts/macos/install-launchagent.sh            # install (or reinstall) and start
#   PAPERCLIP_MCP_PORT=9012 scripts/macos/install-launchagent.sh
#
# Configuration is read from the repository's .env (the agent's working directory).
# Logs: ~/Library/Logs/paperclip-mcp/{stdout,stderr}.log
set -euo pipefail

LABEL="com.paperclip-mcp.server"
HOST="${PAPERCLIP_MCP_HOST:-127.0.0.1}"
PORT="${PAPERCLIP_MCP_PORT:-9011}"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG_DIR="$HOME/Library/Logs/paperclip-mcp"
DOMAIN="gui/$(id -u)"

# Resolve how to start the server: the installed console script, else `python3 -m`.
if BIN="$(command -v paperclip-mcp)"; then
  PROGRAM_ARGS=("$BIN")
elif PY="$(command -v python3)" && "$PY" -c "import paperclip_mcp" 2>/dev/null; then
  PROGRAM_ARGS=("$PY" -m paperclip_mcp)
else
  echo "error: paperclip-mcp is not installed. Run: pip install -e \"$REPO_DIR\"" >&2
  exit 1
fi
PROGRAM_ARGS+=(--transport streamable-http --host "$HOST" --port "$PORT")

if [[ ! -f "$REPO_DIR/.env" ]]; then
  echo "warning: $REPO_DIR/.env not found; copy .env.example to .env and fill it in." >&2
fi

xml_escape() {
  local s="$1"
  s="${s//&/&amp;}"; s="${s//</&lt;}"; s="${s//>/&gt;}"
  printf '%s' "$s"
}

args_xml=""
for a in "${PROGRAM_ARGS[@]}"; do
  args_xml+="    <string>$(xml_escape "$a")</string>"$'\n'
done

mkdir -p "$HOME/Library/LaunchAgents" "$LOG_DIR"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
${args_xml}  </array>
  <key>WorkingDirectory</key>
  <string>$(xml_escape "$REPO_DIR")</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>PYTHONUNBUFFERED</key>
    <string>1</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>ThrottleInterval</key>
  <integer>10</integer>
  <key>ProcessType</key>
  <string>Background</string>
  <key>StandardOutPath</key>
  <string>$(xml_escape "$LOG_DIR/stdout.log")</string>
  <key>StandardErrorPath</key>
  <string>$(xml_escape "$LOG_DIR/stderr.log")</string>
</dict>
</plist>
EOF
plutil -lint "$PLIST" >/dev/null

# Reload: boot out any previous instance, then bootstrap the fresh plist.
launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
launchctl bootstrap "$DOMAIN" "$PLIST"
launchctl enable "$DOMAIN/$LABEL"

echo "Installed $PLIST"
echo "Command:  ${PROGRAM_ARGS[*]}"
echo "Endpoint: http://$HOST:$PORT/mcp"
echo "Logs:     $LOG_DIR"
