#!/bin/bash

set -e

echo "🟢 Starting Ubuntu HARIS setup script..."

# Ensure curl is installed
if ! command -v curl >/dev/null 2>&1; then
    echo "curl not found. Installing..."
    sudo apt-get install -y curl
fi

# Ensure mktemp is available (should already be part of coreutils)
if ! command -v mktemp >/dev/null 2>&1; then
    echo "mktemp not found. Installing coreutils..."
    sudo apt-get install -y coreutils
fi

DIR=$(mktemp -d)

curl -fsSL https://raw.githubusercontent.com/SooratiLab/haris/xprize_mcs_dev/server/scripts/haris/setup_haris_linux.sh -o "$DIR/setup_haris.sh"
chmod +x "$DIR/setup_haris.sh"
"$DIR/setup_haris.sh"

rm -r "$DIR"
