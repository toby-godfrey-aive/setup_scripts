#!/bin/bash

set -e  # Exit on error

echo "🟢 Starting Ubuntu setup script..."

sudo apt-get update
sudo apt-get upgrade -y

cd ~

# --- Step 0: Check for required commands ---
REQUIRED_CMDS=("git" "curl" "unzip" "openjdk-17-jre" "openjdk-17-jdk")

for CMD in "${REQUIRED_CMDS[@]}"; do
  if ! command -v "$CMD" &> /dev/null; then
    echo "❌ Error: '$CMD' is not installed."
    echo "   Installing it with apt..."
    sudo apt-get update
    sudo apt-get install -y "$CMD"
  fi
done

# --- Step 1: Install Pixi if not present ---
if ! command -v pixi &> /dev/null; then
  echo "📦 Installing Pixi..."
  curl -fsSL https://pixi.sh/install.sh | sh
  export PATH="$HOME/.pixi/bin:$PATH"

  # Add to shell config
  if ! grep -q 'export PATH="$HOME/.pixi/bin:$PATH"' "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/.pixi/bin:$PATH"' >> "$HOME/.bashrc"
    echo "✅ Pixi path added to .bashrc"
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
  git submodule update --init --recursive
  pixi install
  cd ..
done

# --- Step 3: Download zenohd router ---
ZENOH_DIR="zenoh"
ZENOH_BIN="${ZENOH_DIR}/zenohd"
ZENOH_URL="https://download.eclipse.org/zenoh/zenoh/latest/zenoh-1.5.0-x86_64-unknown-linux-gnu-standalone.zip"

if [ -f "$ZENOH_BIN" ]; then
  echo "✅ zenohd already exists at $ZENOH_BIN. Skipping download."
else
  echo "🌐 Downloading zenohd router..."
  mkdir -p "$ZENOH_DIR"
  curl -L "$ZENOH_URL" -o "$ZENOH_DIR/zenohd.zip"

  echo "📦 Unzipping zenohd..."
  unzip -o "$ZENOH_DIR/zenohd.zip" -d "$ZENOH_DIR"
  chmod +x "$ZENOH_BIN"
  echo "✅ zenohd ready at $ZENOH_BIN"
fi

echo "🎉 Setup complete for Ubuntu!"
