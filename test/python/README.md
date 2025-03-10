# Q1 CLI Wallet (Python Edition)

THIS EDITION OF THE Q1 WALLET IS NOT MAINTAINED - USE ONLY FOR TESTING PURPOSES

Q1 Wallet (Python Edition) is a user-friendly, cross-platform command-line interface for managing QUIL tokens using Quilibrium's `qclient`. It replaces the original Bash script with a Python implementation, offering the same functionality with improved compatibility across Linux, macOS, and Windows.
Tested on Windows WSL adn macOS

This is unofficial community software provided as-is. Always verify transactions carefully and keep your wallet information secure. The current version is still in BETA—use it cautiously and report any issues.

![Q1 Wallet interface](https://i.imgur.com/QpwuO6k.png)

## What is Q1 Wallet?

Q1 Wallet is a Python script that wraps Quilibrium’s `qclient`, providing a menu-driven interface for:
- Checking balances and addresses
- Managing multiple wallets
- Handling token transactions
- Coin operations (merging, splitting)
- Wallet encryption/decryption

## Features

The menu includes the following options:

1. **Basic Operations**
   - Check balance / address
   - Create transactions
   - View individual coins
   - Merge coins
   - Split coins

2. **Wallet Management**
   - Create new wallets
   - Switch between wallets
   - Encrypt/decrypt wallets
   - Delete wallets

3. **Security and Updates**
   - Security settings
   - Check for updates
   - Help documentation

## Installation

### Linux
```bash
cd && mkdir -p q1wallet && cd q1wallet
curl -sSL https://raw.githubusercontent.com/lamat1111/Q1-Wallet/main/test/install.py -o install.py
chmod +x install.py
python3 install.py
```

### macOS
Ensure Python 3 and the required modeules are installed:
```bash
brew install python3
python3 -m venv venv && source venv/bin/activate && pip install requests colorama
```
Install:
```bash
cd && mkdir -p q1wallet && cd q1wallet
curl -sSL https://raw.githubusercontent.com/lamat1111/Q1-Wallet/main/test/python/install.py -o install.py
chmod +x install.py
python3 install.py
```

### Windows (Native)
Do not use. The qclient binary does not exist for Windows yet!

Install Python 3 from python.org (check "Add Python to PATH").
Open Command Prompt or PowerShell:
```bash
cd %USERPROFILE% && mkdir q1wallet && cd q1wallet
curl -O https://raw.githubusercontent.com/lamat1111/Q1-Wallet/main/test/python/install.py
python install.py
```

### Windows (WSL)
Enable WSL:
In PowerShell (as Administrator):
```powershell
wsl --install
```
Restart, then open "Ubuntu" from Start Menu and set up username/password.
Update:
```bash
sudo apt update && sudo apt upgrade -y
```
Install:
```bash
cd && mkdir -p q1wallet && cd q1wallet
curl -sSL https://raw.githubusercontent.com/lamat1111/Q1-Wallet/main/test/python/install.py -o install.py
chmod +x install.py
python3 install.py
```

## Important Security Steps (Post-Installation)
After creating your wallet, back up the key files in:  
Linux/macOS: `$HOME/q1wallet/wallets/wallet_name`  
Windows: `%USERPROFILE%\q1wallet\wallets\wallet_name`

Store these securely on an encrypted USB drive and do not upload online. Without a backup, hardware failure could lead to permanent token loss. Use the "Encrypt Wallet" menu option to secure your wallet files with a password when not in use.

## System Compatibility
- **Linux**: x86_64 (amd64), aarch64 (arm64)
- **macOS**: x86_64 (amd64), arm64 (Apple Silicon)
- **Windows**: x86_64/amd64 (Native or WSL) - The qclient binary does not exist for native Windows yet!

## Requirements:
- Python 3.6+ with pip  
- Internet connection (for updates and qclient download)  
- requests and colorama modules (installed automatically)

## Important Notes
- Auto-downloads the correct qclient for your system (e.g., qclient-*-linux-amd64, qclient-*-windows-amd64.exe).
- Wallets are stored in INSTALL_DIR/wallets/ (default: ~/q1wallet or %USERPROFILE%\q1wallet).
- Supports multiple wallets with switching.
- Built-in .zip encryption (no external tools needed).
- Updates fetched from GitHub.

## Using Q1 Wallet with a Quilibrium Node
Q1 Wallet is standalone:
- **No Node**: Works out of the box.  
- **With Node**: Doesn’t recognize node keys by default. Copy them to INSTALL_DIR/wallets/wallet_name/ to use.  
Alternative: Use the Q1 Node Menu (Linux, $HOME/ceremonyclient) with options 14/15:  
[Q1 Node Quickstart Menu](https://docs.quilibrium.one/start/q1-node-quickstart-menu)

## Enhancing Usability
Ideas to improve this terminal-based wallet:  
- **Standalone Executable**: Package with pyinstaller for a double-clickable app.  
- **Enhanced Terminal**: Uses colorama (implemented); could add prompt_toolkit for autocomplete.  
- **Bundled Emulator**: Include a lightweight terminal (e.g., Mintty).  
- **Minimal TUI**: Use npyscreen for arrow-key navigation.  
See this [ChatGPT discussion](https://chatgpt.com/share/6761ae54-d1cc-8007-b3f8-3cfcf66b8551) for more details.

## License
GNU Affero General Public License
