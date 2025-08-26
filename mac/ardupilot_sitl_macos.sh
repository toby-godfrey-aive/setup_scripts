#!/bin/bash

# ArduPilot SITL (Software In The Loop) Installer for macOS
# This script automatically sets up the complete ArduPilot SITL environment
# Compatible with macOS 10.14+ (Mojave and later)
# Author: Auto-generated script based on ArduPilot documentation
# Version: 2.0

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Colors and formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'

# Configuration
readonly PYTHON_VERSION="3.11"
readonly ARDUPILOT_REPO="https://github.com/ArduPilot/ardupilot.git"
readonly ARDUPILOT_DIR="$HOME/ardupilot"
readonly LOG_FILE="$HOME/ardupilot_install.log"
readonly BUILD_TARGET="CubeOrange"
readonly VEHICLE="plane"
readonly FIRMWARE_DIR="$HOME/ArduPlane_CubeOrange_Firmware"

# System info
readonly MACOS_VERSION=$(sw_vers -productVersion)
readonly ARCH=$(uname -m)
readonly SHELL_NAME=$(basename "$SHELL")
readonly MAJOR_VERSION=$(echo "$MACOS_VERSION" | cut -d. -f1)
readonly MINOR_VERSION=$(echo "$MACOS_VERSION" | cut -d. -f2)

# Utility functions
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$LOG_FILE"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

get_shell_rc() {
    case "$SHELL_NAME" in
        zsh) echo "$HOME/.zshrc" ;;
        bash) echo "$HOME/.bash_profile" ;;
        *) echo "$HOME/.profile" ;;
    esac
}

add_to_path() {
    local path_line="$1"
    local shell_rc="$2"

    if [[ -f "$shell_rc" ]] && ! grep -Fxq "$path_line" "$shell_rc"; then
        echo "$path_line" >> "$shell_rc"
        success "Added PATH export to $shell_rc"
    elif [[ ! -f "$shell_rc" ]]; then
        echo "$path_line" > "$shell_rc"
        success "Created $shell_rc with PATH export"
    else
        info "PATH already configured in $shell_rc"
    fi
}

check_system_requirements() {
    info "Checking system requirements..."

    # Check macOS version
    if [[ $MAJOR_VERSION -lt 10 ]] || [[ $MAJOR_VERSION -eq 10 && $MINOR_VERSION -lt 14 ]]; then
        error "macOS 10.14 (Mojave) or later required. Current version: $MACOS_VERSION"
        exit 1
    fi

    success "macOS version $MACOS_VERSION is supported"
    info "Architecture: $ARCH"
    info "Shell: $SHELL_NAME"
}

install_xcode_tools() {
    info "Checking Xcode Command Line Tools..."

    if ! xcode-select -p >/dev/null 2>&1; then
        log "Installing Xcode Command Line Tools..."
        xcode-select --install

        echo ""
        echo -e "${YELLOW}${BOLD}IMPORTANT:${NC}"
        echo "Please complete the Xcode Command Line Tools installation"
        echo "and then run this script again."
        echo ""
        exit 0
    else
        success "Xcode Command Line Tools already installed"
    fi
}

