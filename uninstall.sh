#!/bin/bash

# Uninstallation script for collate utility
# Removes collate from ~/.local/bin and optionally removes configuration

set -e

# Color codes
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Collate Uninstallation Script${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}Error: Do not run this script as root or with sudo${NC}"
   exit 1
fi

INSTALL_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.collate"

echo -e "${YELLOW}This will remove:${NC}"
echo -e "  - ${INSTALL_DIR}/collate"
echo -e "  - ${INSTALL_DIR}/col8"

# Check if files exist
FILES_TO_REMOVE=()
if [[ -f "$INSTALL_DIR/collate" ]]; then
    FILES_TO_REMOVE+=("$INSTALL_DIR/collate")
fi
if [[ -L "$INSTALL_DIR/col8" || -f "$INSTALL_DIR/col8" ]]; then
    FILES_TO_REMOVE+=("$INSTALL_DIR/col8")
fi

if [[ ${#FILES_TO_REMOVE[@]} -eq 0 ]]; then
    echo -e "\n${YELLOW}No collate installation found in $INSTALL_DIR${NC}"
else
    echo -e "\n${YELLOW}Found ${#FILES_TO_REMOVE[@]} file(s) to remove${NC}"
    printf "${YELLOW}Proceed with removal? (y/N): ${NC}"
    read confirm
    
    if [[ "$confirm" =~ ^[yY]$ ]]; then
        for file in "${FILES_TO_REMOVE[@]}"; do
            rm -f "$file"
            echo -e "${GREEN}✓ Removed: $file${NC}"
        done
    else
        echo -e "${YELLOW}Cancelled. No files were removed.${NC}"
        exit 0
    fi
fi

# Ask about config directory
if [[ -d "$CONFIG_DIR" ]]; then
    echo -e "\n${YELLOW}Configuration directory found: $CONFIG_DIR${NC}"
    echo -e "${YELLOW}This contains your system-wide config.yaml${NC}"
    printf "${RED}Remove configuration directory? (y/N): ${NC}"
    read remove_config
    
    if [[ "$remove_config" =~ ^[yY]$ ]]; then
        rm -rf "$CONFIG_DIR"
        echo -e "${GREEN}✓ Removed: $CONFIG_DIR${NC}"
    else
        echo -e "${YELLOW}Keeping configuration directory${NC}"
    fi
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}   Uninstallation Complete!${NC}"
echo -e "${GREEN}========================================${NC}\n"

# Check for project-specific configs
COLLATE_DIRS=$(find ~ -type d -name ".collate" 2>/dev/null | head -n 5)
if [[ -n "$COLLATE_DIRS" ]]; then
    echo -e "${BLUE}Note: Found project-specific .collate directories:${NC}"
    echo "$COLLATE_DIRS" | while read -r dir; do
        echo -e "  - ${YELLOW}$dir${NC}"
    done
    echo -e "\n${YELLOW}These are project-specific and were not removed.${NC}"
    echo -e "${YELLOW}You can remove them manually if needed using:${NC}"
    echo -e "${BLUE}  rm -rf <project_directory>/.collate${NC}\n"
fi

echo -e "${GREEN}Collate has been uninstalled from your system.${NC}\n"