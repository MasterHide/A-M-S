# modules/xui-auto-restart.sh

setup_restart_cron() {
    local script_path="$HOME/ams-scripts/restart-xui.sh"

    # Create restart script
    cat > "$script_path" << EOL
#!/bin/bash
export TZ='Asia/Tehran'
x-ui restart
echo "x-ui restarted at \$(date)" >> /var/log/x-ui-restart.log
EOL

    chmod +x "$script_path"

    # Add cron job (if not already added)
    (crontab -l 2>/dev/null | grep -v "$script_path") | crontab -
    (crontab -l 2>/dev/null; echo "TZ=Asia/Tehran") | crontab -
    (crontab -l 2>/dev/null; echo "0 * * * * $script_path") | crontab -

    log_success "Hourly x-ui restart scheduled (Tehran time)."
}

remove_restart_cron() {
    local script_path="$HOME/ams-scripts/restart-xui.sh"

    # Remove cron entries
    (crontab -l 2>/dev/null | grep -v "$script_path") | crontab -
    log_success "Auto-restart removed."
}

check_logs() {
    if [ -f "/var/log/x-ui-restart.log" ]; then
        tail -n 20 /var/log/x-ui-restart.log
    else
        log_warn "No restart logs found yet."
    fi
}
