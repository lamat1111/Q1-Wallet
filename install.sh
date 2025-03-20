#!/usr/bin/env bash

# =============================================================================
# Q1 Wallet - a CLI wallet to manage $QUIL tokens
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

SCRIPT_VERSION=1.1.9

# Variables
INSTALL_DIR="$HOME/q1wallet"
MENU_SCRIPT_URL="https://raw.githubusercontent.com/lamat1111/Q1-Wallet/main/menu.sh"
NODE_KEYS_DIR="$HOME/ceremonyclient/node/.config"
NODE_WALLET_DIR="$INSTALL_DIR/wallets/node_wallet"

# Color definitions (platform-agnostic)
RED='\033[1;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

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

check_sudo() {
    if ! command -v sudo &> /dev/null; then
        error_message "sudo is not installed on this system"
        return 1
    fi

    if ! sudo -n true 2>/dev/null; then
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
                    echo "Q1 Wallet currently supports only x86_64 and aarch64 architectures on Linux."
                    exit 1
                    ;;
            esac
            ;;
        "darwin"*)
            case "$(uname -m)" in
                "x86_64"|"arm64")
                    return 0 ;;
                *)
                    error_message "Unsupported macOS architecture: $(uname -m)"
                    echo "Q1 Wallet currently supports only x86_64 and arm64 architectures on macOS."
                    exit 1
                    ;;
            esac
            ;;
        *)
            error_message "Unsupported operating system: $OSTYPE"
            echo "Q1 Wallet currently supports Linux and macOS only."
            exit 1
            ;;
    esac
}

check_existing_installation() {
    if [ -f "$INSTALL_DIR/menu.sh" ] && [ -d "$INSTALL_DIR/wallets" ]; then
        echo -e "\n${ORANGE}Existing Q1 Wallet installation detected!${NC}"
        echo "Location: $INSTALL_DIR"
        
        if [ -d "$INSTALL_DIR/wallets" ]; then
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
    return 0
}

reinstall_software_only() {
    echo -e "\nReinstalling Q1 Wallet software..."
    echo "Keeping existing wallets and configuration"
    
    if [ -f "$INSTALL_DIR/.current_wallet" ]; then
        cp "$INSTALL_DIR/.current_wallet" "$INSTALL_DIR/.current_wallet.bak"
    fi
    
    find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 ! -name 'wallets' -exec rm -rf {} +
    
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
    
    echo "Creating fresh installation directory..."
    mkdir -p "$INSTALL_DIR"

    cd "$INSTALL_DIR" || exit 1
    
    return 0
}

