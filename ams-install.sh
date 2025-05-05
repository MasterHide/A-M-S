#!/bin/bash

# Load utility functions
source "./modules/utils.sh"
source "./modules/xui-auto-restart.sh"

SCRIPT_DIR="$HOME/ams-scripts"
LOG_FILE="/var/log/x-ui-restart.log"

mkdir -p "$SCRIPT_DIR"

show_menu() {
    clear
    echo -e "${GREEN}==============================${NC}"
    echo -e "${GREEN}=     AMS - Auto X-UI Tool     =${NC}"
    echo -e "${GREEN}==============================${NC}"
    echo -e " ${YELLOW}1.${NC} Install Auto Restart"
    echo -e " ${YELLOW}2.${NC} Setup Hourly Restart (Tehran Time)"
    echo -e " ${YELLOW}3.${NC} View Restart Logs"
    echo -e " ${YELLOW}4.${NC} Uninstall Auto Restart"
    echo -e " ${YELLOW}0.${NC} Exit"
    echo
}

main() {
    while true; do
        show_menu
        read -p "Enter option [0-4]: " choice

        case $choice in
            1)
                log_info "Installing auto restart service..."
                setup_restart_cron
                read -p "Press Enter to continue..." ;;
            2)
                log_info "Setting up hourly restart..."
                setup_restart_cron
                read -p "Press Enter to continue..." ;;
            3)
                log_info "Checking restart logs..."
                check_logs
                read -p "Press Enter to continue..." ;;
            4)
                log_warn "Removing auto restart..."
                remove_restart_cron
                read -p "Press Enter to continue..." ;;
            0)
                log_success "Exiting AMS. Goodbye!"
                exit 0 ;;
            *)
                log_error "Invalid option. Try again." ;;
        esac
    done
}

main
