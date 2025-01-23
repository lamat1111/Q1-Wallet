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

1. **Quick Installation**
   
   ```bash
   # This will install in the folder ~/q1wallet

   cd && \
   mkdir -p ~/q1wallet && \
   curl -sSL "https://raw.githubusercontent.com/lamat1111/Q1-Wallet/main/install.sh" -o ~/q1wallet/install.sh && \
   chmod +x ~/q1wallet/install.sh && \
   ~/q1wallet/install.sh
   ```

2. **Manual Installation**
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
   - Follow the Linux Installation method above
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
