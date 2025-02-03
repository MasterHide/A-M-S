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

    # Ask for a custom remark (optional)
    read -p "Enter a remark for the reboot notification (or leave blank for no remark): " remark

    # Prepare the message with the custom remark (if any)
    if [ -n "$remark" ]; then
        message="Your VPS rebooted at $(date). Remark: $remark"
    else
        message="Your VPS rebooted at $(date)"
    fi

    # Schedule the cron job for Sri Lanka time zone (Asia/Colombo) at 3 AM
    (sudo crontab -l 2>/dev/null; echo "0 3 * * * TZ=Asia/Colombo /bin/bash -c 'bot_token=\$(cat /etc/vps_bot_token.conf); chat_id=\$(cat /etc/vps_chat_id.conf); message=\"$message\"; curl -s -X POST \"https://api.telegram.org/bot\$bot_token/sendMessage\" -d \"chat_id=\$chat_id&text=\$message\"; sudo reboot'") | sudo crontab -

    echo "✅ Reboot scheduled at 3 AM Sri Lanka time (Asia/Colombo) with Telegram notification."
else
    # Schedule the cron job without Telegram notification for Sri Lanka time zone (Asia/Colombo)
    (sudo crontab -l 2>/dev/null; echo "0 3 * * * TZ=Asia/Colombo sudo reboot") | sudo crontab -

    echo "✅ Reboot scheduled at 3 AM Sri Lanka time (Asia/Colombo) without Telegram notification."
fi
