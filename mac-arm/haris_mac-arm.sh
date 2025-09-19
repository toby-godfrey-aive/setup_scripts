#!/bin/bash

set -e

echo "🟢 Starting macOS HARIS setup script..."

# Ensure Homebrew is installed
if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Ensure curl is installed
if ! command -v curl >/dev/null 2>&1; then
    echo "curl not found. Installing with brew..."
    brew install curl
fi

# Ensure mktemp is available
if ! command -v mktemp >/dev/null 2>&1; then
    echo "mktemp not found. Installing coreutils with brew..."
    brew install coreutils
    # Symlink gmktemp as mktemp for compatibility
    if command -v gmktemp >/dev/null 2>&1 && [ ! -f /opt/homebrew/bin/mktemp ]; then
        ln -s "$(command -v gmktemp)" /opt/homebrew/bin/mktemp
    fi
fi

DIR=$(mktemp -d)

curl -fsSL https://raw.githubusercontent.com/SooratiLab/haris/xprize_mcs_dev/server/scripts/haris/setup_haris_mac.sh -o "$DIR/setup_haris.sh"
chmod +x "$DIR/setup_haris.sh"
"$DIR/setup_haris.sh"

rm -r "$DIR"
