#!/bin/bash
# ArduPilot SITL (Software In The Loop) Installer for macOS
# Updated for Apple Silicon (M1/M2) compatibility
# Compatible with macOS 10.14+ (Mojave and later)
# Author: Auto-generated script based on ArduPilot documentation
# Version: 2.1
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
# readonly PYTHON_VERSION=$()
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
        touch "$shell_rc"
        echo "$path_line" >> "$shell_rc"
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
    # Check for Apple Silicon specific notes
    if [[ "$ARCH" == "arm64" ]]; then
        info "Apple Silicon (M1/M2) detected - using optimized installation paths"
    else
        info "Intel Mac detected - using traditional installation paths"
    fi
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

install_gcc_arm() {
    info "Installing ARM GCC toolchain..."

    # Check if arm-none-eabi-gcc is already in PATH
    if command -v arm-none-eabi-gcc >/dev/null 2>&1; then
        info "ARM GCC toolchain is already installed: $(arm-none-eabi-gcc --version | head -1)"
        return 0
    fi

    # Set the installation directory
    local install_dir="$HOME/gcc-arm-none-eabi"
    local temp_dir="/tmp/gcc-arm-install"
    mkdir -p "$temp_dir"

    # Determine the correct download URL based on architecture
    local download_url="https://developer.arm.com/-/media/Files/downloads/gnu/14.3.rel1/binrel/arm-gnu-toolchain-14.3.rel1-darwin-arm64-arm-none-eabi.tar.xz"

    # Download the toolchain
    log "Downloading ARM GCC toolchain from $download_url..."
    if curl -L "$download_url" -o "$temp_dir/gcc-arm.tar.xz"; then
        log "Extracting ARM GCC toolchain..."
        cd "$temp_dir"
        if tar -xf gcc-arm.tar.xz; then
            log "Installing to $install_dir..."
            mkdir -p "$install_dir"
            local extracted_dir=$(find . -name "arm-gnu-toolchain-*" -type d | head -1)
            if [[ -n "$extracted_dir" ]]; then
                cp -R "$extracted_dir"/* "$install_dir/"
                chmod -R u+x "$install_dir"
                # Add to PATH
                local gcc_path_export="export PATH=\"$install_dir/bin:\$PATH\""
                add_to_path "$gcc_path_export" "$(get_shell_rc)"
                # Source immediately
                export PATH="$install_dir/bin:$PATH"
                success "ARM GCC toolchain installed to $install_dir"
                rm -rf "$temp_dir"
                return 0
            else
                error "Failed to find extracted toolchain directory"
                rm -rf "$temp_dir"
                return 1
            fi
        else
            error "Failed to extract ARM GCC toolchain"
            rm -rf "$temp_dir"
            return 1
        fi
    else
        error "Failed to download ARM GCC toolchain"
        rm -rf "$temp_dir"
        return 1
    fi
}


install_brew_packages() {
    info "Installing required Homebrew packages..."
    # Install ARM GCC with fallback methods
    install_gcc_arm

    cd $HOME

    local packages=(
        "gawk"
        "python"
        "git"
        "cmake"
        "ninja"
        "ccache"
        "opencv"
        # "genromfs"
    )

    for package in "${packages[@]}"; do
        if brew list "$package" &>/dev/null; then
            info "$package already installed"
        else
            log "Installing $package..."
            if ! brew install "$package"; then
                warn "$package installation failed, retrying..."
                if ! brew install "$package"; then
                    error "$package installation failed after retry"
                    exit 1
                fi
            fi
            success "$package installed"
        fi
    done

    # Special handling for binutils removal (Mojave compatibility)
    if brew list binutils &>/dev/null; then
        warn "Removing binutils to prevent build issues on modern macOS..."
        brew uninstall binutils || warn "Failed to remove binutils, continuing..."
    fi

    # Verify ARM GCC installation
    if command -v arm-none-eabi-gcc >/dev/null 2>&1; then
        local gcc_version
        gcc_version=$(arm-none-eabi-gcc --version | head -1)
        success "ARM GCC verified: $gcc_version"
    else
        error "ARM GCC toolchain not found in PATH after installation"
        info "You may need to restart your terminal or source your shell config"
    fi
}


setup_python() {
    info "Setting up Python environment..."
    # Use the Homebrew-installed Python
    local python_cmd="/opt/homebrew/bin/python3"
    local pip_cmd="/opt/homebrew/bin/pip3"

    # Check if Homebrew Python is available
    if ! command_exists "$python_cmd"; then
        error "Homebrew Python not found. Please install Python via Homebrew: brew install python"
        exit 1
    fi

    info "Using Python: $($python_cmd --version)"

    # Create a virtual environment
    local venv_dir="$HOME/ardupilot_venv"
    log "Creating Python virtual environment at $venv_dir..."
    $python_cmd -m venv "$venv_dir"

    # Activate the virtual environment
    log "Activating virtual environment..."
    source "$venv_dir/bin/activate"

    # Upgrade pip in the virtual environment
    log "Upgrading pip..."
    pip install --upgrade pip setuptools wheel

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
        "gnureadline"
    )

    info "Installing Python packages for ArduPilot..."
    for package in "${python_packages[@]}"; do
        log "Installing $package..."
        if pip install "$package"; then
            success "$package installed"
        else
            warn "$package installation failed, continuing..."
        fi
    done

    # Install MAVProxy
    log "Installing MAVProxy..."
    if pip install MAVProxy; then
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

    # Activate the virtual environment
    local venv_dir="$HOME/ardupilot_venv"
    source "$venv_dir/bin/activate"

    # Set the Python version for waf
    export PYTHON="$venv_dir/bin/python"

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

wrap_with_venv() {
    local venv_path="$HOME/ardupilot_venv"
    local function_name="sim_vehicle"
    local shell_rc_file=""

    # Determine the shell RC file
    if [[ "$SHELL" == *"zsh"* ]]; then
        shell_rc_file="$HOME/.zshrc"
    elif [[ "$SHELL" == *"bash"* ]]; then
        shell_rc_file="$HOME/.bash_profile"
    else
        warn "Unsupported shell: $SHELL. Adding function to ~/.profile instead."
        shell_rc_file="$HOME/.profile"
    fi

    # Define the Bash function to add to the RC file
    local bash_function="
$function_name () {
    source \"$venv_path/bin/activate\"
    sim_vehicle.py \"\$@\"
}
"

    # Check if the function already exists in the RC file
    if grep -q "function $function_name" "$shell_rc_file"; then
        info "Function '$function_name' already exists in $shell_rc_file. Skipping..."
    else
        # Add the function to the RC file
        echo "$bash_function" >> "$shell_rc_file"
        success "Added function '$function_name' to $shell_rc_file."
    fi

    # Inform the user to reload the shell
    info "Please reload your shell with 'source $shell_rc_file' or restart your terminal."
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
    echo -e "${YELLOW}${BOLD}Troubleshooting ARM GCC Issues:${NC}"
    echo -e "${GREEN}•${NC} If ARM GCC not found: ${BLUE}brew install gcc-arm-none-eabi${NC}"
    echo -e "${GREEN}•${NC} Alternative method: ${BLUE}brew tap ArmMbed/homebrew-formulae && brew install arm-none-eabi-gcc${NC}"
    echo -e "${GREEN}•${NC} Manual installation: Visit ${BLUE}https://developer.arm.com/tools-and-software/open-source-software/developer-tools/gnu-toolchain/gnu-rm${NC}"
    echo ""
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
    echo -e "${GREEN}${BOLD}Installation log saved to: ${BLUE}$LOG_FILE${NC}"
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
    wrap_with_venv
    success "ArduPlane CubeOrange build and SITL installation completed successfully!"
    show_usage_instructions
}

# Error handling
trap 'error "Installation failed at line $LINENO. Check $LOG_FILE for details."; exit 1' ERR

# Run main function
main "$@"
