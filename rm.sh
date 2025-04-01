# Remove the cron job related to reboot
echo "Removing any existing cron jobs related to reboot..."
(crontab -l 2>/dev/null | grep -v "reboot") | crontab -
echo "Removed any existing cron jobs related to reboot."

# Remove specific files from multiple paths
echo "Cleaning up old files..."

# Define the list of files to remove
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
        sudo rm -f "$file"
        echo "Removed: $file"
    else
        echo "File not found, skipping: $file"
    fi
done

echo "Cleanup complete."
