#!/bin/bash
set -e  # Exit script if any command fails

# Function to send Telegram notification
send_telegram() {
    local message="$1"
    local bot_token=$(cat /etc/vps_bot_token.conf)  # Read token from file
    local chat_id=$(cat /etc/vps_chat_id.conf)  # Read chat_id from file
    response=$(curl -s -w "%{http_code}" -o /dev/null -X POST "https://api.telegram.org/bot$bot_token/sendMessage" -d "chat_id=$chat_id&text=$message")
    
    if [ "$response" -eq 200 ]; then
        echo "✅ Message sent successfully!"
    else
        echo "❌ Failed to send message. Response code: $response"
        exit 1
    fi
}

# Remove old bot token and chat ID files, and clear old cron jobs
remove_old_files_and_jobs() {
    # Remove bot token and chat ID files if they exist
    for file in /etc/vps_bot_token.conf /etc/vps_chat_id.conf; do
        if [ -f "$file" ]; then
            sudo rm -f "$file"
            echo "Removed old file: $file"
        fi
    done

    # Remove existing cron jobs related to VPS reboot (if any)
    # Remove cron jobs that mention "reboot" and "Your VPS rebooted at"
    (crontab -l 2>/dev/null | grep -v "Your VPS rebooted at" | grep -v "reboot") | sudo crontab -
    echo "Removed any existing cron jobs related to VPS reboot."
}

# Call the function to clean up
remove_old_files_and_jobs

# Function to set the server's timezone
set_timezone() {
    local timezone="$1"
    echo "Setting server timezone to $timezone..."
    sudo timedatectl set-timezone "$timezone" || { echo "❌ Failed to set timezone"; exit 1; }
}

# Function to check if a cron job already exists
check_existing_cron_job() {
    local timezone="$1"
    local message="$2"
    
    # Check if a cron job for reboot exists for the specified timezone
    if crontab -l 2>/dev/null | grep -q "TZ=$timezone.*reboot"; then
        echo "❌ Cron job for $timezone already exists."
        return 1
    fi
    return 0
}

# Function to set cron job
set_cron_job() {
    local timezone="$1"
    local message="$2"
    local bot_token="$3"
    local chat_id="$4"
    
    # Check if the cron job already exists
    if ! check_existing_cron_job "$timezone" "$message"; then
        echo "⚠️ Skipping duplicate cron job setup."
        return
    fi

    if [[ "$timezone" == "Asia/Colombo" ]]; then
        # Schedule for Sri Lanka time (3 AM Sri Lanka time)
        (sudo crontab -l 2>/dev/null; echo "0 3 * * * TZ=Asia/Colombo /bin/bash -c 'bot_token=\$(cat /etc/vps_bot_token.conf); chat_id=\$(cat /etc/vps_chat_id.conf); message=\"$message\"; curl -s -X POST \"https://api.telegram.org/bot\$bot_token/sendMessage\" -d \"chat_id=\$chat_id&text=\$message\"; sudo reboot'") | sudo crontab -
        echo "✅ Reboot scheduled at 3 AM Sri Lanka time with Telegram notification."
    elif [[ "$timezone" == "Asia/Tehran" ]]; then
        # Schedule for Tehran time (3 AM Tehran time)
        (sudo crontab -l 2>/dev/null; echo "0 3 * * * TZ=Asia/Tehran /bin/bash -c 'bot_token=\$(cat /etc/vps_bot_token.conf); chat_id=\$(cat /etc/vps_chat_id.conf); message=\"$message\"; curl -s -X POST \"https://api.telegram.org/bot\$bot_token/sendMessage\" -d \"chat_id=\$chat_id&text=\$message\"; sudo reboot'") | sudo crontab -
        echo "✅ Reboot scheduled at 3 AM Tehran time with Telegram notification."
    else
        echo "❌ Unsupported timezone selected."
        exit 1
    fi
}

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
    exit 1
fi

# Set the server's timezone
set_timezone "$timezone"

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
