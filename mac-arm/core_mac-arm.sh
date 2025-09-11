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
        BASE_DIR="mac"
        OS_SUFFIX="macos"
        ;;
    Linux)
        echo "Detected Linux"
        BASE_DIR="ubuntu"
        OS_SUFFIX="ubuntu"
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

# Source core to persist environment changes
source "$SCRIPT_DIR/$BASE_DIR/core_${OS_SUFFIX}.sh"

# Run Haris setup
source "$SCRIPT_DIR/$BASE_DIR/haris_${OS_SUFFIX}.sh"

# Optionally run SITL setup
if [ "$INSTALL_SITL" = true ]; then
    source "$SCRIPT_DIR/$BASE_DIR/ardupilot_sitl_${OS_SUFFIX}.sh"
fi
