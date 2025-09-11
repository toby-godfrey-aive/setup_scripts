#!/bin/bash
# install.sh
# Detects platform and runs scripts safely, preserving environment updates

set -e

# Colour codes
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[1;33m"
BOLD="\033[1m"
NC="\033[0m"

INSTALL_SITL=false

# Parse flags
for arg in "$@"; do
    case "$arg" in
        --sitl) INSTALL_SITL=true ;;
        -h|--help)
            echo -e "${CYAN}Usage: $0 [--sitl]${NC}"
            echo -e "${CYAN}  --sitl   Also install ArduPilot SITL${NC}"
            exit 0
            ;;
        *)
            echo -e "${YELLOW}Unknown option: $arg${NC}"
            exit 1
            ;;
    esac
done

OS="$(uname -s)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$OS" in
    Darwin)
        echo -e "${GREEN}Detected macOS${NC}"
        ID="mac-arm"
        ;;
    Linux)
        echo -e "${GREEN}Detected Linux${NC}"
        ID="ubuntu"
        ;;
    *)
        echo -e "${YELLOW}Unsupported OS: $OS${NC}"
        exit 1
        ;;
esac

# Function to safely source a script
source_script() {
    local script="$1"
    if [ ! -f "$script" ]; then
        echo -e "${YELLOW}Warning: $script not found. Skipping.${NC}"
        return
    fi
    echo -e "${CYAN}${BOLD}Running $script...${NC}"
    source "$script"
}

# === Run scripts ===
source_script "$SCRIPT_DIR/$ID/ssh_gh_${ID}.sh"
source_script "$SCRIPT_DIR/$ID/core_${ID}.sh"
source_script "$SCRIPT_DIR/$ID/haris_${ID}.sh"

# Optional SITL
if [ "$INSTALL_SITL" = true ]; then
    source_script "$SCRIPT_DIR/$ID/ardupilot_sitl_${ID}.sh"
fi
