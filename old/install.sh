#!/bin/bash

# =============================================================================
# Q1 Wallet Installer - a CLI wallet to manage $QUIL tokens
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
# =============================================================================

# LINUX ONLY

SCRIPT_VERSION=1.1.4
INSTALL_DIR="$HOME/q1wallet"
SYMLINK_PATH="/usr/local/bin/q1wallet"

# Color definitions
RED='\033[1;31m'      # Bright red for errors
ORANGE='\033[0;33m'   # Orange for warnings
GREEN='\033[0;32m'    # Green for success
BOLD='\033[1m'        # Bold for titles and menu
NC='\033[0m'          # No Color - reset

# Helper functions
error_message() {
    echo -e "${RED}❌ $1${NC}"
}

warning_message() {
    echo -e "${ORANGE}⚠️ $1${NC}"
}

success_message() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Check if sudo is available and user has permissions
check_sudo() {
    if ! command -v sudo &> /dev/null; then
        error_message "sudo is not installed on this system"
        return 1
    fi

    # Try to run sudo with -n flag (non-interactive) to check if we have permissions
    if ! sudo -n true 2>/dev/null; then
        # If we don't have cached credentials, ask for password
        echo "Sudo access is required to create the quick command."
        if ! sudo true; then
            error_message "Failed to obtain sudo privileges. Command creation aborted."
            return 1
        fi
    fi
    return 0
}

check_system_compatibility() {
    case "$OSTYPE" in
        "linux-gnu"*)
            case "$(uname -m)" in
                "x86_64"|"aarch64")
                    return 0 ;;
                *)
                    error_message "Unsupported Linux architecture: $(uname -m)"
                    echo "Q1 Wallet currently supports only x86_64 and aarch64 architectures."
                    exit 1
                    ;;
            esac
            ;;
        *)
            error_message "Unsupported operating system: $OSTYPE"
            echo "Q1 Wallet currently supports Linux only."
            exit 1
            ;;
    esac
}

check_existing_installation() {
    # Check if both menu.sh and wallets folder exist
    if [ -f "$INSTALL_DIR/menu.sh" ] && [ -d "$INSTALL_DIR/wallets" ]; then
        echo -e "\n${ORANGE}Existing Q1 Wallet installation detected!${NC}"
        echo "Location: $INSTALL_DIR"
        
        # Check for wallet subfolders and list them
        if [ -d "$INSTALL_DIR/wallets" ]; then
            # Use find to get only directories, one level deep
            wallet_dirs=$(find "$INSTALL_DIR/wallets" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
            if [ -n "$wallet_dirs" ]; then
                echo -e "\nExisting wallets found:"
                while IFS= read -r wallet_path; do
                    wallet_name=$(basename "$wallet_path")
                    echo "- $wallet_name"
                done <<< "$wallet_dirs"
            fi
        fi
        
        echo -e "\nPlease choose an option:"
        echo "1. Exit installation"
        echo "2. Reinstall software only (keeps wallets and configuration)"
        echo -e "3. Complete reinstall (${RED}WARNING: WILL DELETE ALL EXISTING WALLETS${NC})"
        
        while true; do
            read -p "Enter your choice (1-3): " choice
            case $choice in
                1)
                    echo "Installation cancelled"
                    exit 0
                    ;;
                2)
                    reinstall_software_only
                    return $?
                    ;;
                3)
                    confirm_full_reinstall
                    return $?
                    ;;
                *)
                    error_message "Invalid choice. Please enter 1, 2, or 3"
                    ;;
            esac
        done
    fi
    
    # No valid installation found, return false
    return 0
}

reinstall_software_only() {
    echo -e "\nReinstalling Q1 Wallet software..."
    echo "Keeping existing wallets and configuration"
    
    # Backup current wallet selection if it exists
    if [ -f "$INSTALL_DIR/.current_wallet" ]; then
        cp "$INSTALL_DIR/.current_wallet" "$INSTALL_DIR/.current_wallet.bak"
    fi
    
    # Remove everything except wallets directory
    find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 ! -name 'wallets' -exec rm -rf {} +
    
    # Restore current wallet selection if it existed
    if [ -f "$INSTALL_DIR/.current_wallet.bak" ]; then
        mv "$INSTALL_DIR/.current_wallet.bak" "$INSTALL_DIR/.current_wallet"
    fi
    
    return 0
}

