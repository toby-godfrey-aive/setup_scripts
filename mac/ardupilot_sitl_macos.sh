#!/bin/bash
set -e

echo "🟢 Starting ArduPilot SITL setup script for macOS..."
echo "ℹ macOS version: $(sw_vers -productVersion)"
echo "ℹ Architecture: $(uname -m)"
echo "ℹ Shell: $SHELL"
echo "ℹ User: $USER"
echo "ℹ Home: $HOME"
echo ""

# Helpers
command_exists() {
    command -v "$1" >/dev/null 2>&1
}
add_to_shell_rc() {
    local line="$1"; local file="$2"
    if [[ -f "$file" ]] && ! grep -Fxq "$line" "$file"; then
        echo "$line" >> "$file"
        echo "✅ Added to $file"
    fi
}

# Detect shell RC
if [[ "$SHELL" == *"zsh"* ]]; then SHELL_RC="$HOME/.zshrc"
elif [[ "$SHELL" == *"bash"* ]]; then SHELL_RC="$HOME/.bash_profile"
else SHELL_RC="$HOME/.profile"; fi
echo "🐚 Using shell rc: $SHELL_RC"

# Xcode Command Line Tools
if ! xcode-select -p >/dev/null 2>&1; then
    echo "👉 Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "Please rerun this script once the install completes."
    exit 0
else
    echo "✅ Xcode Command Line Tools already installed"
fi

# Homebrew installation/update
if ! command_exists brew; then
    echo "🍺 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$SHELL_RC"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f "/usr/local/bin/brew" ]]; then
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$SHELL_RC"
        eval "$(/usr/local/bin/brew shellenv)"
    fi
else
    echo "🍺 Updating Homebrew..."
    brew update
fi

# Install required brew packages (without genromfs)
echo "📦 Installing required brew packages..."
BREW_PKGS=(gcc-arm-none-eabi gawk python@3.11 git cmake ninja ccache opencv)
for pkg in "${BREW_PKGS[@]}"; do
    if brew list "$pkg" &>/dev/null; then
        echo "  • $pkg already installed"
    else
        echo "  • Installing $pkg..."
        brew install "$pkg"
    fi
done

# Python setup
if command_exists /opt/homebrew/bin/python3.11; then
    PYTHON_CMD="/opt/homebrew/bin/python3.11"
elif command_exists /usr/local/bin/python3.11; then
    PYTHON_CMD="/usr/local/bin/python3.11"
elif command_exists python3; then
    PYTHON_CMD="python3"
else
    echo "❌ Python 3 not found"
    exit 1
fi
echo "🐍 Using Python: $($PYTHON_CMD --version)"

$PYTHON_CMD -m pip install --upgrade pip setuptools wheel

PYTHON_PKGS=(empy pyserial pymavlink future lxml pexpect matplotlib numpy psutil intelhex geocoder requests paramiko pynmea2)
echo "📦 Installing Python packages..."
$PYTHON_CMD -m pip install "${PYTHON_PKGS[@]}"

echo "🚁 Installing MAVProxy..."
$PYTHON_CMD -m pip install MAVProxy

# ArduPilot source
ARDUPILOT_DIR="$HOME/ardupilot"
if [[ -d "$ARDUPILOT_DIR" ]]; then
    echo "📂 Updating ArduPilot repo..."
    cd "$ARDUPILOT_DIR"
    git pull origin master
    git submodule update --init --recursive
else
    echo "📥 Cloning ArduPilot..."
    cd "$HOME"
    git clone --recurse-submodules https://github.com/ArduPilot/ardupilot.git
    cd ardupilot
fi

# Run prereqs script safely
echo "🔧 Running ArduPilot prereqs script..."
if [[ -f "Tools/environment_install/install-prereqs-mac.sh" ]]; then
    chmod +x Tools/environment_install/install-prereqs-mac.sh
    if ! Tools/environment_install/install-prereqs-mac.sh -y 2> prereqs_errors.log; then
        echo "⚠️ Prereqs script had issues, continuing..."
    fi
    if grep -q "/usr/local/bin" prereqs_errors.log; then
        echo "ℹ️ Ignored missing /usr/local/bin (not needed on Apple Silicon)"
    fi
    rm -f prereqs_errors.log
else
    echo "⚠️ Prereqs script not found, continuing..."
fi

# Mojave SDK headers prompt
OSVER=$(sw_vers -productVersion | awk -F. '{print $2}')
if [[ $OSVER -eq 14 ]]; then
    echo "ℹ️ Mojave detected. If you see header errors, run:"
    echo "   open /Library/Developer/CommandLineTools/Packages/macOS_SDK_headers_for_macOS_10.14.pkg"
fi

# PATH setup
TOOLS_PATH_EXPORT="export PATH=\"\$HOME/ardupilot/Tools/autotest:\$PATH\""
add_to_shell_rc "$TOOLS_PATH_EXPORT" "$SHELL_RC"
add_to_shell_rc "$TOOLS_PATH_EXPORT" "$HOME/.zshrc"
add_to_shell_rc "$TOOLS_PATH_EXPORT" "$HOME/.bash_profile"
add_to_shell_rc "$TOOLS_PATH_EXPORT" "$HOME/.profile"

echo ""
echo "✅ ArduPilot SITL setup complete!"
echo "👉 Run 'source $SHELL_RC' or restart your terminal."
echo "👉 Example to run SITL: sim_vehicle.py -v ArduCopter -f quad --console --map"
