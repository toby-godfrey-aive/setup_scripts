#!/bin/bash

set -e  # Exit on error

echo "🟢 Starting ArduPilot SITL setup script for macOS..."
echo "🔍 System information:"
echo "   macOS version: $(sw_vers -productVersion)"
echo "   Architecture: $(uname -m)"
echo "   Shell: $SHELL"
echo "   User: $USER"
echo "   Home: $HOME"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to add to shell RC files
add_to_shell_rc() {
    local line="$1"
    local file="$2"

    if [[ -f "$file" ]] && ! grep -Fxq "$line" "$file"; then
        echo "$line" >> "$file"
        echo "✅ Added to $file"
    fi
}

# Detect shell and set appropriate RC file
if [[ "$SHELL" == *"zsh"* ]]; then
    SHELL_RC="$HOME/.zshrc"
    SHELL_NAME="zsh"
elif [[ "$SHELL" == *"bash"* ]]; then
    SHELL_RC="$HOME/.bash_profile"
    SHELL_NAME="bash"
else
    SHELL_RC="$HOME/.profile"
    SHELL_NAME="default"
fi

echo "🐚 Detected shell: $SHELL_NAME, using RC file: $SHELL_RC"

# Check for Homebrew and install if not present
if ! command_exists brew; then
    echo "🍺 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH - check both possible locations
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        echo "📍 Adding Apple Silicon Homebrew to PATH..."
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$SHELL_RC"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f "/usr/local/bin/brew" ]]; then
        echo "📍 Adding Intel Homebrew to PATH..."
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$SHELL_RC"
        eval "$(/usr/local/bin/brew shellenv)"
    else
        echo "⚠️  Homebrew installed but not found in expected locations. Please restart your terminal and re-run this script."
        exit 1
    fi
else
    echo "🍺 Homebrew found. Updating..."
    brew update
fi

# Install required dependencies for ArduPilot
echo "📦 Installing ArduPilot dependencies..."

# Core build tools and libraries
BREW_PACKAGES=(
    python@3.11
    gcc
    git
    autoconf
    automake
    libtool
    pkg-config
    gawk
    cmake
    ninja
    ccache
    opencv
)

# Install packages, checking each one
for package in "${BREW_PACKAGES[@]}"; do
    if brew list "$package" &>/dev/null; then
        echo "✅ $package already installed"
    else
        echo "📦 Installing $package..."
        brew install "$package"
    fi
done

# Ensure Python 3.11 is in PATH (prefer Homebrew’s version)
if command_exists /opt/homebrew/bin/python3.11; then
    PYTHON_CMD="/opt/homebrew/bin/python3.11"
elif command_exists /usr/local/bin/python3.11; then
    PYTHON_CMD="/usr/local/bin/python3.11"
elif command_exists python3; then
    PYTHON_CMD="python3"
else
    echo "❌ Python 3 not found after installation"
    exit 1
fi

echo "🐍 Using Python: $($PYTHON_CMD --version)"

# Upgrade pip tooling
$PYTHON_CMD -m pip install --upgrade pip setuptools wheel

# Essential ArduPilot SITL dependencies
PYTHON_PACKAGES=(
    "empy"
    "pyserial"
    "pymavlink"
    "future"
    "lxml"
    "pexpect"
    "matplotlib"
    "numpy"
    "psutil"
    "intelhex"
    "geocoder"
    "requests"
    "paramiko"
    "pynmea2"
)

echo "📦 Installing Python packages for ArduPilot SITL..."
$PYTHON_CMD -m pip install "${PYTHON_PACKAGES[@]}"

# Optional: Install MAVProxy globally (not --user)
echo "🚁 Installing MAVProxy..."
$PYTHON_CMD -m pip install MAVProxy

# Set up ArduPilot directory
ARDUPILOT_DIR="$HOME/ardupilot"

if [[ -d "$ARDUPILOT_DIR" ]]; then
    echo "📂 ArduPilot directory already exists. Updating..."
    cd "$ARDUPILOT_DIR"
    git pull origin master
    git submodule update --init --recursive
else
    cd "$HOME"
    echo "📥 Cloning ArduPilot repository..."
    git clone --recurse-submodules https://github.com/ArduPilot/ardupilot.git
    cd ardupilot
fi

# Run the macOS-specific prerequisite installation
echo "🔧 Installing ArduPilot prerequisites for macOS..."
if [[ -f "Tools/environment_install/install-prereqs-mac.sh" ]]; then
    chmod +x Tools/environment_install/install-prereqs-mac.sh
    echo "📍 Running ArduPilot macOS prerequisites script..."
    # Run with error handling - the prerequisites script sometimes has issues
    if ! Tools/environment_install/install-prereqs-mac.sh -y; then
        echo "⚠️  ArduPilot prerequisites script encountered issues, but continuing..."
        echo "   This is often normal and doesn't prevent SITL from working."
    fi
else
    echo "⚠️  macOS prerequisites script not found, continuing..."
fi

# Add ArduPilot tools to PATH
echo "🛠️ Adding ArduPilot tools to PATH..."
TOOLS_PATH_EXPORT="export PATH=\"\$HOME/ardupilot/Tools/autotest:\$PATH\""

# Add to appropriate shell RC file
add_to_shell_rc "$TOOLS_PATH_EXPORT" "$SHELL_RC"

# Also add to common RC files as backup
add_to_shell_rc "$TOOLS_PATH_EXPORT" "$HOME/.zshrc"
add_to_shell_rc "$TOOLS_PATH_EXPORT" "$HOME/.bash_profile"
add_to_shell_rc "$TOOLS_PATH_EXPORT" "$HOME/.profile"

echo ""
echo "✅ ArduPilot SITL setup complete!"
echo "👉 Open a new terminal or run 'source $SHELL_RC' to update your PATH."
echo "👉 To start SITL, run something like:"
echo "     sim_vehicle.py -v ArduCopter -f quad --console --map"
