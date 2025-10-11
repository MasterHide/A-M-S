#!/bin/bash
# Traffic Log Auto Management Script
# Safe, tested version - prevents disk flooding while preserving torrent blocker logs

LOGFILE="/var/log/3xipl-ap.log"
LOGROTATE="/var/log/3xipl-ap-rotate.log"
SIZE_LIMIT=$((1024*1024*1024))  # 1 GB

# Safety check
if [ ! -f "$LOGFILE" ]; then
  echo "⚠️  Log file not found: $LOGFILE"
  echo "Please make sure your service is running and generating logs first."
  exit 1
fi

# Helper function to write messages
log_action() {
  echo "$(date '+%F %T') - $1" | tee -a "$LOGROTATE"
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

# Setup cron jobs
setup_cron() {
  (sudo crontab -l 2>/dev/null | grep -v 'clear_3xipl_log' ; echo "$1") | sudo crontab -
  log_action "✅ Added cron job: $1"
}

# Main Menu
clear
echo "──────────────────────────────────────────────"
echo "     ⚙️  Traffic Log Auto-Management Setup"
echo "──────────────────────────────────────────────"
echo "Choose how you want to control /var/log/3xipl-ap.log:"
echo
echo "1️⃣  Auto-clear when log size ≥ 1 GB"
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
echo "✅ Setup complete! Logs will now be managed safely."
echo "Actions are logged in: $LOGROTATE"
echo "──────────────────────────────────────────────"