check_dependencies() {
    local deps=("curl" "unzip" "zip" "bc")
    local missing_deps=()
    
    echo "Checking required dependencies..."
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
            echo "❌ Missing: $dep"
        else
            echo "✅ Found: $dep"
        fi
    done
    
    if [ ${#missing_deps[@]} -eq 0 ]; then
        success_message "All dependencies are installed!"
        return 0
    fi
    
    echo -e "\nInstalling missing dependencies: ${missing_deps[*]}"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if ! command -v brew &> /dev/null; then
            echo -e "${ORANGE}Homebrew is not installed. It's required to install missing dependencies.${NC}"
            read -p "Would you like to install Homebrew? (y/n): " install_brew
            if [[ "$install_brew" =~ ^[Yy]$ ]]; then
                echo "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                if [ $? -ne 0 ]; then
                    error_message "Failed to install Homebrew. Please install it manually and try again."
                    exit 1
                fi
                eval "$(/opt/homebrew/bin/brew shellenv)"
            else
                error_message "Cannot proceed without Homebrew. Please install it manually and rerun the script."
                exit 1
            fi
        fi
        
        echo "Using Homebrew package manager..."
        for dep in "${missing_deps[@]}"; do
            echo "Installing $dep..."
            brew install "$dep"
            if [ $? -ne 0 ]; then
                error_message "Failed to install $dep. Please install it manually and try again."
                exit 1
            fi
        done
    elif [[ "$OSTYPE" == "linux-gnu"* ]] && command -v apt-get &> /dev/null; then
        echo "Using apt package manager..."
        sudo apt-get update
        for dep in "${missing_deps[@]}"; do
            echo "Installing $dep..."
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$dep"
            if [ $? -ne 0 ]; then
                error_message "Failed to install $dep. Please install it manually and try again."
                exit 1
            fi
        done
    else
        error_message "No supported package manager found. Please install manually: ${missing_deps[*]}"
        exit 1
    fi
    
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

copy_node_keys() {
    echo -e "\nChecking for existing node keys..."
    
    # Check if ceremonyclient config directory exists
    if [ ! -d "$NODE_KEYS_DIR" ]; then
        warning_message "No node keys found at $NODE_KEYS_DIR"
        echo "Skipping node keys import."
        return 0
    fi
    
    # Check if required files exist
    if [ ! -f "$NODE_KEYS_DIR/keys.yml" ] || [ ! -f "$NODE_KEYS_DIR/config.yml" ]; then
        warning_message "Required files (keys.yml or config.yml) not found in $NODE_KEYS_DIR"
        echo "Skipping node keys import."
        return 0
    fi
    
    # Check if node_wallet already exists
    if [ -d "$NODE_WALLET_DIR" ]; then
        warning_message "node_wallet already exists at $NODE_WALLET_DIR"
        read -p "Would you like to overwrite the existing node_wallet with your current node keys? (y/n): " overwrite
        if [[ ! $overwrite =~ ^[Yy]$ ]]; then
            echo "Skipping node keys import."
            return 0
        fi
        rm -rf "$NODE_WALLET_DIR"
    fi
    
    # Create node_wallet directory and copy files
    echo "Importing node keys to node_wallet..."
    mkdir -p "$NODE_WALLET_DIR/.config"
    
    if ! cp -p "$NODE_KEYS_DIR/keys.yml" "$NODE_KEYS_DIR/config.yml" "$NODE_WALLET_DIR/.config/"; then
        error_message "Failed to copy node keys files"
        rm -rf "$NODE_WALLET_DIR"  # Clean up if copy failed
        return 1
    fi
    
    # Verify copy success
    if [ -f "$NODE_WALLET_DIR/.config/keys.yml" ] && [ -f "$NODE_WALLET_DIR/.config/config.yml" ]; then
        success_message "Successfully imported node keys to $NODE_WALLET_DIR"
        echo "Wallet 'node_wallet' has been created with your existing node keys."
        echo "node_wallet" > "$INSTALL_DIR/.current_wallet"
    else
        error_message "Copy verification failed - files may not have transferred correctly"
        rm -rf "$NODE_WALLET_DIR"  # Clean up if verification failed
        return 1
    fi
    
    return 0
}

check_wallet_exists() {
    local wallet_name="$1"
    if [ -d "wallets/$wallet_name" ]; then
        return 0
    fi
    return 1
}

handle_wallet_creation() {
    if [[ -n "$wallet_name" ]]; then
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
                wallet_name=""
                return
            fi
        fi
        
        echo "Creating wallet: $wallet_name"
        mkdir -p "wallets/$wallet_name/.config"
        echo "$wallet_name" > .current_wallet
        success_message "Wallet '$wallet_name' created successfully"
    fi
}

setup_alias() {
    echo -e "\nQuick command setup"
    echo "-------------------"
    echo "This will add an alias 'q1wallet' to your shell profile to call the menu."

    read -p "Would you like to set up the quick command? (y/n): " setup_cmd
    if [[ ! $setup_cmd =~ ^[Yy]$ ]]; then
        warning_message "Skipping quick command setup."
        echo "You can still use the wallet by running: $INSTALL_DIR/menu.sh"
        return 0
    fi

    # Detect shell and appropriate profile file
    profile_file=""
    case "$SHELL" in
        */zsh)
            profile_file="$HOME/.zprofile"  # Use .zprofile for Zsh to avoid Oh My Zsh issues
            ;;
        */bash)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                profile_file="$HOME/.bash_profile"  # macOS Bash
            else
                profile_file="$HOME/.bashrc"  # Linux Bash
            fi
            ;;
        *)
            profile_file="$HOME/.profile"  # Fallback for other shells
            ;;
    esac

    # Check if alias already exists
    if grep -q "alias q1wallet=" "$profile_file" 2>/dev/null; then
        current_alias=$(grep "alias q1wallet=" "$profile_file" | sed 's/alias q1wallet=//')
        if [ "$current_alias" = "'$INSTALL_DIR/menu.sh'" ]; then
            success_message "Command 'q1wallet' alias already exists and is set up correctly in $profile_file"
            warning_message "You may need to restart your terminal or run 'source $profile_file' to use the alias."
            return 0
        else
            warning_message "An existing alias 'q1wallet' was found in $profile_file pointing to: $current_alias"
            read -p "Would you like to replace it with the new alias? (y/n): " replace
            if [[ ! $replace =~ ^[Yy]$ ]]; then
                warning_message "Keeping the existing alias unchanged."
                echo "You can still use the wallet by running: $INSTALL_DIR/menu.sh"
                return 0
            fi
            # Remove existing alias (portable sed syntax)
            sed -i.bak "/alias q1wallet=/d" "$profile_file" && rm "$profile_file.bak"
            if [ $? -ne 0 ]; then
                error_message "Failed to remove existing alias from $profile_file."
                echo "Please remove it manually and rerun the setup."
                return 1
            fi
        fi
    fi

    # Add alias with a comment to profile file
    echo "Adding alias to $profile_file..."
    {
        echo "# Q1 Wallet quick command - runs the wallet menu script"
        echo "alias q1wallet='$INSTALL_DIR/menu.sh'"
    } >> "$profile_file"

    if [ $? -eq 0 ]; then
        success_message "Command 'q1wallet' alias added successfully to $profile_file!"
        warning_message "You may need to restart your terminal or run 'source $profile_file' to use the alias."
        return 0
    else
        error_message "Failed to add alias to $profile_file"
        echo "You can still use the wallet by running: $INSTALL_DIR/menu.sh"
        echo "Or manually add this to your $profile_file:"
        echo "# Q1 Wallet quick command - runs the wallet menu script"
        echo "alias q1wallet='$INSTALL_DIR/menu.sh'"
        return 1
    fi
}

