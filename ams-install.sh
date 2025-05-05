#!/bin/bash

# ======================
#   COLOR DEFINITIONS
# ======================
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ======================
#   UTILITY FUNCTIONS
# ======================
log_info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

log_success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# ======================
#   MAIN BANNER
# ======================
show_main_banner() {
    printf "\033c"
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}=                                       =${NC}"
    echo -e "${GREEN}=     🚀  POWER UP WITH A-M-S TOOL      =${NC}"
    echo -e "${GREEN}=                                       =${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo
    echo -e " ${YELLOW}1.${NC} Install AMS Tools"
    echo -e " ${YELLOW}2.${NC} Auto Restart X-UI Tool"
    echo -e " ${YELLOW}3.${NC} Update Telegram Settings"
    echo -e " ${YELLOW}4.${NC} Send Test Telegram Message"
    echo -e " ${YELLOW}0.${NC} Exit"
    echo
}

# ======================
#   OPTION 1: INSTALL AMS TOOL
# ======================
install_ams_tool() {
    log_info "Installing AMS tool..."
    cd /root || { log_error "Failed to enter /root directory"; return 1; }
    curl -O https://raw.githubusercontent.com/MasterHide/A-M-S/main/sr-system.sh
    if [ $? -ne 0 ]; then
        log_error "Failed to download sr-system.sh"
        return 1
    fi
    chmod +x sr-system.sh
    sudo ./sr-system.sh
    if [ $? -eq 0 ]; then
        log_success "AMS Tool installed successfully!"
    else
        log_error "AMS Tool install failed."
    fi
}

# ======================
#   PATHS & CONFIG
# ======================
SCRIPT_PATH="$HOME/ams-scripts/restart-xui.sh"
TELEGRAM_CONF="$HOME/ams-scripts/telegram.conf"
REBOOT_ALERT_SCRIPT="$HOME/ams-scripts/reboot-alert.sh"

# Load existing Telegram config if it exists
if [ -f "$TELEGRAM_CONF" ]; then
    source "$TELEGRAM_CONF"
fi

