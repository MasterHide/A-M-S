#!/bin/bash
# Traffic Log Auto Management Script
# Safe, tested version with automatic cleanup before reinstall

LOGFILE="/var/log/3xipl-ap.log"
LOGROTATE="/var/log/3xipl-ap-rotate.log"
SIZE_LIMIT=$((1024*1024*1024))  # 1 GB

# Safety check
if [ ! -f "$LOGFILE" ]; then
  echo "⚠️  Log file not found: $LOGFILE"
  echo "Please make sure your service is running and generating logs first."
  exit 1
fi

# ✅ Ensure correct permissions
if [ ! -w "$LOGFILE" ]; then
  echo "🔧 Adjusting permissions for $LOGFILE..."
  sudo chown root:adm "$LOGFILE" 2>/dev/null || true
  sudo chmod 664 "$LOGFILE" 2>/dev/null || true
fi

if [ ! -w "$LOGROTATE" ]; then
  sudo touch "$LOGROTATE"
  sudo chown root:adm "$LOGROTATE" 2>/dev/null || true
  sudo chmod 664 "$LOGROTATE" 2>/dev/null || true
fi

# Helper for logging actions
log_action() {
  echo "$(date '+%F %T') - $1" | tee -a "$LOGROTATE"
}

# 🧹 Cleanup old setup before re-install
cleanup_old() {
  log_action "🧹 Cleaning old log rotation setup..."
  # Remove old scripts
  sudo rm -f /usr/local/bin/clear_3xipl_log_size.sh /usr/local/bin/clear_3xipl_log_daily.sh

  # Remove old cron entries
  local tmpfile
  tmpfile=$(mktemp)
  sudo crontab -l 2>/dev/null | grep -v 'clear_3xipl_log' > "$tmpfile"
  sudo crontab "$tmpfile"
  rm -f "$tmpfile"

  log_action "✅ Old setup removed successfully."
}

# Create the size-based cleaner
create_size_cleaner() {
cat <<'EOF' | sudo tee /usr/local/bin/clear_3xipl_log_size.sh >/dev/null
#!/bin/bash
LOGFILE="/var/log/3xipl-ap.log"
LOGROTATE="/var/log/3xipl-ap-rotate.log"
MAXSIZE=$((1024*1024*1024))

if [ -f "$LOGFILE" ]; then
  FILESIZE=$(stat -c%s "$LOGFILE")
  if [ "$FILESIZE" -ge "$MAXSIZE" ]; then
    echo "$(date '+%F %T') - Log exceeded 1GB, clearing..." >> "$LOGROTATE"
    truncate -s 0 "$LOGFILE"
  fi
fi
EOF
chmod +x /usr/local/bin/clear_3xipl_log_size.sh
log_action "✅ Created size-based cleaner script."
}

# Create the daily cleaner
create_daily_cleaner() {
cat <<'EOF' | sudo tee /usr/local/bin/clear_3xipl_log_daily.sh >/dev/null
#!/bin/bash
LOGFILE="/var/log/3xipl-ap.log"
LOGROTATE="/var/log/3xipl-ap-rotate.log"
if [ -f "$LOGFILE" ]; then
  echo "$(date '+%F %T') - Daily log reset triggered." >> "$LOGROTATE"
  truncate -s 0 "$LOGFILE"
fi
EOF
chmod +x /usr/local/bin/clear_3xipl_log_daily.sh
log_action "✅ Created daily cleaner script."
}

# ✅ Improved Cron setup (prevents duplicates)
setup_cron() {
  local job="$1"
  local tmpfile
  tmpfile=$(mktemp)
  sudo crontab -l 2>/dev/null | grep -v -F "$job" | grep -v 'clear_3xipl_log' > "$tmpfile"
  echo "$job" >> "$tmpfile"
  sudo crontab "$tmpfile"
  rm -f "$tmpfile"
  log_action "✅ Added cron job: $job"
}

# Start clean
cleanup_old

# Menu
clear
echo "──────────────────────────────────────────────"
echo "     ⚙️  Traffic Log Auto-Management Setup"
echo "──────────────────────────────────────────────"
echo "Choose how you want to control /var/log/3xipl-ap.log:"
echo
echo "1️⃣  Auto-clear when log size ≥ 1 GB every 10 minutes"
echo "2️⃣  Auto-clear every 24 hours (midnight)"
echo "3️⃣  Combine both methods (recommended)"
echo "4️⃣  Cancel setup"
echo "──────────────────────────────────────────────"
read -rp "Enter your choice [1-4]: " choice

case "$choice" in
  1)
    create_size_cleaner
    setup_cron "*/10 * * * * /usr/local/bin/clear_3xipl_log_size.sh"
    ;;
  2)
    create_daily_cleaner
    setup_cron "0 0 * * * /usr/local/bin/clear_3xipl_log_daily.sh"
    ;;
  3)
    create_size_cleaner
    create_daily_cleaner
    setup_cron "*/10 * * * * /usr/local/bin/clear_3xipl_log_size.sh"
    setup_cron "0 0 * * * /usr/local/bin/clear_3xipl_log_daily.sh"
    ;;
  4)
    echo "❌ Setup cancelled."
    exit 0
    ;;
  *)
    echo "❌ Invalid input. Exiting."
    exit 1
    ;;
esac

echo
echo "──────────────────────────────────────────────"
echo "✅ Setup complete! Old setup removed, new one installed safely."
echo "Actions are logged in: $LOGROTATE"
echo "──────────────────────────────────────────────"
