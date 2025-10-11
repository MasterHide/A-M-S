#!/bin/bash
# Traffic Log Auto-Management Uninstaller (Safe Version)

LOGROTATE="/var/log/3xipl-ap-rotate.log"

log_action() {
  echo "$(date '+%F %T') - $1" | tee -a "$LOGROTATE"
}

echo "──────────────────────────────────────────────"
echo "🧹  Uninstalling Traffic Log Auto-Management Setup"
echo "──────────────────────────────────────────────"

# Confirm
read -rp "Are you sure you want to remove the auto log management setup? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "❌ Uninstall cancelled."
  exit 0
fi

# Remove cron jobs
log_action "🧹 Removing old cron entries..."
tmpfile=$(mktemp)
sudo crontab -l 2>/dev/null | grep -v 'clear_3xipl_log' > "$tmpfile"
sudo crontab "$tmpfile"
rm -f "$tmpfile"
log_action "✅ Cron jobs removed."

# Remove cleanup scripts
log_action "🧹 Removing cleaner scripts..."
sudo rm -f /usr/local/bin/clear_3xipl_log_size.sh /usr/local/bin/clear_3xipl_log_daily.sh
log_action "✅ Cleaner scripts removed."

# Optionally remove rotate log (ask user)
read -rp "Do you also want to remove $LOGROTATE ? (y/N): " remove_log
if [[ "$remove_log" =~ ^[Yy]$ ]]; then
  sudo rm -f "$LOGROTATE"
  echo "🗑️  $LOGROTATE deleted."
else
  echo "ℹ️  $LOGROTATE preserved."
fi

echo
echo "──────────────────────────────────────────────"
echo "✅ Uninstallation complete!"
echo "All Traffic Log Auto-Management files and cron jobs are removed."
echo "──────────────────────────────────────────────"
