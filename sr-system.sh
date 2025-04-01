#!/bin/bash
set -e  # Exit script if any command fails

# Function to send Telegram notification
send_telegram() {
    local message="$1"
    local bot_token=$(sudo cat /etc/vps_bot_token.conf)  # Read token from file
    local chat_id=$(sudo cat /etc/vps_chat_id.conf)  # Read chat_id from file

    echo "Sending Telegram message: $message"
    response=$(curl -s -w "%{http_code}" -o /dev/null --connect-timeout 10 -X POST "https://api.telegram.org/bot$bot_token/sendMessage" -d "chat_id=$chat_id&text=$message")

    if [ "$response" -eq 200 ]; then
        echo "✅ Message sent successfully!"
    else
        echo "❌ Failed to send message. Response code: $response"
        exit 3
    fi
}

# Function to remove old bot token, chat ID files, and clear old cron jobs related to reboot
remove_old_files_and_jobs() {
    echo "Cleaning up old files and cron jobs..."

    # Remove bot token and chat ID files if they exist
    for file in /etc/vps_bot_token.conf /etc/vps_chat_id.conf; do
        if [ -f "$file" ]; then
            sudo rm -f "$file"
            echo "Removed old file: $file"
        fi
    done

    # Remove cron jobs related to reboot (if any)
    echo "Removing any existing cron jobs related to VPS reboot..."
    (crontab -l 2>/dev/null | grep -v 'sudo reboot') | sudo crontab -
    echo "Removed any existing cron jobs related to VPS reboot."
}

# Function to set the server's timezone
set_timezone() {
    local timezone="$1"
    echo "Setting server timezone to $timezone..."

    if timedatectl set-timezone "$timezone"; then
        echo "✅ Timezone set to $timezone"
    else
        echo "❌ Failed to set timezone"
        exit 4
    fi
}

# Verify the timezone after reboot
verify_timezone() {
    local expected_timezone="$1"
    echo "Verifying timezone..."

    # Check current timezone
    current_timezone=$(timedatectl | grep "Time zone" | awk '{print $3}')
    if [[ "$current_timezone" != "$expected_timezone" ]]; then
        echo "❌ Timezone mismatch! Expected: $expected_timezone, but found: $current_timezone"
        echo "Reapplying timezone..."
        set_timezone "$expected_timezone"
    else
        echo "✅ Timezone verified: $expected_timezone"
    fi
}

# Function to set cron job
set_cron_job() {
    local timezone="$1"
    local message="$2"
    local bot_token="$3"
    local chat_id="$4"

    echo "Scheduling reboot task in cron..."

    if [[ "$timezone" == "Asia/Colombo" ]]; then
        # Schedule for Sri Lanka time (3 AM Sri Lanka time)
        (sudo crontab -l 2>/dev/null; echo "0 3 * * * TZ=Asia/Colombo /bin/bash -c 'bot_token=\$(sudo cat /etc/vps_bot_token.conf); chat_id=\$(sudo cat /etc/vps_chat_id.conf); message=\"$message\"; curl -s -X POST \"https://api.telegram.org/bot\$bot_token/sendMessage\" -d \"chat_id=\$chat_id&text=\$message\"; sudo reboot'") | sudo crontab -
        echo "✅ Reboot scheduled at 3 AM Sri Lanka time with Telegram notification."
    elif [[ "$timezone" == "Asia/Tehran" ]]; then
        # Schedule for Tehran time (3 AM Tehran time)
        (sudo crontab -l 2>/dev/null; echo "0 3 * * * TZ=Asia/Tehran /bin/bash -c 'bot_token=\$(sudo cat /etc/vps_bot_token.conf); chat_id=\$(sudo cat /etc/vps_chat_id.conf); message=\"$message\"; curl -s -X POST \"https://api.telegram.org/bot\$bot_token/sendMessage\" -d \"chat_id=\$chat_id&text=\$message\"; sudo reboot'") | sudo crontab -
        echo "✅ Reboot scheduled at 3 AM Tehran time with Telegram notification."
    else
        echo "❌ Unsupported timezone selected."
        exit 5
    fi
}

