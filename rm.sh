#!/bin/bash

# Function to remove reboot-related cron jobs
remove_cron_jobs() {
    echo "Removing any existing cron jobs related to reboot..."
    if crontab -l 2>/dev/null | grep -q "reboot"; then
        (crontab -l 2>/dev/null | grep -v "reboot") | crontab -
        echo "✅ Removed reboot-related cron jobs."
    else
        echo "ℹ️ No reboot-related cron jobs found."
    fi
}

# Function to remove specific files
remove_files() {
    echo "Cleaning up old files..."

    # List of files to remove
    files_to_remove=(
        "/root/sr-system.sh"
        "/home/ubuntu/sr-system.sh"
        "/opt/sr-system.sh"
        "/opt/hiddify-manager/sr-system.sh"
        "/root/rm.sh"
        "/home/ubuntu/rm.sh"
        "/opt/rm.sh"
        "/opt/hiddify-manager/rm.sh"
    )

    # Loop through the list and remove each file if it exists
    for file in "${files_to_remove[@]}"; do
        if [ -f "$file" ]; then
            if sudo rm -f "$file"; then
                echo "✅ Removed: $file"
            else
                echo "❌ Failed to remove: $file (Permission denied?)"
            fi
        else
            echo "ℹ️ File not found, skipping: $file"
        fi
    done

    echo "Cleanup complete."
}

# Main script execution starts here
echo "Starting cleanup process..."

# Step 1: Remove reboot-related cron jobs
remove_cron_jobs

# Step 2: Remove old files
remove_files

echo "✅ All cleanup tasks completed."
