#!/bin/bash
set -e
BOT_DIR="/opt/A-M-S"
SERVICE_FILE="/etc/systemd/system/xui-tg-bot.service"
CONFIG_FILE="$BOT_DIR/config/config.json"
PYTHON=$(command -v python3 || echo "/usr/bin/python3")

if systemctl is-active --quiet xui-tg-bot; then
  echo "⚠️ Service already running. Stop or uninstall first."
  exit 1
fi

mkdir -p "$BOT_DIR/config"

# Download latest files directly from GitHub
echo "📥 Downloading bot files from GitHub..."
rm -rf "$BOT_DIR"
mkdir -p "$BOT_DIR"
curl -L https://github.com/MasterHide/A-M-S/archive/refs/heads/main.zip -o /tmp/A-M-S.zip
apt install -y unzip >/dev/null 2>&1
unzip -q /tmp/A-M-S.zip -d /tmp
mv /tmp/xui-tg-bot-main/* "$BOT_DIR"/
rm -rf /tmp/A-M-S.zip /tmp/A-M-S-main

echo "🔹 Enter Telegram Bot Token:"
read -p "> " TOKEN
echo "🔹 Enter Admin ID:"
read -p "> " ADMIN_ID

cat <<EOF > "$CONFIG_FILE"
{
  "telegram_token": "$TOKEN",
  "admin_ids": [$ADMIN_ID],
  "db_path": "/etc/x-ui/x-ui.db",
  "log_path": "/var/log/A-M-S.log"
}
EOF

# ===========================
# INSTALL SYSTEM DEPENDENCIES
# ===========================
echo "📦 Installing system packages..."
apt update -y >/dev/null
apt install -y python3 python3-pip jq sqlite3 whiptail >/dev/null


# ===========================
# INSTALL PYTHON DEPENDENCIES
# ===========================
echo "📦 Installing Python dependencies..."
if [ -f "$BOT_DIR/install/requirements.txt" ]; then
    pip3 install -r "$BOT_DIR/install/requirements.txt" >/dev/null
else
    echo "⚠️ requirements.txt not found, installing minimal set..."
    pip3 install aiogram apscheduler psutil >/dev/null
fi
echo "✅ Python dependencies installed successfully."


cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=XUI Telegram Bot
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/A-M-S
ExecStart=/usr/bin/python3 /opt/A-M-S/bot/xui_bot.py
Restart=always
RestartSec=5
User=root
StandardOutput=append:/var/log/A-M-S.log
StandardError=append:/var/log/A-M-S.log

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now xui-tg-bot
echo "✅ Installation complete. Bot is running!"
