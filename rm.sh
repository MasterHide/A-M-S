#!/bin/bash

# ======================================
# Safe Cleanup Script (auto search mode)
# Version: 2.0 - 2025-10
# ======================================

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

# Function to search and remove matching files
remove_files() {
    echo "Cleaning up old and matching files..."

    # Fixed known file paths
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

    # Remove fixed files
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

    # Auto-detect and remove all scripts like ams-install.sh, rm.sh, sr-system.sh, etc.
    echo "🔍 Scanning for leftover uninstall or setup scripts..."
    find /root /home /opt /etc /usr/local -type f \
        \( -name "ams-install.sh" -o -name "sr-system.sh" -o -name "rm.sh" -o -name "cleanup.sh" -o -name "remove.sh" \) \
        2>/dev/null | while read -r file; do
            if sudo rm -f "$file"; then
                echo "✅ Auto-removed: $file"
            else
                echo "❌ Could not remove: $file"
            fi
        done

    echo "Cleanup complete."
}

# Main script
echo "Starting cleanup process..."
remove_cron_jobs
remove_files
echo "✅ All cleanup tasks completed."
