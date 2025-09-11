#!/bin/bash
# install.sh
# Detects the platform (macOS or Ubuntu) and runs the corresponding scripts:
#   1. core_*.sh
#   2. haris_*.sh
#   3. ardupilot_sitl_*.sh

set -e

OS="$(uname -s)"

case "$OS" in
    Darwin)
        echo "Detected macOS"
        BASE_DIR="mac-arm"
        ;;
    Linux)
        echo "Detected Linux"
        BASE_DIR="ubuntu"
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/$BASE_DIR/ssh_gh_${BASE_DIR}.sh"
source "$SCRIPT_DIR/$BASE_DIR/core_${BASE_DIR}.sh"
source "$SCRIPT_DIR/$BASE_DIR/haris_${BASE_DIR}.sh"
source "$SCRIPT_DIR/$BASE_DIR/ardupilot_sitl_${BASE_DIR}.sh"
