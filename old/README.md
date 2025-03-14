# Q1 CLI Wallet (BETA)

Q1 Wallet is a user-friendly menu interface for managing QUIL tokens using Quilibrium's qclient. It provides an easy-to-use command-line interface for common token operations without needing to remember complex commands.

This is unofficial community software provided as-is. Always verify transactions carefully and keep your wallet information secure.
The current version is still in BETA, use carefully and report any issues.

![Q1 Wallet interface](https://i.imgur.com/QpwuO6k.png)

## What is Q1 Wallet?

Q1 Wallet is a bash script that wraps around the Quilibrium qclient, providing a menu-driven interface for:
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

## Linux Installation

### Quick Installation (recommended)

Run this snippet in your terminal:

```bash
# This will install in the folder ~/q1wallet

cd && \
mkdir -p ~/q1wallet && \
curl -sSL "https://raw.githubusercontent.com/lamat1111/Q1-Wallet/main/install.sh" -o ~/q1wallet/install.sh && \
chmod +x ~/q1wallet/install.sh && \
~/q1wallet/install.sh
```

**IMPORTANT SECURITY STEPS: DO THIS AFTER THE INSTALLATION**  

After creating your wallet, it’s highly recommended to back up the two key files located in: `$HOME/q1wallet/wallets/wallet_name` (where "wallet_name" is the name you chose for your wallet).  

Store these files securely on an encrypted USB drive and avoid uploading them online.  
Without a backup, a hardware failure on your PC could result in the permanent loss of access to your tokens. Protect your keys to ensure your assets remain safe.  

To enhance security, use the "Encrypt Wallet" option in the menu when you're not actively using your wallet(s). This feature stores your wallet(s) files in a .zip archive protected by a password of your choice.

This extra step is crucial in case a hacker gains access to your files, as it helps prevent unauthorized access to your wallet keys.

### Manual Installation
```bash
# Create directory
mkdir q1wallet && cd q1wallet

# Download the script
curl -O https://raw.githubusercontent.com/lamat1111/Q1-Wallet/main/menu.sh
chmod +x menu.sh

# Run the wallet
./menu.sh

# Optional: add a symlink "q1wallet" to call the menu
```

## Windows WSL Installation

If you already have WSL ready, simply launch it in your terminal with `wsl` and then follow the Linux Installation method above.

1. **Enable WSL**
   - Open PowerShell as Administrator
   - Run: `wsl --install`
   - Restart your computer

2. **Setup Ubuntu**
   - Open "Ubuntu" from Start Menu
   - Create username and password when prompted
   - Update system: 
     ```bash
     sudo apt update && sudo apt upgrade -y
     ```

3. **Install Q1 Wallet**
   - Follow the "Linux Quick Installation" method above
   - Launch the menu with: `cd ~/q1wallet && ./menu.sh` or simply `q1wallet`

## System Compatibility

The script is currently compatible with:

- **Linux or Windows WSL**
  - x86_64 (amd64)
  - aarch64 (arm64)

Requirements:
- Bash shell
- curl, zip
- Internet connection (for updates and qclient download)

## Important Notes

- The script automatically downloads the appropriate qclient version for your system
- All wallets are stored locally in the `wallets` subdirectory
- Multiple wallets can be created and managed
- Optional encryption for wallet storage is available via zip/unzip of the "wallets" folder
- Regular updates are provided through the GitHub repository

## Use of Q1 wallet if you are already running a Quilibrium node
Q1 Wallet is a standalone script that operates independently of a node installation. However, there are a few considerations depending on your setup:  

If you do not have a node installed, the script will work seamlessly without requiring one.  

If you do have a node installed:  
- Q1 Wallet will not recognize your current node keys because they are stored in a different location.  
- To use your node keys with Q1 Wallet, you need to copy them manually into the following folder:  
  `$HOME/q1wallet/wallets/wallet_name`  where "wallet_name" is any name you want to give to your wallet

As an alternative, if you want to manage your node QUIL, you can install the Q1 menu:  
<https://docs.quilibrium.one/start/q1-node-quickstart-menu>  

Then use **option 14** and **option 15** in the Q1 menu to handle node tokens.  

For the Q1 menu to work, ensure:  
- You are using **Linux**.  
- The node is installed in the `$HOME/ceremonyclient` folder.  
Please note that the Q1 menu does not offer the management of multiple wallets (which the Q1 wallet does).

## Enhancing Usability for the Q1Wallet

This repository contains a terminal-based menu script for creating and managing Quilibrium wallets. Below are some ideas to further improve usability, bridging the gap between a traditional CLI and a full GUI application:

1. **Executable with Embedded Script**  
   - Package the script into a standalone executable using tools like `pyinstaller` (Python).  
   - Users can launch the application by double-clicking, simplifying the experience.

2. **Enhanced Terminal Interface**  
   - Add colored output for better readability (e.g., `colorama` in Python).  
   - Use libraries like Prompt Toolkit to enable richer input handling (e.g., autocomplete, dropdowns).

3. **Bundled Terminal Emulator**  
   - Distribute the wallet with a lightweight terminal emulator (e.g., Mintty, ConEmu).  
   - Ensures a consistent user experience without requiring external terminal configurations.

4. **Minimal TUI (Text User Interface)**  
   - Use libraries like `dialog` (Bash) or `npyscreen` (Python) to create interactive menus navigable with arrow keys.

These enhancements aim to maintain the lightweight and portable nature of the script while offering a more polished and user-friendly experience.
See this [ChatGPT discussion](https://chatgpt.com/share/6761ae54-d1cc-8007-b3f8-3cfcf66b8551) for more details.

## Licence

GNU AFFERO GENERAL PUBLIC LICENSE
