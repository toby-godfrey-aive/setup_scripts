#!/bin/bash

set -e  # Exit on error

echo "🟢 Starting ArduPilot SITL setup script for macOS..."

# Check for Homebrew and install if not present
if ! command -v brew &> /dev/null; then
    echo "🍺 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH (for Apple Silicon Macs)
    if [[ -f /opt/homebrew/bin/brew ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    echo "🍺 Updating Homebrew..."
    brew update
fi

# Install required dependencies for ArduPilot
echo "📦 Installing ArduPilot dependencies..."
brew install python@3.11 gcc git autoconf automake libtool pkg-config gawk

# Install Python packages needed for ArduPilot
echo "🐍 Installing Python dependencies..."
pip3 install empy==3.3.4 pyserial pymavlink

cd ~
echo "📥 Cloning ArduPilot repository..."
git clone --recurse-submodules https://github.com/ArduPilot/ardupilot.git
cd ardupilot

# Run the macOS-specific prerequisite installation
echo "🔧 Installing ArduPilot prerequisites for macOS..."
Tools/environment_install/install-prereqs-mac.sh -y

# Source the updated environment
if [[ -f ~/.zshrc ]]; then
    source ~/.zshrc
elif [[ -f ~/.bash_profile ]]; then
    source ~/.bash_profile
fi

# Add ArduPilot tools to PATH
echo "🛠️ Adding ArduPilot tools to PATH..."
TOOLS_PATH="export PATH=\$HOME/ardupilot/Tools/autotest:\$PATH"

# Add to .zshrc (default shell on macOS)
if ! grep -q "ardupilot/Tools/autotest" ~/.zshrc 2>/dev/null; then
    echo "$TOOLS_PATH" >> ~/.zshrc
fi

# Also add to .bash_profile in case user switches shells
if ! grep -q "ardupilot/Tools/autotest" ~/.bash_profile 2>/dev/null; then
    echo "$TOOLS_PATH" >> ~/.bash_profile
fi

export PATH="$HOME/ardupilot/Tools/autotest:$PATH"

# Configure and build
echo "🔨 Configuring ArduPilot build..."
./waf configure --board sitl

echo "🛠️ Building ArduPilot plane..."
./waf plane

echo "🎉 Setup complete for ArduPilot SITL on macOS!"
echo ""
echo "To run ArduPilot SITL, use commands like:"
echo "  sim_vehicle.py -v ArduPlane"
echo "  sim_vehicle.py -v ArduCopter"
echo ""
echo "Please restart your terminal or run 'source ~/.zshrc' to use the new environment."
