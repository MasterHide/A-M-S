#!/bin/bash
set -e  # Exit the script if any command fails

echo "Updating package list and upgrading packages..."
sudo apt update && sudo apt upgrade -y

echo "Installing necessary packages..."
sudo apt install -y curl

echo "Downloading and running sr-system.sh..."
curl -O https://raw.githubusercontent.com/MasterHide/A-M-S/main/sr-system.sh
chmod +x sr-system.sh
sudo ./sr-system.sh

echo "Installation and execution complete!"