confirm_full_reinstall() {
    echo -e "\n${RED}WARNING: This will delete ALL existing wallets and data in $INSTALL_DIR${NC}"
    echo "This action cannot be undone!"
    
    read -p "Do you want to proceed? (y/n): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi
    
    echo "Removing existing installation..."
    rm -rf "$INSTALL_DIR"
    
    # Create fresh installation directory
    echo "Creating fresh installation directory..."
    mkdir -p "$INSTALL_DIR"

    cd $INSTALL_DIR
    
    return 0
}

check_dependencies() {
    local deps=("curl" "unzip" "bc" "zip")
    local missing_deps=()
    
    echo "Checking required dependencies..."
    
    # Check for missing dependencies
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
            echo "❌ Missing: $dep"
        else
            echo "✅ Found: $dep"
        fi
    done
    
    # If all dependencies are present, return
    if [ ${#missing_deps[@]} -eq 0 ]; then
        success_message "All dependencies are installed!"
        return 0
    fi
    
    echo -e "\nInstalling missing dependencies: ${missing_deps[*]}"
    
    if command -v apt-get &> /dev/null; then
        echo "Using apt package manager..."
        sudo DEBIAN_FRONTEND=noninteractive apt-get update
        for dep in "${missing_deps[@]}"; do
            echo "Installing $dep..."
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$dep"
        done
    else
        error_message "This installer requires apt package manager. Please install manually: ${missing_deps[*]}"
        exit 1
    fi
    
    # Verify installation
    local failed_deps=()
    for dep in "${missing_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            failed_deps+=("$dep")
        fi
    done
    
    if [ ${#failed_deps[@]} -ne 0 ]; then
        error_message "Failed to install: ${failed_deps[*]}"
        exit 1
    fi
    
    success_message "Successfully installed all dependencies!"
}

check_wallet_exists() {
    local wallet_name="$1"
    if [ -d "wallets/$wallet_name" ]; then
        return 0  # wallet exists
    fi
    return 1  # wallet doesn't exist
}

handle_wallet_creation() {
    if [[ -n "$wallet_name" ]]; then
        # For software-only reinstall, check if wallet already exists
        if [ -d "wallets/$wallet_name" ]; then
            warning_message "Wallet '$wallet_name' already exists"
            read -p "Would you like to create a different wallet? (y/n): " create_different
            if [[ $create_different =~ ^[Yy]$ ]]; then
                while true; do
                    echo
                    read -p "Enter new wallet name (a-z, 0-9, -, _): " wallet_name
                    
                    if [[ ! "$wallet_name" =~ ^[a-z0-9_-]+$ ]]; then
                        error_message "Invalid wallet name. Use only lowercase letters, numbers, dashes (-) and underscores (_)."
                        continue
                    fi
                    
                    if check_wallet_exists "$wallet_name"; then
                        error_message "Wallet '$wallet_name' already exists. Please choose a different name."
                        continue
                    fi
                    break
                done
            else
                wallet_name=""  # Clear wallet_name if user doesn't want to create a different one
                return
            fi
        fi
        
        echo "Creating wallet: $wallet_name"
        mkdir -p "wallets/$wallet_name/.config"
        echo "$wallet_name" > .current_wallet
        success_message "Wallet '$wallet_name' created successfully"
    fi
}

setup_symlink() {
    echo -e "\nQuick command setup"
    echo "-------------------"
    echo "Create a 'q1wallet' quick commands to call the menu."
    echo "Requires sudo access to create the command in /usr/local/bin"
    
    read -p "Would you like to set up the quick command? (y/n): " setup_cmd
    if [[ ! $setup_cmd =~ ^[Yy]$ ]]; then
        echo "Skipping quick command setup."
        echo "You can still use the wallet by running: $INSTALL_DIR/menu.sh"
        return 0
    fi
    
    # Check if symlink already exists with correct target
    if [ -L "$SYMLINK_PATH" ]; then
        current_target=$(readlink -f "$SYMLINK_PATH")
        if [ "$current_target" = "$INSTALL_DIR/menu.sh" ]; then
            success_message "Command 'q1wallet' is already set up correctly"
            return 0
        fi
    fi
    
    # Check sudo access first
    if ! check_sudo; then
        error_message "Quick command creation requires sudo access"
        echo "You can still use the wallet by running: $INSTALL_DIR/menu.sh"
        return 1
    fi
    
    # First ensure /usr/local/bin exists
    if [ ! -d "/usr/local/bin" ]; then
        echo "Creating /usr/local/bin directory..."
        if ! sudo mkdir -p /usr/local/bin; then
            error_message "Failed to create /usr/local/bin directory"
            echo "You can still use the wallet by running: $INSTALL_DIR/menu.sh"
            return 1
        fi
    fi
    
    # Check if a non-symlink file exists at the target location
    if [ -e "$SYMLINK_PATH" ] && [ ! -L "$SYMLINK_PATH" ]; then
        error_message "A file already exists at $SYMLINK_PATH but is not a symlink"
        echo "Please remove it manually and run the installer again"
        return 1
    fi

    # Create or update the symlink with explicit error checking
    echo "Creating symlink to $INSTALL_DIR/menu.sh..."
    if ! sudo ln -sf "$INSTALL_DIR/menu.sh" "$SYMLINK_PATH"; then
        error_message "Failed to create quick command 'q1wallet'"
        echo "You can still use the wallet by running: $INSTALL_DIR/menu.sh"
        echo "To create the quick command later, run: sudo ln -sf $INSTALL_DIR/menu.sh $SYMLINK_PATH"
        return 1
    fi

    # Verify the symlink was created
    if [ -L "$SYMLINK_PATH" ]; then
        success_message "Command 'q1wallet' installed successfully!"
        echo "You can now run 'q1wallet' from anywhere"
        return 0
    else
        error_message "Symlink creation appeared to succeed but link not found"
        echo "You can still use the wallet by running: $INSTALL_DIR/menu.sh"
        return 1
    fi
}


# Show welcome message
clear
echo -e "
                    Q1Q1Q1\    Q1\   
                   Q1  __Q1\ Q1Q1 |  
                   Q1 |  Q1 |\_Q1 |  
                   Q1 |  Q1 |  Q1 |  
                   Q1 |  Q1 |  Q1 |  
                   Q1  Q1Q1 |  Q1 |  
                   \Q1Q1Q1 / Q1Q1Q1\ 
                    \___Q1Q\ \______|  QUILIBRIUM.ONE
                        \___|        
                              
=================================================================
             Welcome to Q1 Wallet Installer - $SCRIPT_VERSION
================================================================="

# Run initial checks
check_system_compatibility
echo
check_existing_installation
echo

# Add this section to ensure we're in the correct directory
if [ "$PWD" != "$INSTALL_DIR" ]; then
    echo "Changing to installation directory: $INSTALL_DIR"
    cd "$INSTALL_DIR" || {
        error_message "Failed to change to installation directory: $INSTALL_DIR"
        exit 1
    }
fi


check_dependencies
echo



# Ask about wallet creation
echo
read -p "Would you like to create a new wallet now? (y/n): " create_wallet
wallet_name=""

if [[ $create_wallet =~ ^[Yy]$ ]]; then
    while true; do
        echo
        read -p "Enter wallet name (no spaces): " wallet_name
        
        if [[ ! "$wallet_name" =~ ^[A-Za-z0-9_-]+$ ]]; then
            error_message "Invalid wallet name. Use only letters, numbers, dashes (-) and underscores (_)."
            continue
        fi
        
        if check_wallet_exists "$wallet_name"; then
            error_message "Wallet '$wallet_name' already exists. Please choose a different name."
            continue
        fi
        break
    done
fi

# Create directory structure
echo
echo "Creating directory structure..."
mkdir -p "wallets"

# Download the wallet script
echo "Downloading Q1 Wallet script..."
if ! curl -sS -o "menu.sh" "https://raw.githubusercontent.com/lamat1111/Q1-Wallet/main/menu.sh"; then
    error_message "Failed to download wallet script!"
    exit 1
fi
chmod +x menu.sh

# Download qclient binary
echo "Detecting system architecture..."
case "$OSTYPE" in
    "linux-gnu"*)
        release_os="linux"
        case "$(uname -m)" in
            "x86_64") release_arch="amd64" ;;
            "aarch64") release_arch="arm64" ;;
            *) error_message "Error: Unsupported system architecture ($(uname -m))"; exit 1 ;;
        esac ;;
    "darwin"*)
        release_os="darwin"
        case "$(uname -m)" in
            "x86_64") release_arch="amd64" ;;
            "arm64") release_arch="arm64" ;;
            *) error_message "Error: Unsupported system architecture ($(uname -m))"; exit 1 ;;
        esac ;;
    *) error_message "Error: Unsupported operating system ($OSTYPE)"; exit 1 ;;
