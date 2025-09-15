#!/bin/bash
# ArduPilot SITL (Software In The Loop) Installer for macOS
# Updated for Apple Silicon (M1/M2) compatibility
# Compatible with macOS 10.14+ (Mojave and later)
# Author: Auto-generated script based on ArduPilot documentation
# Version: 2.1
set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Trap errors globally
trap 'error_handler $LINENO $?' ERR

error_handler() {
    local line=$1
    local code=$2
    echo -e "${RED}[FATAL]${NC} Script failed at line ${YELLOW}${line}${NC} with exit code ${RED}${code}${NC}"
    echo -e "${YELLOW}Check the log file for details: ${BLUE}$LOG_FILE${NC}"
    exit $code
}

# Colours and formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Colour
readonly BOLD='\033[1m'

# Configuration
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
log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"; }
info() { echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$LOG_FILE"; }
command_exists() { command -v "$1" >/dev/null 2>&1; }

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
    if [[ $MAJOR_VERSION -lt 10 ]] || [[ $MAJOR_VERSION -eq 10 && $MINOR_VERSION -lt 14 ]]; then
        error "macOS 10.14 (Mojave) or later required. Current version: $MACOS_VERSION"
        exit 1
    fi
    success "macOS version $MACOS_VERSION is supported"
    info "Architecture: $ARCH"
    info "Shell: $SHELL_NAME"
    if [[ "$ARCH" == "arm64" ]]; then
        info "Apple Silicon (M1/M2) detected - using optimised installation paths"
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
        return 1
    else
        success "Xcode Command Line Tools already installed"
    fi
}

