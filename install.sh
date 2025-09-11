#!/bin/bash
# install.sh
# Detects the platform (macOS or Ubuntu) and runs:
#   1. core_*.sh (sourced, so env vars persist)
#   2. haris_*.sh
#   3. ardupilot_sitl_*.sh (only if --sitl flag is passed)

set -e

# Colour codes
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[1;33m"
NC="\033[0m" # No colour

INSTALL_SITL=false

# Parse flags
for arg in "$@"; do
    case "$arg" in
        --sitl)
            INSTALL_SITL=true
            shift
            ;;
        -h|--help)
            echo -e "${CYAN}Usage: $0 [--sitl]${NC}"
            echo -e "${CYAN}  --sitl   Also install ArduPilot SITL${NC}"
            exit 0
            ;;
        *)
            echo -e "${YELLOW}Unknown option: $arg${NC}"
            echo -e "Use --help for usage information."
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

# Run scripts with coloured output
echo -e "${CYAN}Running SSH/GH setup script...${NC}"
source "$SCRIPT_DIR/$ID/ssh_gh_${ID}.sh"

echo -e "${CYAN}Running core setup script...${NC}"
source "$SCRIPT_DIR/$ID/core_${ID}.sh"

echo -e "${CYAN}Running Haris setup script...${NC}"
source "$SCRIPT_DIR/$ID/haris_${ID}.sh"

# Optionally run SITL setup
if [ "$INSTALL_SITL" = true ]; then
    echo -e "${CYAN}Running ArduPilot SITL setup script...${NC}"
    source "$SCRIPT_DIR/$ID/ardupilot_sitl_${ID}.sh"
fi
