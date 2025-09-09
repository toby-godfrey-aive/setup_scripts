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

---

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
