#!/bin/bash

set -e  # Exit on error

echo "🟢 Starting macOS setup script..."

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

cd ~

# --- Step 0: Install required packages ---
REQUIRED_PACKAGES=("git" "curl" "unzip" "openjdk@17")

echo "📦 Installing required packages..."
brew install "${REQUIRED_PACKAGES[@]}"

# Set up Java 17
echo "☕ Setting up Java 17..."
if ! grep -q 'export JAVA_HOME=' ~/.zshrc 2>/dev/null; then
    echo 'export JAVA_HOME="$(/opt/homebrew/bin/brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home"' >> ~/.zshrc
    echo 'export PATH="$JAVA_HOME/bin:$PATH"' >> ~/.zshrc
fi
export JAVA_HOME="$(/opt/homebrew/bin/brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

# --- Step 1: Install Pixi if not present ---
if ! command -v pixi &> /dev/null; then
  echo "📦 Installing Pixi..."
  curl -fsSL https://pixi.sh/install.sh | sh
  export PATH="$HOME/.pixi/bin:$PATH"

  # Add to shell config (using .zshrc for macOS default shell)
  if ! grep -q 'export PATH="$HOME/.pixi/bin:$PATH"' "$HOME/.zshrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.pixi/bin:$PATH"' >> "$HOME/.zshrc"
    echo "✅ Pixi path added to .zshrc"
  fi
else
  echo "✅ Pixi already installed."
fi

# --- Step 2: Clone GitHub Repos and run pixi install ---
REPOS=(
  "git@github.com:AIVE-Systems/mavlink_dds_compatibility_node.git"
  # Add more repositories here
)

for REPO_URL in "${REPOS[@]}"; do
  REPO_NAME=$(basename "$REPO_URL" .git)

  if [ -d "$REPO_NAME" ]; then
    echo "📁 Repo '$REPO_NAME' already exists. Skipping clone."
  else
    echo "📥 Cloning $REPO_URL..."
    git clone --recurse-submodules "$REPO_URL"
  fi

  echo "📦 Installing dependencies in $REPO_NAME..."
  cd "$REPO_NAME"
  pixi install
  cd ..
done

# --- Step 3: Download zenohd router ---
ZENOH_DIR="zenoh"
ZENOH_BIN="${ZENOH_DIR}/zenohd"

# Determine architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
  ZENOH_ARCH="aarch64-apple-darwin"
else
  ZENOH_ARCH="x86_64-apple-darwin"
fi

ZENOH_URL="https://www.eclipse.org/downloads/download.php?file=/zenoh/zenoh/latest/zenoh-1.5.0-x86_64-unknown-linux-gnu-standalone.zip&mirror_id=1260"

if [ -f "$ZENOH_BIN" ]; then
  echo "✅ zenohd already exists at $ZENOH_BIN. Skipping download."
else
  echo "🌐 Downloading zenohd router for macOS ($ARCH)..."
  mkdir -p "$ZENOH_DIR"
  curl -L "$ZENOH_URL" -o "$ZENOH_DIR/zenohd.zip"

  echo "📦 Unzipping zenohd..."
  unzip -o "$ZENOH_DIR/zenohd.zip" -d "$ZENOH_DIR"
  chmod +x "$ZENOH_BIN"
  echo "✅ zenohd ready at $ZENOH_BIN"
fi

echo "🎉 Setup complete for macOS!"
echo "Please restart your terminal or run 'source ~/.zshrc' to use the new environment."
