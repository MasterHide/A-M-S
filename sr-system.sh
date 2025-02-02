#!/bin/bash
set -e  # Exit script if any command fails

# Function to send email notification
send_email() {
    local email="$1"
    local subject="VPS Reboot Notification"
    local body="Your VPS was rebooted at $(date)."

    echo "$body" | mail -s "$subject" "$email"
}

# Ask the user if they want email notifications
read -p "Do you want to receive email notifications for reboots? (y/n): " notify

if [[ "$notify" == "y" ]]; then
    read -p "Enter your email: " user_email

    # Save the email in a config file
    echo "$user_email" | sudo tee /etc/vps_email.conf > /dev/null

    # Schedule the cron job with email notification
    (sudo crontab -l 2>/dev/null; echo "30 21 * * * email=\$(cat /etc/vps_email.conf); echo 'Your VPS rebooted at \$(date)' | mail -s 'VPS Reboot Notification' \"\$email\"; sudo reboot") | sudo crontab -
    
    echo "✅ Reboot scheduled at 3 AM IST with email notification to $user_email."
else
    # Schedule the cron job without email notification
    (sudo crontab -l 2>/dev/null; echo "30 21 * * * sudo reboot") | sudo crontab -

    echo "✅ Reboot scheduled at 3 AM IST without email notification."
fi
