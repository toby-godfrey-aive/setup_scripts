#!/bin/bash
# install.sh
# Detects the platform (macOS or Ubuntu) and runs:
#   1. core_*.sh (sourced, so env vars persist)
#   2. haris_*.sh
#   3. ardupilot_sitl_*.sh (only if --sitl flag is passed)

set -e

INSTALL_SITL=false

# Parse flags
for arg in "$@"; do
    case "$arg" in
        --sitl)
            INSTALL_SITL=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--sitl]"
            echo "  --sitl   Also install ArduPilot SITL"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

OS="$(uname -s)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$OS" in
    Darwin)
        echo "Detected macOS"
        ID="mac-arm"
        ;;
    Linux)
        echo "Detected Linux"
        ID="ubuntu"
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

source "$SCRIPT_DIR/$ID/ssh_gh_${ID}.sh"
source "$SCRIPT_DIR/$ID/core_${ID}.sh"
source "$SCRIPT_DIR/$ID/haris_${ID}.sh"

# Optionally run SITL setup
if [ "$INSTALL_SITL" = true ]; then
    source "$SCRIPT_DIR/$ID/ardupilot_sitl_${ID}.sh"
fi
