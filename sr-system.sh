#!/bin/bash
set -e  # Exit script if any command fails

# Function to send Telegram notification
send_telegram() {
    local message="$1"
    local bot_token="YOUR_BOT_TOKEN"
    local chat_id="YOUR_CHAT_ID"

    curl -s -X POST "https://api.telegram.org/bot$bot_token/sendMessage" -d "chat_id=$chat_id&text=$message"
}

# Remove old bot token and chat ID files if they exist
if [ -f "/etc/vps_bot_token.conf" ]; then
    sudo rm -f /etc/vps_bot_token.conf
    echo "Removed old bot token file."
fi

if [ -f "/etc/vps_chat_id.conf" ]; then
    sudo rm -f /etc/vps_chat_id.conf
    echo "Removed old chat ID file."
fi

# Remove existing cron job related to VPS reboot (if any)
# Better to search for the exact cron job pattern
(crontab -l 2>/dev/null | grep -v "Your VPS rebooted at" ) | sudo crontab -

echo "Removed any existing cron jobs related to VPS reboot."

# Ask the user if they want Telegram notifications
read -p "Do you want to receive Telegram notifications for reboots? (y/n): " notify

if [[ "$notify" == "y" ]]; then
    # Ask user for Telegram Bot Token and Chat ID
    read -p "Enter your Telegram Bot Token: " bot_token
    read -p "Enter your Telegram Chat ID: " chat_id

    # Save the bot token and chat ID to config files
    echo "$bot_token" | sudo tee /etc/vps_bot_token.conf > /dev/null
    echo "$chat_id" | sudo tee /etc/vps_chat_id.conf > /dev/null

    # Schedule the cron job with Telegram notification
    (sudo crontab -l 2>/dev/null; echo "30 21 * * * /bin/bash -c 'bot_token=\$(cat /etc/vps_bot_token.conf); chat_id=\$(cat /etc/vps_chat_id.conf); message=\"Your VPS rebooted at \$(date)\"; curl -s -X POST \"https://api.telegram.org/bot\$bot_token/sendMessage\" -d \"chat_id=\$chat_id&text=\$message\"; sudo reboot'") | sudo crontab -

    echo "✅ Reboot scheduled at 3 AM IST with Telegram notification."
else
    # Schedule the cron job without Telegram notification
    (sudo crontab -l 2>/dev/null; echo "30 21 * * * sudo reboot") | sudo crontab -

    echo "✅ Reboot scheduled at 3 AM IST without Telegram notification."
fi
