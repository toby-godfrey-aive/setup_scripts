# Installation Scripts

This repository provides setup scripts for macOS and Ubuntu.

The installer handles environment setup, dependencies, and optional installation of ArduPilot SITL.

## Structure

```
.
├── install.sh
├── mac
│ ├── core_macos.sh
│ ├── haris_macos.sh
│ └── ardupilot_sitl_macos.sh
└── ubuntu
├── core_ubuntu.sh
├── haris_ubuntu.sh
└── ardupilot_sitl_ubuntu.sh
```

- `core_*.sh` – installs required packages, tools, and dependencies.
- `haris_*.sh` – sets up project-specific software.
- `ardupilot_sitl_*.sh` – installs and configures ArduPilot SITL (optional).

## Prerequisites

An SSH key must be added to GitHub before using these scripts.

Here’s a fully filled-out, renumbered version of your steps:

### 1. Check if an SSH key already exists

List the contents of your `.ssh` directory:

```bash
ls -al ~/.ssh
```

Look for a key pair such as `id_ed25519` and `id_ed25519.pub` (preferred) or `id_rsa` and `id_rsa.pub`.

If **none** exist, generate a new key.

### 2. Generate a new SSH key pair

Run the following command, replacing the email with the one associated with your GitHub account or some other useful comment:

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

If your system does not support Ed25519, use RSA:

```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

Press **Enter** to accept the default location (`~/.ssh/id_ed25519`) and optionally enter a passphrase for security.

### 3. Start the SSH agent

Ensure the SSH agent is running:

```bash
eval "$(ssh-agent -s)"
```

Then add your newly created key to the agent:

```bash
ssh-add ~/.ssh/id_ed25519
```

### 4. Add the key to GitHub

Copy the public key to your clipboard:

- On **Linux**:

  ```bash
  cat ~/.ssh/id_ed25519.pub | xclip -selection clipboard
  ```

- On **macOS**:

  ```bash
  pbcopy < ~/.ssh/id_ed25519.pub
  ```

Then:

1. Go to [GitHub → Settings → SSH and GPG keys](https://github.com/settings/keys).
2. Click **New SSH key**.
3. Paste the copied key into the **Key** field.
4. Give the key a title.
5. Click **Add SSH key**.

### 5. Check access

Test that the key is working with GitHub:

```bash
ssh -T git@github.com
```

You should see:

```
Hi [username]! You've successfully authenticated, but GitHub does not provide shell access.
```

## Usage

Make the installer executable:

```bash
chmod +x install.sh
```

Run the installer:

```bash
./install.sh
```

### Optional SITL Installation

To include ArduPilot SITL in the setup:

```bash
./install.sh --sitl
```

### Help

```bash
./install.sh --help
```

## Notes

- macOS defaults to `zsh`; the installer appends environment variables to `~/.zshrc`.
- Restart your shell or run `source ~/.zshrc` after installation to ensure changes take effect.

Here’s a troubleshooting section you can append to your README:

## Troubleshooting

### **Command not found after installation**

Ensure you restart your terminal session or run `source ~/.zshrc` (macOS) or `source ~/.bashrc` (Ubuntu) so updated environment variables take effect.

### **Homebrew not found on macOS**

If `brew` is not available after installation, verify that Homebrew is on your PATH:

```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
```

Then re-run `./install.sh`.

### **Pixi not found**

If `pixi` cannot be found, make sure `$HOME/.pixi/bin` is on your PATH:

```bash
export PATH="$HOME/.pixi/bin:$PATH"
```

### **Java issues (macOS)**

If tools cannot find Java, confirm that `JAVA_HOME` is correctly set:

```bash
echo $JAVA_HOME
```

It should point to the Java 17 installation under Homebrew.

### **Permission denied when running scripts**

Make sure scripts are executable:

```bash
chmod +x install.sh mac/*.sh ubuntu/*.sh
```

### **Git clone errors (SSH)**

If cloning via SSH fails, ensure your SSH keys are added to GitHub:

```bash
ssh -T git@github.com
```

### **ArduPilot SITL build errors**

Ensure all build dependencies are installed (on Ubuntu: `build-essential`, `python3-dev`, etc.). If errors persist, try running the SITL script manually to inspect logs.