esac

echo
echo "Downloading qclient for $release_os-$release_arch..."
echo "This may take some time, do not close your terminal."
echo
QCLIENT_RELEASE_URL="https://releases.quilibrium.com/qclient-release"
QUILIBRIUM_RELEASES="https://releases.quilibrium.com"

# Fetch the file list
files=$(curl -s "$QCLIENT_RELEASE_URL" | grep "$release_os-$release_arch" || true)

if [ -z "$files" ]; then
    error_message "No qclient files found for $release_os-$release_arch"
    exit 1
fi

# Download files
for file in $files; do
    echo "Downloading $file..."
    if ! curl -# -f "$QUILIBRIUM_RELEASES/$file" > "$file"; then
        error_message "Failed to download $file"
        continue
    fi
    
    # Make binary executable if it's not a signature or digest file
    if [[ ! $file =~ \.(dgst|sig)$ ]]; then
        chmod +x "$file"
    fi
done

# Create wallet if requested
if [[ -n "$wallet_name" ]]; then
    echo "Creating wallet: $wallet_name"
    mkdir -p "wallets/$wallet_name/.config"
    echo "$wallet_name" > .current_wallet
fi

# Success message
echo
success_message "Installation completed successfully!"
echo
echo "Installation details:"
echo "--------------------"
echo "Location: $(pwd)"
if [[ -n "$wallet_name" ]]; then
    echo "Wallet created: $wallet_name"