# ======================
#   CLEANUP OLD CRON
# ======================
cleanup_old_cron() {
    if [ -f "$SCRIPT_PATH" ]; then
        (crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH" | grep -v "TZ=Asia/Tehran") | crontab -
        rm -f "$SCRIPT_PATH"
    fi
}

# ======================
#   SETUP TELEGRAM ALERTS
# ======================
setup_telegram_alert() {
    log_info "Enter Telegram Bot Token:"
    read -r new_token
    log_info "Enter Telegram Chat ID:"
    read -r new_chatid
    log_info "Enter Server Remark (for identification):"
    read -r new_remark
    mkdir -p "$HOME/ams-scripts"
    cat > "$TELEGRAM_CONF" << EOL
BOT_TOKEN="$new_token"
CHAT_ID="$new_chatid"
SERVER_REMARK="$new_remark"
EOL
    chmod 600 "$TELEGRAM_CONF"
    log_success "Telegram settings saved!"
    log_info "Server remark: '$new_remark'"
}

# ======================
#   SEND REBOOT ALERT SCRIPT
# ======================
setup_reboot_alert_script() {
    cat > "$REBOOT_ALERT_SCRIPT" << EOL
#!/bin/bash

source "$TELEGRAM_CONF" 2>/dev/null

if [ -z "\$BOT_TOKEN" ] || [ -z "\$CHAT_ID" ]; then
    exit 0
fi

TEXT="⚠️ Server Reboot Detected"
TEXT+="\\n\\nRemark: \$SERVER_REMARK"
TEXT+="\\nHostname: \$(hostname)"
TEXT+="\\nIP: \$(hostname -I)"
TEXT+="\\nTime: \$(date)"

curl -s -X POST "https://api.telegram.org/bot\$BOT_TOKEN/sendMessage" \\
    -d "chat_id=\$CHAT_ID" \\
    -d "text=\$TEXT" \\
    -d "parse_mode=markdown" > /dev/null 2>&1
EOL
    chmod +x "$REBOOT_ALERT_SCRIPT"
    (crontab -l 2>/dev/null | grep -v "@reboot $REBOOT_ALERT_SCRIPT") | crontab -
    (crontab -l 2>/dev/null; echo "@reboot $REBOOT_ALERT_SCRIPT") | crontab -
}

# ======================
#   SEND TEST MESSAGE
# ======================
send_telegram_test_message() {
    if [ ! -f "$TELEGRAM_CONF" ]; then
        log_error "Telegram not configured yet."
        return 1
    fi

    source "$TELEGRAM_CONF"

    if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
        log_error "Bot token or Chat ID is missing. Please configure first."
        return 1
    fi

    TEXT="📬 AMS Tool - Test Message"
    TEXT+="\n\nThis is a test alert from:"
    TEXT+="\nServer: $SERVER_REMARK"
    TEXT+="\nHostname: $(hostname)"
    TEXT+="\nIP Address: $(hostname -I)"
    TEXT+="\nTime: $(date)"

    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d "chat_id=$CHAT_ID" \
        -d "text=$TEXT" \
        -d "parse_mode=markdown" > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        log_success "Test message sent successfully!"
    else
        log_error "Failed to send test message. Check bot token/chat ID."
    fi
}

# ======================
#   SUBMENU FOR X-UI AUTO RESTART
# ======================
setup_restart_cron() {
    log_info "Setting up Telegram Alerts..."

    read -r -p "Enter Telegram Bot Token: " BOT_TOKEN
    read -r -p "Enter Telegram Chat ID: " CHAT_ID
    read -r -p "Enter Server Remark (e.g., MyMainServer): " SERVER_REMARK

    mkdir -p "$HOME/ams-scripts"

    cat > "$TELEGRAM_CONF" << EOL
BOT_TOKEN="$BOT_TOKEN"
CHAT_ID="$CHAT_ID"
SERVER_REMARK="$SERVER_REMARK"
EOL

    chmod 600 "$TELEGRAM_CONF"
    log_success "Telegram settings saved."

    cleanup_old_cron

    cat > "$SCRIPT_PATH" << EOL
#!/bin/bash
export TZ='Asia/Tehran'
x-ui restart
echo "x-ui restarted at \$(date)" >> /var/log/x-ui-restart.log
EOL

    chmod +x "$SCRIPT_PATH"

    (crontab -l 2>/dev/null; echo "TZ=Asia/Tehran") | crontab -
    (crontab -l 2>/dev/null; echo "0 * * * * $SCRIPT_PATH") | crontab -

    log_success "Auto Restart installed successfully!"
    log_info "x-ui will restart every hour (Tehran time)."

    # Post-install alert
    cat > "$SCRIPT_PATH-postinstall" << EOL
#!/bin/bash
sleep 10
TEXT="✅ Auto Restart Installed"
TEXT+="\\n\\nRemark: \$SERVER_REMARK"
TEXT+="\\nHostname: \$(hostname)"
TEXT+="\\nIP: \$(hostname -I)"
TEXT+="\\nTime: \$(date)"
curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \\
    -d "chat_id=$CHAT_ID" \\
    -d "text=\$TEXT" \\
    -d "parse_mode=markdown" > /dev/null 2>&1
EOL

    chmod +x "$SCRIPT_PATH-postinstall"
    (crontab -l 2>/dev/null | grep -v "@reboot $SCRIPT_PATH-postinstall") | crontab -
    (crontab -l 2>/dev/null; echo "@reboot $SCRIPT_PATH-postinstall") | crontab -

    setup_reboot_alert_script

    # Ask user to send test message
    log_info "Would you like to send a test Telegram message now? (y/n)"
    read -r -p "> " send_test
    if [[ "$send_test" =~ ^[Yy]$ ]]; then
        send_telegram_test_message
    fi
}

check_logs() {
    if [ -f "/var/log/x-ui-restart.log" ]; then
        tail -n 20 /var/log/x-ui-restart.log
    else
        log_warn "No restart logs found yet."
    fi
}

remove_restart_cron() {
    # Remove main restart script and cron
    if [ -f "$SCRIPT_PATH" ]; then
        (crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH") | crontab -
        rm -f "$SCRIPT_PATH"
    fi

    # Remove postinstall script and cron
    if [ -f "$SCRIPT_PATH-postinstall" ]; then
        (crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH-postinstall") | crontab -
        rm -f "$SCRIPT_PATH-postinstall"
    fi

    # Remove Telegram config (optional but clean)
    if [ -f "$TELEGRAM_CONF" ]; then
        rm -f "$TELEGRAM_CONF"
        log_success "Telegram settings cleared."
    fi

    log_success "Auto Restart and Telegram settings removed successfully."
}

xui_submenu() {
    while true; do
        clear
        echo -e "${GREEN}==============================${NC}"
        echo -e "${GREEN}=     AMS - Auto X-UI Tool     =${NC}"
        echo -e "${GREEN}==============================${NC}"
        echo -e " ${YELLOW}1.${NC} Install / Reinstall Auto Restart"
        echo -e " ${YELLOW}2.${NC} View Restart Logs"
        echo -e " ${YELLOW}3.${NC} Uninstall Auto Restart"
        echo -e " ${YELLOW}0.${NC} Back to Main Menu"
        echo

        read -r -p "Enter option [0-3]: " sub_choice

        case $sub_choice in
            1)
                setup_restart_cron
                read -r -p "Press Enter to continue..." dummy ;;
            2)
                check_logs
                read -r -p "Press Enter to continue..." dummy ;;
            3)
                remove_restart_cron
                read -r -p "Press Enter to continue..." dummy ;;
            0)
                break ;;
            *)
                log_error "Invalid option. Try again." ;;
        esac
    done
}

# ======================
#   FINAL SETUP OPTIONS
# ======================
setup_global_alias() {
    log_info "Would you like to add 'ams' command for easy access? (y/n)"
    read -r -p "> " add_alias

    if [[ "$add_alias" =~ ^[Yy]$ ]]; then
        mkdir -p /root/ams/
        cp "$0" /root/ams/ams-install.sh
        chmod +x /root/ams/ams-install.sh

        if [ ! -f "/usr/local/bin/ams" ]; then
            sudo ln -s /root/ams/ams-install.sh /usr/local/bin/ams
            log_success "AMS global command created: type 'ams' anytime!"
        else
            log_warn "'ams' command already exists."
        fi
    else
        log_info "Global command skipped. You can manually set it later."
    fi
}

# ======================
#   MAIN MENU HANDLER
# ======================
main() {
    while true; do
        show_main_banner
        read -r -p "Select an option [0-4]: " choice

        case $choice in
            1)
                install_ams_tool
                read -r -p "Press Enter to continue..." dummy ;;
            2)
                xui_submenu ;;
            3)
                setup_telegram_alert
                read -r -p "Press Enter to continue..." dummy ;;
            4)
                send_telegram_test_message
                read -r -p "Press Enter to continue..." dummy ;;
            0)
                setup_global_alias
                log_success "Exiting AMS. Goodbye!"
                exit 0 ;;
            *)
                log_error "Invalid option. Please try again."
                sleep 1 ;;
        esac
    done
}

# ======================
#   START SCRIPT
# ======================
main