# Show welcome message (platform-agnostic)
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

if [ "$PWD" != "$INSTALL_DIR" ]; then
    echo "Changing to installation directory: $INSTALL_DIR"
    cd "$INSTALL_DIR" || {
        error_message "Failed to change to installation directory: $INSTALL_DIR"
        exit 1
    }
fi

check_dependencies
echo

copy_node_keys
echo

# Ask about wallet creation (platform-agnostic)
echo
# Check if node_wallet was created by checking if it exists and was set as current
if [ -d "$INSTALL_DIR/wallets/node_wallet" ] && [ "$(cat "$INSTALL_DIR/.current_wallet" 2>/dev/null)" = "node_wallet" ]; then
    #success_message "A wallet 'node_wallet' has been created using your imported node keys."
    echo "You can use this wallet immediately, or create an additional wallet."
    read -p "Would you like to create an additional wallet now? (y/n): " create_wallet
else
    # If no node_wallet was imported, use the original prompt
    read -p "Would you like to create a new wallet now? (y/n): " create_wallet
fi

wallet_name=""

if [[ $create_wallet =~ ^[Yy]$ ]]; then
    while true; do
        echo
        read -p "Enter wallet name (a-z, 0-9, -, _): " wallet_name
        
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
fi

# Create directory structure (platform-agnostic)
echo
echo "Creating directory structure..."
mkdir -p "wallets"

# Download the wallet script (platform-agnostic)
echo "Downloading Q1 Wallet script..."
if ! curl -sS -o "menu.sh" "$MENU_SCRIPT_URL"; then
    error_message "Failed to download wallet script!"
    exit 1
fi
chmod +x menu.sh

# Download qclient binary (cross-platform)
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

files=$(curl -s "$QCLIENT_RELEASE_URL" | grep "$release_os-$release_arch" || true)

if [ -z "$files" ]; then
    error_message "No qclient files found for $release_os-$release_arch"
    exit 1
fi

for file in $files; do
    echo "Downloading $file..."
    if ! curl -# -f "$QUILIBRIUM_RELEASES/$file" > "$file"; then
        error_message "Failed to download $file"
        continue
    fi
    
    if [[ ! $file =~ \.(dgst|sig)$ ]]; then
        chmod +x "$file"
    fi
done

# Create wallet if requested
handle_wallet_creation

# Success message (platform-agnostic)
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
warning_message "IMPORTANT SECURITY STEPS:"
echo "------------------------"
echo "1. Back up your wallet keys:"
echo "   After creating your wallet, locate the folders in:"
echo "   $HOME/q1wallet/wallets"
echo "   Each folder contains the secret keys to one of your wallets.
echo
echo "   Copy these folders to an encrypted USB drive for secure storage."
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

setup_alias

# Launch the menu if requested
echo
read -p "Would you like to start Q1 Wallet now? (y/n): " start_now
if [[ $start_now =~ ^[Yy]$ ]]; then
    ./menu.sh
fi
