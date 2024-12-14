# Q1 CLI Wallet

Q1 Wallet is a user-friendly menu interface for managing QUIL tokens using Quilibrium's qclient. It provides an easy-to-use command-line interface for common token operations without needing to remember complex commands.

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

## Installation

1. **Quick Installation**
   ```bash
   curl -s https://raw.githubusercontent.com/lamat1111/Q1-Wallet/main/install.sh | bash
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
   ```

## System Compatibility

The script is currently compatible with:

- **Linux**
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

## Disclaimer

Q1 Wallet is unofficial community software provided as-is. Always verify transactions carefully and keep your wallet information secure.