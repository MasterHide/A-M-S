#!/usr/bin/env bash
# xrestart.sh - installer for xrestart worker + systemd timer (x-ui restart only)
set -euo pipefail

INSTALL_PATH="/usr/local/bin"
WORKER="${INSTALL_PATH}/xrestart-worker.sh"
SERVICE="/etc/systemd/system/xrestart.service"
TIMER="/etc/systemd/system/xrestart.timer"
LOG_DIR="/var/log/xrestart"

info(){ echo -e "\033[1;34m[INFO]\033[0m $*"; }
err(){ echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }
confirm(){ read -rp "$* [y/N]: " yn; [[ "${yn:-}" =~ ^[Yy] ]]; }

# ensure running as root
if [ "$EUID" -ne 0 ]; then
  err "Please run as root (sudo)."
  exit 1
fi

# ensure required commands
for cmd in curl systemctl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    info "Installing missing package for $cmd"
    apt-get update -y && apt-get install -y curl || { err "install $cmd failed"; exit 1; }
  fi
done

# Clean old install if exists
if [ -f "$WORKER" ] || [ -f "$SERVICE" ] || [ -f "$TIMER" ]; then
  info "Found existing xrestart installation."
  if confirm "Remove existing installation and continue?"; then
    systemctl stop xrestart.timer xrestart.service >/dev/null 2>&1 || true
    systemctl disable xrestart.timer xrestart.service >/dev/null 2>&1 || true
    rm -f "$WORKER" "$SERVICE" "$TIMER"
    rm -rf "$LOG_DIR"
    systemctl daemon-reload
    info "Old installation removed."
  else
    info "Aborting."
    exit 0
  fi
fi

# Prompt user for Telegram details
read -rp "Enter Telegram Bot Token (format: 123456:ABC-...): " TG_TOKEN
read -rp "Enter Telegram Chat ID (or channel @name): " TG_CHAT
read -rp "Enter a short remark to identify this server in TG messages (e.g. mumbai-1): " SERVER_REMARK

# create log dir
mkdir -p "$LOG_DIR"
chown root:root "$LOG_DIR"
chmod 755 "$LOG_DIR"

# write worker script
cat > "$WORKER" <<EOF
#!/usr/bin/env bash
# xrestart-worker.sh - called by systemd (oneshot) and can be run manually.
set -euo pipefail

LOG_DIR="$LOG_DIR"
LOGFILE="\${LOG_DIR}/xrestart.log"

TG_TOKEN="${TG_TOKEN}"
TG_CHAT="${TG_CHAT}"
SERVER_REMARK="${SERVER_REMARK}"

TIMESTAMP(){ date -u +"%Y-%m-%dT%H:%M:%SZ"; }

log(){
  mkdir -p "\$LOG_DIR"
  echo "\$(TIMESTAMP) \$*" | tee -a "\$LOGFILE"
}

send_tg(){
  local text="\$1"
  if [ -z "\$TG_TOKEN" ] || [ -z "\$TG_CHAT" ]; then
    log "Telegram not configured; skipping notification."
    return 0
  fi

  # Escape backslashes and double quotes for JSON
  local esc
  esc=\$(printf '%s' "\$text" | sed 's/\\\\/\\\\\\\\/g; s/"/\\"/g')

  curl -s -m 10 -X POST "https://api.telegram.org/bot\${TG_TOKEN}/sendMessage" \\
    -H "Content-Type: application/json" \\
    -d "{\\"chat_id\\":\\"\${TG_CHAT}\\",\\"text\\":\\"\${esc}\\",\\"parse_mode\\":\\"Markdown\\"}" \\
    >/dev/null 2>&1 || {
      log "Telegram send failed; retrying once..."
      sleep 2
      curl -s -m 10 -X POST "https://api.telegram.org/bot\${TG_TOKEN}/sendMessage" \\
        -H "Content-Type: application/json" \\
        -d "{\\"chat_id\\":\\"\${TG_CHAT}\\",\\"text\\":\\"\${esc}\\",\\"parse_mode\\":\\"Markdown\\"}" \\
        >/dev/null 2>&1 || log "Telegram send failed again."
    }
}

restart_via_xui(){
  log "Attempting 'x-ui restart' command..."
  if command -v x-ui >/dev/null 2>&1; then
    if x-ui restart >/dev/null 2>&1; then
      log "'x-ui restart' succeeded."
      return 0
    else
      log "'x-ui restart' failed."
      return 1
    fi
  else
    log "x-ui command not found."
    return 1
  fi
}

restart_fallback_services(){
  log "Attempting to restart common system services (xray, xray.service, xray-core, xray@)..."
  local services=(xray xray.service xray-core xray@)
  for s in "\${services[@]}"; do
    if systemctl restart "\$s" 2>/dev/null; then
      log "Restarted system service \$s"
      send_tg "🔁 *xrestart:* restarted system service '\$s' on *\${SERVER_REMARK}* at \$(TIMESTAMP)"
      return 0
    fi
  done
  return 1
}

main(){
  log "=== xrestart: starting restart sequence (server: \$SERVER_REMARK) ==="

  if restart_via_xui; then
    send_tg "🔁 *xrestart:* successful restart via x-ui command on *\${SERVER_REMARK}* at \$(TIMESTAMP)"
    log "Restart sequence finished (x-ui success)."
    exit 0
  fi

  log "x-ui restart failed. Trying systemd fallback..."
  if restart_fallback_services; then
    log "Restart sequence finished (systemd fallback success)."
    exit 0
  fi

  log "All restart attempts failed."
  send_tg "⚠️ *xrestart:* FAILED to restart on *\${SERVER_REMARK}* at \$(TIMESTAMP). Check server logs."
  exit 2
}

mode="\${1:-}"

if [ "\$mode" = "test" ]; then
  log "Running in TEST mode: sending Telegram test message and trying x-ui restart."
  send_tg "🧪 *xrestart test:* server *\${SERVER_REMARK}* at \$(TIMESTAMP)"
  if command -v x-ui >/dev/null 2>&1; then
    if x-ui restart >/dev/null 2>&1; then
      log "x-ui restart (test) executed successfully."
    else
      log "x-ui restart (test) failed."
    fi
  else
    log "x-ui command not found (test)."
  fi
  exit 0
fi

main
EOF

chmod +x "$WORKER"
info "Worker written to $WORKER"

# create systemd service (oneshot)
cat > "$SERVICE" <<EOF
[Unit]
Description=xrestart worker - restart x-ui/xray and notify Telegram
After=network.target

[Service]
Type=oneshot
ExecStart=$WORKER
User=root
WorkingDirectory=/
TimeoutStartSec=120
StandardOutput=append:$LOG_DIR/xrestart.service.log
StandardError=append:$LOG_DIR/xrestart.service.err
EOF

# create systemd timer (every 60 minutes)
cat > "$TIMER" <<EOF
[Unit]
Description=Run xrestart worker every 60 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=60min
Persistent=true

[Install]
WantedBy=timers.target
EOF

# reload systemd and enable timer
systemctl daemon-reload
systemctl enable --now xrestart.timer
systemctl start xrestart.timer || true

info "Installation complete."
info "Worker: $WORKER"
info "Service: $SERVICE"
info "Timer: $TIMER (fires every 60 minutes)"
info "Logs: $LOG_DIR/*.log"
info "To run a test now: sudo $WORKER test"
info "To run immediately: sudo systemctl start xrestart.service"
info "To run Uninstall immediately: bash <(curl -fsSL https://raw.githubusercontent.com/MasterHide/A-M-S/main/restart/uninstallx.sh)"