# Main script execution starts here
echo "Welcome to the VPS Reboot Scheduler!"

# Clean up old files and cron jobs
remove_old_files_and_jobs

# Menu for selecting timezone
echo "Choose your preferred timezone for reboot scheduling:"
echo "1. Sri Lanka (Asia/Colombo)"
echo "2. Tehran (Asia/Tehran)"
read -p "Enter the number of your choice (1/2): " choice

# Validate user input for timezone selection
if [[ "$choice" == "1" ]]; then
    timezone="Asia/Colombo"
elif [[ "$choice" == "2" ]]; then
    timezone="Asia/Tehran"
else
    echo "❌ Invalid choice. Exiting."
    exit 6
fi

# Set the server's timezone
set_timezone "$timezone"

# Verify the timezone
verify_timezone "$timezone"

# Ask the user if they want Telegram notifications
read -p "Do you want to receive Telegram notifications for reboots? (y/n): " notify

if [[ "$notify" == "y" ]]; then
    # Ask user for Telegram Bot Token and Chat ID
    read -p "Enter your Telegram Bot Token: " bot_token
    read -p "Enter your Telegram Chat ID: " chat_id

    # Validate inputs
    if [[ -z "$bot_token" || -z "$chat_id" ]]; then
        echo "❌ Invalid Bot Token or Chat ID. Exiting."
        exit 7
    fi

    # Save the bot token and chat ID to config files with secure permissions
    echo "$bot_token" | sudo tee /etc/vps_bot_token.conf > /dev/null
    echo "$chat_id" | sudo tee /etc/vps_chat_id.conf > /dev/null
    sudo chmod 600 /etc/vps_bot_token.conf /etc/vps_chat_id.conf
    sudo chown root:root /etc/vps_bot_token.conf /etc/vps_chat_id.conf

    # Ask for a custom remark (optional)
    read -p "Enter a remark for the reboot notification (or leave blank for no remark): " remark

    # Prepare the message with the custom remark (if any)
    if [ -n "$remark" ]; then
        message="Your VPS rebooted at $(date). Remark: $remark"
    else
        message="Your VPS rebooted at $(date)"
    fi

    # Send the first message to confirm Telegram notification setup
    send_telegram "$message"
    echo "✅ Initial test message sent to Telegram!"

    # Set the cron job based on the selected timezone
    set_cron_job "$timezone" "$message" "$bot_token" "$chat_id"
else
    # Schedule the cron job without Telegram notification
    if [[ "$timezone" == "Asia/Colombo" ]]; then
        (sudo crontab -l 2>/dev/null; echo "0 3 * * * TZ=Asia/Colombo sudo reboot") | sudo crontab -
        echo "✅ Reboot scheduled at 3 AM Sri Lanka time without Telegram notification."
    elif [[ "$timezone" == "Asia/Tehran" ]]; then
        (sudo crontab -l 2>/dev/null; echo "0 3 * * * TZ=Asia/Tehran sudo reboot") | sudo crontab -
        echo "✅ Reboot scheduled at 3 AM Tehran time without Telegram notification."
    fi
fi

# Ask user if they want to test the reboot immediately
read -p "Do you want to test the reboot immediately and send another Telegram message? (y/n): " test_reboot
if [[ "$test_reboot" == "y" ]]; then
    # Send a final Telegram message confirming reboot test
    message="Test: Your VPS will now reboot, and this is the final confirmation message."
    send_telegram "$message"
    echo "✅ Test message sent before reboot."

    # Reboot the system
    echo "Rebooting the system in 5 seconds..."
    sleep 5
    sudo reboot
else
    echo "No reboot initiated. Cron job will handle the next scheduled reboot."
fi
