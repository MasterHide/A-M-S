# Remove the cron job related to reboot
(crontab -l | grep -v "reboot") | crontab -

# Remove the sr-system.sh file from multiple paths
rm -f /root/sr-system.sh
rm -f /home/ubuntu/sr-system.sh
rm -f /opt/sr-system.sh

echo "Removed the sr-system.sh file from /root, /home/ubuntu, and /opt."
