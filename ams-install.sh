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
    echo -e "${GREEN}
─────▄▀▄─────▄▀▄
─────▄█░░▀▀▀▀▀░░█▄
─▄▄──█░░░░░░░░░░░█──▄▄
█▄▄█─█░░▀░░┬░░▀░░█─█▄▄█
${NC}"
    echo -e "${GREEN}┌───────────────────────────────────────┐${NC}"
    echo -e "${GREEN}│     🚀  POWER UP WITH A-M-S TOOL      │${NC}"
    echo -e "${GREEN}└───────────────────────────────────────┘${NC}"
    echo
    echo -e " ${YELLOW}┌───────────────────────────────────┐${NC}"
    echo -e " ${YELLOW}│${NC} 01. Install AMS Reboot Tools      ${YELLOW}│${NC}"
    echo -e " ${YELLOW}│${NC} 02. Auto (db) Backup X-UI Tool    ${YELLOW}│${NC}"
    echo -e " ${YELLOW}│${NC} 03. Update Telegram Settings      ${YELLOW}│${NC}"
    echo -e " ${YELLOW}│${NC} 04. Send Test Telegram Message    ${YELLOW}│${NC}"
    echo -e " ${YELLOW}│${NC} 05. Uninstall AMS Tools           ${YELLOW}│${NC}"
    echo -e " ${YELLOW}│${NC} 06. Uninstall X-UI Backup Tool    ${YELLOW}│${NC}"
    echo -e " ${YELLOW}│${NC} 07. Disk Cleaner (install) 3xipl  ${YELLOW}│${NC}"
    echo -e " ${YELLOW}│${NC} 08. Remove Disk leaner            ${YELLOW}│${NC}"
    echo -e " ${YELLOW}│${NC} 09. X-UI Automated Ban (TG-BOT)   ${YELLOW}│${NC}"
    echo -e " ${YELLOW}│${NC} 10. Remove X-UI Ban (TG-BOT)      ${YELLOW}│${NC}"
    echo -e " ${YELLOW}│${NC} 11. Logger X-UI Ban               ${YELLOW}│${NC}"
    echo -e " ${YELLOW}│${NC}  0. Exit & Create Menu Cmd        ${YELLOW}│${NC}"
    echo -e " ${YELLOW}└───────────────────────────────────┘${NC}"
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
#   OPTION 5: UNINSTALL AMS TOOL
# ======================
uninstall_ams_tool() {
    log_info "Downloading and running AMS uninstaller..."

    cd /root || { log_error "Failed to enter /root directory"; return 1; }

    curl -O https://raw.githubusercontent.com/MasterHide/A-M-S/main/rm.sh
    if [ $? -ne 0 ]; then
        log_error "Failed to download rm.sh"
    else
        chmod +x rm.sh
        sudo ./rm.sh
        log_success "External uninstaller script executed."
    fi

    if [ -d "$HOME/ams-scripts" ]; then
        rm -rf "$HOME/ams-scripts"
        log_success "AMS configuration files removed."
    fi

    if [ -f "/usr/local/bin/ams" ]; then
        sudo rm -f /usr/local/bin/ams
        log_success "Global 'ams' command removed."
    fi

    log_info "AMS has been fully uninstalled."
}

# ======================
#   TELEGRAM SETTINGS
# ======================
TELEGRAM_CONF="$HOME/ams-scripts/telegram.conf"

if [ -f "$TELEGRAM_CONF" ]; then
    source "$TELEGRAM_CONF"
fi

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

send_telegram_test_message() {
    if [ ! -f "$TELEGRAM_CONF" ]; then
        log_error "Telegram not configured yet."
        return 1
    fi
    source "$TELEGRAM_CONF"
    if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
        log_error "Bot token or Chat ID missing. Please configure first."
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
#   GLOBAL ALIAS SETUP
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
        read -r -p "Select an option [0-10]: " choice
        case $choice in
            1)
                install_ams_tool
                read -r -p "Press Enter to continue..." dummy ;;
            2)
                bash <(curl -s https://raw.githubusercontent.com/MasterHide/xSL-backup/main/xsl-install.sh)
                read -r -p "Press Enter to continue..." dummy ;;
            3)
                setup_telegram_alert
                read -r -p "Press Enter to continue..." dummy ;;
            4)
                send_telegram_test_message
                read -r -p "Press Enter to continue..." dummy ;;
            5)
                uninstall_ams_tool
                read -r -p "Press Enter to continue..." dummy ;;
            6)
                bash <(curl -s https://raw.githubusercontent.com/MasterHide/xSL-backup/main/xsl-uninstall.sh)
                read -r -p "Press Enter to continue..." dummy ;;

            7)
                bash <(curl -fsSL https://raw.githubusercontent.com/MasterHide/A-M-S/main/modules/log_check.sh)
                read -r -p "Press Enter to continue..." dummy ;;

            8)
                bash <(curl -s https://raw.githubusercontent.com/MasterHide/A-M-S/main/modules/rm_log_check.sh)
                read -r -p "Press Enter to continue..." dummy ;; 

            9)
                bash <(curl -s https://raw.githubusercontent.com/MasterHide/xui-tg-bot/main/install/x-ui-tg-install.sh)
                read -r -p "Press Enter to continue..." dummy ;;
                
            10)
                bash <(curl -s https://raw.githubusercontent.com/MasterHide/xui-tg-bot/main/install/x-ui-tg-uninstall.sh)
                read -r -p "Press Enter to continue..." dummy ;;                
                
            11)
                tail -f /var/log/xui-tg-bot.log
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

main