install_homebrew() {
    info "Checking Homebrew installation..."

    if ! command_exists brew; then
        log "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add Homebrew to PATH based on architecture
        if [[ "$ARCH" == "arm64" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
            add_to_path 'eval "$(/opt/homebrew/bin/brew shellenv)"' "$(get_shell_rc)"
        else
            eval "$(/usr/local/bin/brew shellenv)"
            add_to_path 'eval "$(/usr/local/bin/brew shellenv)"' "$(get_shell_rc)"
        fi

        success "Homebrew installed successfully"
    else
        info "Updating Homebrew..."
        brew update || warn "Homebrew update failed, continuing..."
        success "Homebrew is ready"
    fi
}

install_brew_packages() {
    info "Installing required Homebrew packages..."

    local packages=(
        "gcc-arm-none-eabi"
        "gawk"
        "python@${PYTHON_VERSION}"
        "git"
        "cmake"
        "ninja"
        "ccache"
        "opencv"
        "genromfs"
    )

    for package in "${packages[@]}"; do
        if brew list "$package" &>/dev/null; then
            info "$package already installed"
        else
            log "Installing $package..."
            if brew install "$package"; then
                success "$package installed"
            else
                warn "$package installation failed, continuing..."
            fi
        fi
    done

    # Special handling for binutils removal (Mojave compatibility)
    if brew list binutils &>/dev/null; then
        warn "Removing binutils to prevent build issues on modern macOS..."
        brew uninstall binutils || warn "Failed to remove binutils, continuing..."
    fi
}

setup_python() {
    info "Setting up Python environment..."

    # Find Python 3.11
    local python_cmd=""
    for path in "/opt/homebrew/bin/python${PYTHON_VERSION}" "/usr/local/bin/python${PYTHON_VERSION}" "python3"; do
        if command_exists "$path"; then
            python_cmd="$path"
            break
        fi
    done

    if [[ -z "$python_cmd" ]]; then
        error "Python 3 not found. Please ensure Python ${PYTHON_VERSION} is installed via Homebrew."
        exit 1
    fi

    info "Using Python: $($python_cmd --version)"

    # Upgrade pip
    log "Upgrading pip and essential packages..."
    $python_cmd -m pip install --upgrade pip setuptools wheel

    # Install Python packages required for ArduPilot
    local python_packages=(
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
        "wxpython"
        "billiard"
    )

    info "Installing Python packages for ArduPilot..."
    for package in "${python_packages[@]}"; do
        log "Installing $package..."
        if $python_cmd -m pip install "$package"; then
            success "$package installed"
        else
            warn "$package installation failed, continuing..."
        fi
    done

    # Install MAVProxy
    log "Installing MAVProxy..."
    if $python_cmd -m pip install MAVProxy; then
        success "MAVProxy installed successfully"
    else
        error "MAVProxy installation failed"
        exit 1
    fi
}

clone_ardupilot() {
    info "Setting up ArduPilot source code..."

    if [[ -d "$ARDUPILOT_DIR" ]]; then
        log "Updating existing ArduPilot repository..."
        cd "$ARDUPILOT_DIR"

        # Check if it's a git repository
        if [[ -d ".git" ]]; then
            git fetch origin
            git checkout master
            git pull origin master
            git submodule update --init --recursive
            success "ArduPilot repository updated"
        else
            warn "Directory exists but is not a git repository. Removing and re-cloning..."
            cd "$HOME"
            rm -rf "$ARDUPILOT_DIR"
            git clone --recurse-submodules "$ARDUPILOT_REPO"
            success "ArduPilot repository cloned"
        fi
    else
        log "Cloning ArduPilot repository..."
        cd "$HOME"
        git clone --recurse-submodules "$ARDUPILOT_REPO"
        success "ArduPilot repository cloned"
    fi

    cd "$ARDUPILOT_DIR"
}

run_prereqs_script() {
    info "Running ArduPilot prerequisites script..."

    local prereqs_script="Tools/environment_install/install-prereqs-mac.sh"

    if [[ -f "$prereqs_script" ]]; then
        chmod +x "$prereqs_script"
        log "Executing ArduPilot prereqs script..."

        # Run with error handling
        if ./"$prereqs_script" -y 2>"$HOME/prereqs_errors.log"; then
            success "ArduPilot prerequisites script completed successfully"
        else
            warn "Prerequisites script had some issues (this is often normal)"
            if [[ -f "$HOME/prereqs_errors.log" ]]; then
                info "Checking error log..."
                if grep -q "/usr/local/bin" "$HOME/prereqs_errors.log"; then
                    info "Ignored /usr/local/bin warnings (normal on Apple Silicon)"
                fi
            fi
        fi

        # Cleanup
        rm -f "$HOME/prereqs_errors.log"
    else
        warn "Prerequisites script not found at $prereqs_script"
    fi
}

setup_build_environment() {
    info "Setting up build environment for ArduPlane on CubeOrange..."

    cd "$ARDUPILOT_DIR"

    # Clean any previous builds
    log "Cleaning previous builds..."
    ./waf distclean

    # Configure waf for CubeOrange
    log "Configuring build system for CubeOrange target..."
    if ./waf configure --board "$BUILD_TARGET"; then
        success "Build system configured for $BUILD_TARGET"
    else
        error "Build configuration failed for $BUILD_TARGET"
        info "Available boards can be listed with: ./waf list_boards"
        exit 1
    fi

    # Build ArduPlane for CubeOrange
    log "Building ArduPlane for CubeOrange (this may take 5-10 minutes)..."
    if ./waf "$VEHICLE"; then
        success "ArduPlane build completed successfully"

        # Create firmware directory and copy files
        mkdir -p "$FIRMWARE_DIR"

        # Copy the built firmware files
        local build_dir="build/$BUILD_TARGET/bin"
        if [[ -d "$build_dir" ]]; then
            cp "$build_dir"/*.apj "$FIRMWARE_DIR"/ 2>/dev/null || warn "No .apj files found"
            cp "$build_dir"/*.hex "$FIRMWARE_DIR"/ 2>/dev/null || warn "No .hex files found"
            cp "$build_dir"/*.bin "$FIRMWARE_DIR"/ 2>/dev/null || warn "No .bin files found"
            success "Firmware files copied to $FIRMWARE_DIR"
        fi
    else
        error "ArduPlane build failed. Check the logs above."
        info "You can try running './waf distclean' and './waf configure --board $BUILD_TARGET' manually"
        exit 1
    fi
}

setup_path_environment() {
    info "Setting up PATH environment..."

    local tools_path="export PATH=\"\$HOME/ardupilot/Tools/autotest:\$PATH\""
    local shell_files=("$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.profile")

    # Add to all common shell configuration files
    for shell_file in "${shell_files[@]}"; do
        add_to_path "$tools_path" "$shell_file"
    done

    # Also add to current shell rc
    add_to_path "$tools_path" "$(get_shell_rc)"

    success "PATH environment configured"
}

handle_mojave_specifics() {
    if [[ $MAJOR_VERSION -eq 10 && $MINOR_VERSION -eq 14 ]]; then
        warn "macOS Mojave detected - you may need to install SDK headers if you encounter build issues"
        info "If needed, run: open /Library/Developer/CommandLineTools/Packages/macOS_SDK_headers_for_macOS_10.14.pkg"
    fi
}

test_installation() {
    info "Testing ArduPilot installation and build..."

    # Source the shell rc to get updated PATH
    local shell_rc
    shell_rc="$(get_shell_rc)"

    if [[ -f "$shell_rc" ]]; then
        # shellcheck source=/dev/null
        source "$shell_rc" 2>/dev/null || true
    fi

    # Test sim_vehicle.py
    if command_exists sim_vehicle.py; then
        success "sim_vehicle.py is available in PATH"
    else
        warn "sim_vehicle.py not found in PATH. You may need to restart your terminal."
    fi

    # Test MAVProxy
    if command_exists mavproxy.py; then
        success "MAVProxy is available"
    else
        warn "MAVProxy not found in PATH"
    fi

    # Check if firmware was built successfully
    if [[ -d "$FIRMWARE_DIR" ]] && [[ -n "$(find "$FIRMWARE_DIR" -name "*.apj" -o -name "*.hex" 2>/dev/null)" ]]; then
        success "ArduPlane firmware for CubeOrange built successfully"
        info "Firmware files located in: $FIRMWARE_DIR"
    else
        warn "Firmware files not found. Build may have failed."
    fi
}

show_usage_instructions() {
    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}           ArduPilot Installation Complete - CubeOrange Ready!${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}ArduPlane Firmware Built for CubeOrange:${NC}"
    echo -e "${GREEN}•${NC} Target: ${BLUE}$BUILD_TARGET${NC}"
    echo -e "${GREEN}•${NC} Firmware location: ${BLUE}$FIRMWARE_DIR${NC}"
    echo ""

    if [[ -d "$FIRMWARE_DIR" ]]; then
        echo -e "${YELLOW}${BOLD}Available Firmware Files:${NC}"
        find "$FIRMWARE_DIR" -name "*.apj" -o -name "*.hex" -o -name "*.bin" | while read -r file; do
            echo -e "${GREEN}•${NC} $(basename "$file")"
        done
        echo ""
    fi

    echo -e "${YELLOW}${BOLD}Next Steps for CubeOrange:${NC}"
    echo ""
    echo -e "${GREEN}1.${NC} Upload firmware to CubeOrange using Mission Planner or QGroundControl:"
    echo -e "   ${BLUE}Use the .apj file for automatic upload${NC}"
    echo -e "   ${BLUE}Use the .hex file for manual flashing${NC}"
    echo ""
    echo -e "${GREEN}2.${NC} For SITL testing, restart your terminal or run:"
    echo -e "   ${BLUE}source $(get_shell_rc)${NC}"
    echo ""
    echo -e "${GREEN}3.${NC} Test ArduPlane SITL simulation:"
    echo -e "   ${BLUE}cd $ARDUPILOT_DIR/ArduPlane${NC}"
    echo -e "   ${BLUE}sim_vehicle.py -v ArduPlane -f plane --console --map${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}Rebuilding Firmware:${NC}"
    echo -e "${GREEN}•${NC} Clean build: ${BLUE}cd $ARDUPILOT_DIR && ./waf distclean${NC}"
    echo -e "${GREEN}•${NC} Configure: ${BLUE}./waf configure --board $BUILD_TARGET${NC}"
    echo -e "${GREEN}•${NC} Build: ${BLUE}./waf $VEHICLE${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}Other Build Targets:${NC}"
    echo -e "${GREEN}•${NC} List all boards: ${BLUE}cd $ARDUPILOT_DIR && ./waf list_boards${NC}"
    echo -e "${GREEN}•${NC} CubeOrange variants: ${BLUE}CubeOrange, CubeOrange, CubeOrange-periph${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}Useful Commands:${NC}"
    echo -e "${GREEN}•${NC} Update ArduPilot: ${BLUE}cd $ARDUPILOT_DIR && git pull && git submodule update --recursive${NC}"
    echo -e "${GREEN}•${NC} Build for other vehicles:"
    echo -e "   ${BLUE}./waf copter${NC} (ArduCopter)"
    echo -e "   ${BLUE}./waf rover${NC} (ArduRover)"
    echo -e "   ${BLUE}./waf sub${NC} (ArduSub)"
    echo ""
    echo -e "${YELLOW}${BOLD}Documentation:${NC}"
    echo -e "${GREEN}•${NC} CubeOrange Guide: ${BLUE}https://ardupilot.org/copter/docs/common-thecubeorange-overview.html${NC}"
    echo -e "${GREEN}•${NC} ArduPlane Docs: ${BLUE}https://ardupilot.org/plane/${NC}"
    echo -e "${GREEN}•${NC} Building Guide: ${BLUE}https://ardupilot.org/dev/docs/building-the-code.html${NC}"
    echo ""
    echo -e "${GREEN}${BOLD}Installation log saved to: ${BLUE}$BUILD_LOG${NC}"
    echo ""
}

main() {
    # Initialize log file
    echo "ArduPilot SITL Installation Log - $(date)" > "$LOG_FILE"

    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}        ArduPlane CubeOrange Builder & SITL Installer for macOS${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    info "Starting ArduPlane CubeOrange build and SITL setup..."
    info "Target Hardware: CubeOrange Flight Controller"
    info "Vehicle: ArduPlane"
    info "macOS Version: $MACOS_VERSION"
    info "Architecture: $ARCH"
    info "Shell: $SHELL_NAME"
    info "User: $USER"
    info "Home: $HOME"
    echo ""

    # Installation steps
    check_system_requirements
    install_xcode_tools
    install_homebrew
    install_brew_packages
    setup_python
    clone_ardupilot
    run_prereqs_script
    setup_build_environment
    setup_path_environment
    handle_mojave_specifics
    test_installation

    success "ArduPlane CubeOrange build and SITL installation completed successfully!"
    show_usage_instructions
}

# Error handling
trap 'error "Installation failed at line $LINENO. Check $LOG_FILE for details."; exit 1' ERR

# Run main function
main "$@"
