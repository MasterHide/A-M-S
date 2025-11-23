#!/usr/bin/env bash
# uninstallx.sh - removes xrestart installation
set -euo pipefail

WORKER="/usr/local/bin/xrestart-worker.sh"
SERVICE="/etc/systemd/system/xrestart.service"
TIMER="/etc/systemd/system/xrestart.timer"
LOG_DIR="/var/log/xrestart"

if [ "$EUID" -ne 0 ]; then
  echo "Run as root (sudo)."
  exit 1
fi

echo "[INFO] Stopping services..."
systemctl stop xrestart.timer xrestart.service >/dev/null 2>&1 || true
systemctl disable xrestart.timer xrestart.service >/dev/null 2>&1 || true

echo "[INFO] Removing files..."
rm -f "$WORKER" "$SERVICE" "$TIMER"
rm -rf "$LOG_DIR"

systemctl daemon-reload
echo "[INFO] Uninstall complete."