fi
echo
echo
echo "IMPORTANT SECURITY STEPS:"
echo "------------------------"
echo "1. Back up your wallet keys:"
echo "   After creating your wallet, locate the two key files in:"
echo "   $HOME/q1wallet/wallets/$wallet_name"
echo
echo "   Copy these files to an encrypted USB drive for secure storage."
echo "   DO NOT upload them online to prevent unauthorized access."
echo "   Without a backup of your wallet keys, a PC hardware failure"
echo "   could result in permanent loss of access to your tokens."
echo "   Always ensure your keys are safely backed up."
echo
echo "2. Encrypt your wallet files:"
echo "   Use the 'Encrypt Wallet' option from the menu to store your wallet files"
echo "   in a .zip archive secured with a password of your choice when you are not using the wallet."
echo "   This step is essential to protect your keys if a hacker gains access to your files."
echo
echo "By following these steps, you ensure your assets remain safe and secure."
echo
echo

if ! setup_symlink; then
    echo "To create the quick command later, run: sudo ln -sf $INSTALL_DIR/menu.sh $SYMLINK_PATH"
    echo
fi

# Launch the menu if requested
echo
read -p "Would you like to start Q1 Wallet now? (y/n): " start_now
if [[ $start_now =~ ^[Yy]$ ]]; then
    ./menu.sh
fi