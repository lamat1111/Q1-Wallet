#!/bin/bash

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
    echo -e "${ORANGE}⚠️  $1${NC}"
}

success_message() {
    echo -e "${GREEN}✅ $1${NC}"
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

check_dependencies() {
    local deps=("curl" "unzip" "bc" "zip")
    local missing_deps=()
    
    # Quietly check for missing dependencies
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    # If all dependencies are present, return silently
    [ ${#missing_deps[@]} -eq 0 ] && return 0
    
    echo "Installing required dependencies..."
    
    case "$OSTYPE" in
        "linux-gnu"*)
            if command -v apt-get &> /dev/null; then
                sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
                sudo DEBIAN_FRONTEND=noninteractive apt-get install -qq -y "${missing_deps[@]}"
            elif command -v yum &> /dev/null; then
                sudo yum install -y -q "${missing_deps[@]}"
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y -q "${missing_deps[@]}"
            elif command -v pacman &> /dev/null; then
                sudo pacman -Sy --noconfirm --quiet "${missing_deps[@]}"
            else
                error_message "Could not detect package manager. Please install: ${missing_deps[*]}"
                exit 1
            fi
            ;;
        "darwin"*)
            if ! command -v brew &> /dev/null; then
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            brew install --quiet "${missing_deps[@]}"
            ;;
        *)
            error_message "Unsupported operating system"
            exit 1
            ;;
    esac
    
    # Verify installation silently
    for dep in "${missing_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            error_message "Failed to install required dependencies"
            exit 1
        fi
    done
}


check_system_compatibility

check_dependencies

# Show welcome message
clear
echo -e "${BOLD}
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
                 Welcome to Q1 Wallet Installer
=================================================================${NC}"


# Show current directory and ask for installation location
current_dir=$(pwd)
echo
echo "Current directory: $current_dir"
echo "The Q1 Wallet will be installed in this location."
echo -e "${ORANGE}If you want to install it somewhere else, press Ctrl+C and cd to the desired location first.${NC}"
echo

# Ask for confirmation
read -p "Do you want to proceed with the installation in this location? (y/n): " proceed
if [[ ! $proceed =~ ^[Yy]$ ]]; then
    error_message "Installation cancelled."
    exit 1
fi

# Ask about wallet creation
read -p "Would you like to create a new wallet now? (y/n): " create_wallet
wallet_name=""

if [[ $create_wallet =~ ^[Yy]$ ]]; then
    while true; do
        echo
        read -p "Enter wallet name (a-z, 0-9, -, _): " wallet_name
        
        if [[ ! "$wallet_name" =~ ^[a-z0-9_-]+$ ]]; then
            error_message "Invalid wallet name. Use only lowercase letters, numbers, dashes (-) and underscores (_)."
            continue
        fi
        break
    done
fi

# Create directory structure
echo
echo "Creating directory structure..."
mkdir -p "q1wallet/wallets"
cd "q1wallet" || exit 1

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

echo "Downloading qclient for $release_os-$release_arch..."
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
    if ! curl -s -f "$QUILIBRIUM_RELEASES/$file" > "$file"; then
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

success_message "Installation completed successfully!"
echo
echo "Installation details:"
echo "--------------------"
echo "Location: $(pwd)"
if [[ -n "$wallet_name" ]]; then
    echo "Wallet created: $wallet_name"
fi
echo
echo "To start Q1 Wallet, run:"
echo "cd $(pwd) && ./menu.sh"
echo

# Launch the menu if requested
read -p "Would you like to start Q1 Wallet now? (y/n): " start_now
if [[ $start_now =~ ^[Yy]$ ]]; then
    ./menu.sh
fi