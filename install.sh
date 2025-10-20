#!/bin/bash

# Installation script for collate utility
# Installs collate to ~/.local/bin and sets up system-wide configuration

set -e

# Color codes
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Collate Installation Script${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Check if running as root (we don't want that)
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}Error: Do not run this script as root or with sudo${NC}"
   echo -e "${YELLOW}The script will install to your user's ~/.local/bin directory${NC}"
   exit 1
fi

# Determine installation directory
INSTALL_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.collate"

echo -e "${GREEN}Installation directories:${NC}"
echo -e "  Binary: ${INSTALL_DIR}"
echo -e "  Config: ${CONFIG_DIR}\n"

# Create directories if they don't exist
echo -e "${YELLOW}Creating directories...${NC}"
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"

# Check if collate.sh exists in current directory
if [[ ! -f "collate.sh" ]]; then
    echo -e "${RED}Error: collate.sh not found in current directory${NC}"
    echo -e "${YELLOW}Please run this script from the collate project directory${NC}"
    exit 1
fi

# Install collate.sh
echo -e "${YELLOW}Installing collate.sh...${NC}"
cp collate.sh "$INSTALL_DIR/collate"
chmod +x "$INSTALL_DIR/collate"

# Create col8 symlink
echo -e "${YELLOW}Creating col8 alias...${NC}"
ln -sf "$INSTALL_DIR/collate" "$INSTALL_DIR/col8"

# Install or update config.yaml
if [[ -f "$CONFIG_DIR/config.yaml" ]]; then
    echo -e "${YELLOW}Config file already exists at $CONFIG_DIR/config.yaml${NC}"
    printf "${YELLOW}Overwrite existing config? (y/N): ${NC}"
    read overwrite
    if [[ "$overwrite" =~ ^[yY]$ ]]; then
        cp config.yaml "$CONFIG_DIR/config.yaml"
        echo -e "${GREEN}Config file updated${NC}"
    else
        echo -e "${YELLOW}Keeping existing config file${NC}"
    fi
else
    echo -e "${YELLOW}Installing config.yaml...${NC}"
    cp config.yaml "$CONFIG_DIR/config.yaml"
    echo -e "${GREEN}Config file installed${NC}"
fi

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo -e "\n${YELLOW}Warning: $INSTALL_DIR is not in your PATH${NC}"
    echo -e "${YELLOW}Add the following line to your ~/.bashrc or ~/.zshrc:${NC}\n"
    echo -e "${BLUE}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}\n"
    
    printf "${YELLOW}Would you like me to add it to your shell config? (y/N): ${NC}"
    read add_path
    if [[ "$add_path" =~ ^[yY]$ ]]; then
        # Detect shell
        if [[ -n "$BASH_VERSION" ]]; then
            SHELL_RC="$HOME/.bashrc"
        elif [[ -n "$ZSH_VERSION" ]]; then
            SHELL_RC="$HOME/.zshrc"
        else
            echo -e "${RED}Unable to detect shell. Please add PATH manually.${NC}"
            exit 0
        fi
        
        # Add to shell config if not already there
        if ! grep -q "export PATH=\"\$HOME/.local/bin:\$PATH\"" "$SHELL_RC"; then
            echo "" >> "$SHELL_RC"
            echo "# Added by collate installer" >> "$SHELL_RC"
            echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$SHELL_RC"
            echo -e "${GREEN}Added to $SHELL_RC${NC}"
            echo -e "${YELLOW}Please run: source $SHELL_RC${NC}"
            echo -e "${YELLOW}Or restart your terminal${NC}"
        else
            echo -e "${GREEN}PATH already configured in $SHELL_RC${NC}"
        fi
    fi
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}   Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "${GREEN}Installed files:${NC}"
echo -e "  ✓ ${INSTALL_DIR}/collate"
echo -e "  ✓ ${INSTALL_DIR}/col8 (symlink)"
echo -e "  ✓ ${CONFIG_DIR}/config.yaml\n"

echo -e "${BLUE}Quick Start:${NC}"
echo -e "  1. ${YELLOW}collate init${NC}          - Initialize project config"
echo -e "  2. ${YELLOW}collate ./my_folder${NC}   - Combine files"
echo -e "  3. ${YELLOW}collate --help${NC}        - View full help\n"

echo -e "${BLUE}Testing installation:${NC}"
if command -v collate &> /dev/null; then
    echo -e "${GREEN}✓ collate command is available${NC}"
    collate --help > /dev/null 2>&1 && echo -e "${GREEN}✓ collate runs successfully${NC}" || echo -e "${RED}✗ collate failed to run${NC}"
else
    echo -e "${YELLOW}! collate command not found in PATH${NC}"
    echo -e "${YELLOW}  Please restart your terminal or run: source ~/.bashrc${NC}"
fi

echo -e "\n${BLUE}Documentation:${NC}"
echo -e "  Run ${YELLOW}collate --help${NC} for usage information\n"