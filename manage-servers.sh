#!/bin/bash
# Kamailio Server Management Script
# This script helps manage Asterisk server mappings

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

KAMAILIO_CFG="/etc/kamailio/kamailio.cfg"

# Function to display current server mappings
show_servers() {
    echo -e "${GREEN}Current Asterisk Server Mappings:${NC}"
    echo "=================================="
    
    grep -A 20 "event_route\[htable:mod-init\]" $KAMAILIO_CFG | \
    grep "asterisk_servers=>" | \
    grep -v "^#" | \
    sed 's/.*asterisk_servers=>/  /' | \
    sed 's/) = /  ->  /' | \
    sed 's/[";]//g'
    
    echo ""
}

# Function to test connectivity to a server
test_server() {
    local ip=$1
    echo -e "${YELLOW}Testing connectivity to $ip...${NC}"
    
    # Ping test
    if ping -c 1 -W 2 $ip > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Ping successful"
    else
        echo -e "  ${RED}✗${NC} Ping failed"
        return 1
    fi
    
    # Port 5060 test
    if nc -zv -w 2 $ip 5060 > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} SIP port 5060 is open"
    else
        echo -e "  ${RED}✗${NC} SIP port 5060 is not accessible"
        return 1
    fi
    
    echo -e "  ${GREEN}Server $ip is reachable${NC}"
    return 0
}

# Function to add a new server
add_server() {
    echo -e "${GREEN}Add New Asterisk Server${NC}"
    echo "======================="
    
    read -p "Enter server domain (e.g., ast2.sandboxegytelecoms.com): " domain
    read -p "Enter server VPN IP (e.g., 10.10.40.118): " ip
    read -p "Enter short name (e.g., ast2): " shortname
    
    echo ""
    echo -e "${YELLOW}Testing server connectivity...${NC}"
    
    if ! test_server $ip; then
        echo -e "${RED}Warning: Server is not reachable. Continue anyway? (y/N)${NC}"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo "Operation cancelled."
            return 1
        fi
    fi
    
    echo ""
    echo -e "${YELLOW}Add the following lines to kamailio.cfg:${NC}"
    echo ""
    echo "    # Server - $domain"
    echo "    \$sht(asterisk_servers=>$domain) = \"$ip\";"
    echo "    \$sht(asterisk_servers=>$shortname) = \"$ip\";"
    echo ""
    echo -e "${YELLOW}Location:${NC} Inside event_route[htable:mod-init] section"
    echo ""
    echo -e "${YELLOW}After adding, restart Kamailio:${NC}"
    echo "    systemctl restart kamailio"
    echo ""
}

# Function to check Kamailio status
check_status() {
    echo -e "${GREEN}Kamailio Service Status:${NC}"
    systemctl status kamailio --no-pager | head -n 10
    echo ""
}

# Function to reload Kamailio
reload_kamailio() {
    echo -e "${YELLOW}Reloading Kamailio...${NC}"
    systemctl restart kamailio
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Kamailio reloaded successfully${NC}"
    else
        echo -e "${RED}✗ Failed to reload Kamailio${NC}"
        return 1
    fi
}

# Function to view recent logs
view_logs() {
    echo -e "${GREEN}Recent Kamailio Logs:${NC}"
    echo "===================="
    journalctl -u kamailio -n 50 --no-pager
}

# Function to test routing
test_routing() {
    read -p "Enter domain to test (e.g., ast1.sandboxegytelecoms.com): " domain
    
    echo -e "${YELLOW}Checking routing for domain: $domain${NC}"
    echo ""
    
    # Look up in configuration
    ip=$(grep "asterisk_servers=>$domain" $KAMAILIO_CFG | grep -v "^#" | sed 's/.*= "//' | sed 's/";//')
    
    if [ -n "$ip" ]; then
        echo -e "${GREEN}Found mapping:${NC} $domain -> $ip"
        echo ""
        test_server $ip
    else
        echo -e "${RED}No mapping found for domain: $domain${NC}"
        echo "Using default server..."
    fi
}

# Main menu
show_menu() {
    echo ""
    echo -e "${GREEN}==================================${NC}"
    echo -e "${GREEN}  Kamailio Server Management${NC}"
    echo -e "${GREEN}==================================${NC}"
    echo "1. Show current server mappings"
    echo "2. Add new server"
    echo "3. Test server connectivity"
    echo "4. Test domain routing"
    echo "5. Check Kamailio status"
    echo "6. Reload Kamailio"
    echo "7. View recent logs"
    echo "8. Exit"
    echo ""
    read -p "Select option [1-8]: " choice
    
    case $choice in
        1) show_servers ;;
        2) add_server ;;
        3) 
            read -p "Enter server IP to test: " ip
            test_server $ip
            ;;
        4) test_routing ;;
        5) check_status ;;
        6) reload_kamailio ;;
        7) view_logs ;;
        8) exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
    esac
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (sudo)${NC}"
    exit 1
fi

# Check if config file exists
if [ ! -f "$KAMAILIO_CFG" ]; then
    echo -e "${RED}Error: Kamailio config not found at $KAMAILIO_CFG${NC}"
    exit 1
fi

# Main loop
while true; do
    show_menu
    echo ""
    read -p "Press Enter to continue..."
done
