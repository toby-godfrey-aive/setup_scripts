#!/bin/bash
# Script to check if SSH authentication with GitHub is already set up.
# If not, generate a key if missing, start ssh-agent if needed, and guide user. (macOS version)

set -e

# Colours
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
NC="\033[0m" # reset

USER_NAME="$(whoami)"
KEY_DIR="$HOME/.ssh"
KEY_PATH_ED="$KEY_DIR/id_ed25519"
KEY_PATH_RSA="$KEY_DIR/id_rsa"
PUB_KEY_PATH=""

echo -e "${CYAN}>>> Checking if SSH authentication with GitHub already works...${NC}"
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    echo -e "${GREEN}✅ SSH authentication with GitHub is already configured.${NC}"
    exit 0
fi

echo -e "${YELLOW}⚠️  SSH authentication not yet configured. Proceeding with setup...${NC}"

echo -e "${CYAN}>>> Checking for existing SSH keys...${NC}"
if [ -f "${KEY_PATH_ED}.pub" ]; then
    echo -e "${GREEN}Found existing Ed25519 key:${NC} ${KEY_PATH_ED}.pub"
    PUB_KEY_PATH="${KEY_PATH_ED}.pub"
    KEY_PATH="$KEY_PATH_ED"
elif [ -f "${KEY_PATH_RSA}.pub" ]; then
    echo -e "${GREEN}Found existing RSA key:${NC} ${KEY_PATH_RSA}.pub"
    PUB_KEY_PATH="${KEY_PATH_RSA}.pub"
    KEY_PATH="$KEY_PATH_RSA"
else
    echo -e "${YELLOW}No SSH key found. Generating a new one...${NC}"
    if ssh-keygen -t ed25519 -C "$USER_NAME" -f "$KEY_PATH_ED" -N "" 2>/dev/null; then
        echo -e "${GREEN}Generated new Ed25519 key at${NC} $KEY_PATH_ED"
        KEY_PATH="$KEY_PATH_ED"
        PUB_KEY_PATH="${KEY_PATH}.pub"
    else
        echo -e "${YELLOW}Ed25519 not supported. Falling back to RSA...${NC}"
        ssh-keygen -t rsa -b 4096 -C "$USER_NAME" -f "$KEY_PATH_RSA" -N ""
        KEY_PATH="$KEY_PATH_RSA"
        PUB_KEY_PATH="${KEY_PATH}.pub"
    fi
fi

echo -e "${CYAN}>>> Checking ssh-agent...${NC}"
if pgrep -u "$USER" ssh-agent > /dev/null; then
    echo -e "${GREEN}ssh-agent is already running. Reusing it.${NC}"
else
    echo -e "${YELLOW}No ssh-agent found. Starting a new one...${NC}"
    eval "$(ssh-agent -s)" > /dev/null
fi

echo -e "${CYAN}>>> Checking if key is already loaded into ssh-agent...${NC}"
if ssh-add -l | grep -q "$KEY_PATH"; then
    echo -e "${GREEN}Key is already loaded into ssh-agent.${NC}"
else
    echo -e "${YELLOW}Adding key to ssh-agent...${NC}"
    ssh-add "$KEY_PATH"
fi

echo -e "${CYAN}>>> Preparing your public key for GitHub...${NC}"

# Copy to clipboard automatically on macOS
if command -v pbcopy &> /dev/null; then
    pbcopy < "$PUB_KEY_PATH"
    echo -e "${GREEN}✔ Public key copied to clipboard using pbcopy.${NC}"
else
    echo -e "${YELLOW}⚠ pbcopy not found. You’ll need to copy manually.${NC}"
fi

# Always print as fallback
echo -e "${YELLOW}-----------------------------------------------------------------${NC}"
cat "$PUB_KEY_PATH"
echo -e "${YELLOW}-----------------------------------------------------------------${NC}"
echo -e "${RED}⚠️  Copy the above key (if not already copied) and paste it into GitHub → Settings → SSH and GPG keys.${NC}"
echo

read -p "Press Enter once you've added the key to GitHub..."

echo -e "${CYAN}>>> Testing SSH connection to GitHub...${NC}"
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    echo -e "${GREEN}✅ SSH authentication with GitHub works!${NC}"
else
    echo -e "${RED}⚠️  Authentication failed. Make sure you added the correct key.${NC}"
    echo -e "${YELLOW}   You can retry with: ssh -T git@github.com${NC}"
fi