install_homebrew() {
    info "Checking Homebrew installation..."
    if ! command_exists brew; then
        log "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
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
    if command -v arm-none-eabi-gcc >/dev/null 2>&1; then
        info "ARM GCC toolchain is already installed: $(arm-none-eabi-gcc --version | head -1)"
        return 0
    fi
    local install_dir="$HOME/gcc-arm-none-eabi"
    local temp_dir="/tmp/gcc-arm-install"
    mkdir -p "$temp_dir"
    local download_url="https://developer.arm.com/-/media/Files/downloads/gnu/14.3.rel1/binrel/arm-gnu-toolchain-14.3.rel1-darwin-arm64-arm-none-eabi.tar.xz"
    log "Downloading ARM GCC toolchain from $download_url..."
    if curl -L "$download_url" -o "$temp_dir/gcc-arm.tar.xz"; then
        log "Extracting ARM GCC toolchain..."
        cd "$temp_dir"
        if tar -xf gcc-arm.tar.xz; then
            log "Installing to $install_dir..."
            mkdir -p "$install_dir"
            local extracted_dir
            extracted_dir=$(find . -name "arm-gnu-toolchain-*" -type d | head -1)
            if [[ -n "$extracted_dir" ]]; then
                cp -R "$extracted_dir"/* "$install_dir/"
                chmod -R u+x "$install_dir"
                local gcc_path_export="export PATH=\"$install_dir/bin:\$PATH\""
                add_to_path "$gcc_path_export" "$(get_shell_rc)"
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
    install_gcc_arm || return 1
    cd "$HOME"
    local packages=( "gawk" "python" "git" "cmake" "ninja" "ccache" "opencv" )
    for package in "${packages[@]}"; do
        if brew list "$package" &>/dev/null; then
            info "$package already installed"
        else
            log "Installing $package..."
            if ! brew install "$package"; then
                warn "$package installation failed, retrying..."
                if ! brew install "$package"; then
                    error "$package installation failed after retry"
                    return 1
                fi
            fi
            success "$package installed"
        fi
    done
    if brew list binutils &>/dev/null; then
        warn "Removing binutils to prevent build issues on modern macOS..."
        brew uninstall binutils || warn "Failed to remove binutils, continuing..."
    fi
    if command -v arm-none-eabi-gcc >/dev/null 2>&1; then
        local gcc_version
        gcc_version=$(arm-none-eabi-gcc --version | head -1)
        success "ARM GCC verified: $gcc_version"
    else
        error "ARM GCC toolchain not found in PATH after installation"
        info "You may need to restart your terminal or source your shell config"
        return 1
    fi
}

setup_python() {
    info "Setting up Python environment..."
    local python_cmd="/opt/homebrew/bin/python3"
    if ! command_exists "$python_cmd"; then
        error "Homebrew Python not found. Please install Python via Homebrew: brew install python"
        return 1
    fi
    info "Using Python: $($python_cmd --version)"
    local venv_dir="$HOME/ardupilot_venv"
    log "Creating Python virtual environment at $venv_dir..."
    $python_cmd -m venv "$venv_dir"
    log "Activating virtual environment..."
    source "$venv_dir/bin/activate"
    log "Upgrading pip..."
    pip install --upgrade pip setuptools wheel
    local python_packages=( "empy" "pyserial" "pymavlink" "future" "lxml" "pexpect" "matplotlib" "numpy" "psutil" "intelhex" "geocoder" "requests" "paramiko" "pynmea2" "wxpython" "billiard" "gnureadline" )
    info "Installing Python packages for ArduPilot..."
    for package in "${python_packages[@]}"; do
        log "Installing $package..."
        if pip install "$package"; then
            success "$package installed"
        else
            warn "$package installation failed, continuing..."
        fi
    done
    log "Installing MAVProxy..."
    if pip install MAVProxy; then
        success "MAVProxy installed successfully"
    else
        error "MAVProxy installation failed"
        return 1
    fi
}

clone_ardupilot() {
    info "Setting up ArduPilot source code..."
    if [[ -d "$ARDUPILOT_DIR" ]]; then
        log "Updating existing ArduPilot repository..."
        cd "$ARDUPILOT_DIR"
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
        rm -f "$HOME/prereqs_errors.log"
    else
        warn "Prerequisites script not found at $prereqs_script"
    fi
}

setup_build_environment() {
    info "Setting up build environment for ArduPlane on CubeOrange..."
    cd "$ARDUPILOT_DIR"
    local venv_dir="$HOME/ardupilot_venv"
    source "$venv_dir/bin/activate"
    export PYTHON="$venv_dir/bin/python"
    log "Cleaning previous builds..."
    ./waf distclean
    log "Configuring build system for CubeOrange target..."
    if ./waf configure --board "$BUILD_TARGET"; then
        success "Build system configured for $BUILD_TARGET"
    else
        error "Build configuration failed for $BUILD_TARGET"
        info "Available boards can be listed with: ./waf list_boards"
        return 1
    fi
    log "Building ArduPlane for CubeOrange (this may take 5-10 minutes)..."
    if ./waf "$VEHICLE"; then
        success "ArduPlane build completed successfully"
        mkdir -p "$FIRMWARE_DIR"
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
        return 1
    fi
}

wrap_with_venv() {
    local venv_path="$HOME/ardupilot_venv"
    local function_name="sim_vehicle_venv"
    local shell_rc_file=""
    if [[ "$SHELL" == *"zsh"* ]]; then
        shell_rc_file="$HOME/.zshrc"
    elif [[ "$SHELL" == *"bash"* ]]; then
        shell_rc_file="$HOME/.bash_profile"
    else
        warn "Unsupported shell: $SHELL. Adding function to ~/.profile instead."
        shell_rc_file="$HOME/.profile"
    fi
    local bash_function="
$function_name() {
    source \"$venv_path/bin/activate\"
    command sim_vehicle.py \"\$@\"
}
"
    if grep -q "function $function_name" "$shell_rc_file"; then
        info "Function '$function_name' already exists in $shell_rc_file. Skipping..."
    else
        echo "$bash_function" >> "$shell_rc_file"
        success "Added function '$function_name' to $shell_rc_file."
    fi
    info "Please reload your shell with 'source $shell_rc_file' or restart your terminal."
}

setup_path_environment() {
    info "Setting up PATH environment..."
    local tools_path="export PATH=\"\$HOME/ardupilot/Tools/autotest:\$PATH\""
    local shell_files=("$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.profile")
    for shell_file in "${shell_files[@]}"; do
        add_to_path "$tools_path" "$shell_file"
    done
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
    local shell_rc
    shell_rc="$(get_shell_rc)"
    if [[ -f "$shell_rc" ]]; then
        source "$shell_rc" 2>/dev/null || true
    fi
    if command_exists sim_vehicle.py; then
        success "sim_vehicle.py is available in PATH"
    else
        warn "sim_vehicle.py not found in PATH. You may need to restart your terminal."
    fi
    if command_exists mavproxy.py; then
        success "MAVProxy is available"
    else
        warn "MAVProxy not found in PATH"
    fi
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
    echo -e "${GREEN}1.${NC} Upload firmware to CubeOrange using Mission Planner (Windows) or QGroundControl (macOS/Linux)"
    echo -e "${GREEN}2.${NC} Use the firmware file from: ${BLUE}$FIRMWARE_DIR${NC}"
    echo -e "${GREEN}3.${NC} Connect CubeOrange via USB and follow ground station instructions"
    echo ""
    echo -e "${YELLOW}${BOLD}Usage Tips:${NC}"
    echo ""
    echo -e "${GREEN}•${NC} Start SITL simulation with virtual environment:"
    echo -e "    ${CYAN}sim_vehicle_venv -v ArduPlane${NC}"
    echo ""
    echo -e "${GREEN}•${NC} Run MAVProxy directly (after activating venv):"
    echo -e "    ${CYAN}mavproxy.py --master tcp:127.0.0.1:5760${NC}"
    echo ""
    echo -e "${GREEN}•${NC} Source environment in a new terminal session:"
    echo -e "    ${CYAN}source $(get_shell_rc)${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

main() {
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}       ArduPilot SITL Installer for macOS (CubeOrange Build)${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    log "Installation started at $(date)"
    check_system_requirements
    install_xcode_tools || exit 1
    install_homebrew
    install_brew_packages || exit 1
    setup_python || exit 1
    clone_ardupilot
    run_prereqs_script
    setup_build_environment || exit 1
    wrap_with_venv
    setup_path_environment
    handle_mojave_specifics
    test_installation
    show_usage_instructions
    log "Installation completed at $(date)"
}

main "$@"
