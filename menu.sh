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


SCRIPT_VERSION="1.2.6"

# Color definitions (platform-agnostic)
RED='\033[1;31m'
ORANGE='\033[0;33m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

#=====================
# Variables
#=====================

# Cross-platform path resolution (works on both Linux and macOS)
QCLIENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WALLETS_DIR="$QCLIENT_DIR/wallets"
CURRENT_WALLET_FILE="$QCLIENT_DIR/.current_wallet"

check_existing_wallets() {
    if [ -d "$WALLETS_DIR" ]; then
        if find "$WALLETS_DIR" -mindepth 2 -maxdepth 2 -type d -name ".config" | grep -q .; then
            return 0
        fi
    fi
    return 1
}

# Initialize current wallet (platform-agnostic)
if [ -f "$CURRENT_WALLET_FILE" ]; then
    WALLET_NAME=$(cat "$CURRENT_WALLET_FILE")
elif check_existing_wallets; then
    WALLET_NAME=$(find "$WALLETS_DIR" -mindepth 2 -maxdepth 2 -type d -name ".config" | head -n1 | awk -F'/' '{print $(NF-2)}')
    echo "$WALLET_NAME" > "$CURRENT_WALLET_FILE"
else
    WALLET_NAME="Wallet_1"
    echo "$WALLET_NAME" > "$CURRENT_WALLET_FILE"
    mkdir -p "$WALLETS_DIR/$WALLET_NAME/.config"
fi

get_config_flags() {
    echo "--config $WALLETS_DIR/$WALLET_NAME/.config --public-rpc"
}

FLAGS=$(get_config_flags)

QCLIENT_EXEC=$(find "$QCLIENT_DIR" -maxdepth 1 -type f -name "qclient-*" ! -name "*.dgst*" ! -name "*.sig*" ! -name "*Zone.Identifier*" | sort -V | tail -n 1)

QCLIENT_RELEASE_URL="https://releases.quilibrium.com/qclient-release"
QUILIBRIUM_RELEASES="https://releases.quilibrium.com"

#=====================
# Dependency Checks and Auto-Install (Cross-Platform)
#=====================

check_and_install_deps() {
    local deps=("curl" "unzip" "zip" "bc")
    local missing_deps=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${ORANGE}⚠️ Missing dependencies: ${missing_deps[*]}${NC}"
        echo "These are required for the script to function properly."

        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS dependency installation via Homebrew
            if ! command -v brew &> /dev/null; then
                echo -e "${ORANGE}Homebrew is not installed. It's required to install missing dependencies.${NC}"
                read -p "Would you like to install Homebrew? (y/n): " install_brew
                if [[ "$install_brew" =~ ^[Yy]$ ]]; then
                    echo "Installing Homebrew..."
                    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                    if [ $? -ne 0 ]; then
                        echo -e "${RED}❌ Failed to install Homebrew. Please install it manually and try again.${NC}"
                        exit 1
                    fi
                    eval "$(/opt/homebrew/bin/brew shellenv)"
                else
                    echo -e "${RED}❌ Cannot proceed without Homebrew. Please install it manually and rerun the script.${NC}"
                    exit 1
                fi
            fi
            for dep in "${missing_deps[@]}"; do
                echo "Installing $dep via Homebrew..."
                brew install "$dep"
                if [ $? -ne 0 ]; then
                    echo -e "${RED}❌ Failed to install $dep. Please install it manually and try again.${NC}"
                    exit 1
                fi
            done
        elif [[ "$OSTYPE" == "linux-gnu"* ]] && command -v apt-get &> /dev/null; then
            # Linux dependency installation via apt-get
            echo "Installing missing dependencies via apt-get..."
            sudo apt-get update
            for dep in "${missing_deps[@]}"; do
                echo "Installing $dep..."
                sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$dep"
                if [ $? -ne 0 ]; then
                    echo -e "${RED}❌ Failed to install $dep. Please install it manually and try again.${NC}"
                    exit 1
                fi
            done
        else
            echo -e "${RED}❌ No supported package manager found. Please install manually: ${missing_deps[*]}${NC}"
            exit 1
        fi
        echo -e "${BOLD}✅ All dependencies installed successfully!${NC}"
    fi
}

#=====================
# Menu Interface (Platform-Agnostic)
#=====================

display_menu() {
    clear
    echo "
                Q1Q1Q1\    Q1\   
               Q1  __Q1\ Q1Q1 |  
               Q1 |  Q1 |\_Q1 |  
               Q1 |  Q1 |  Q1 |  
               Q1 |  Q1 |  Q1 |  
               Q1  Q1Q1 |  Q1 |  
               \Q1Q1Q1 / Q1Q1Q1\ 
                \___Q1Q\ \______|  QUILIBRIUM.ONE
                    \___|        
                              
========================================================"
    echo -e "${BOLD}Q1 WALLET (BETA) ${PURPLE}${BOLD}>> $WALLET_NAME${NC}"
    echo -e "========================================================
1) Check balance / address   6) Check individual coins      
2) Create transaction        7) Merge coins   
                             8) Split coins  
--------------------------------------------------------
10) Create new wallet       12) Switch wallet
11) Import wallet           13) Encrypt/decrypt wallet
                            14) Delete wallet
--------------------------------------------------------
U) Check for updates         X) Disclaimer   
S) Security settings         H) Help
-------------------------------------------------------- 
D) Donations 
--------------------------------------------------------    
E) Exit                      v $SCRIPT_VERSION"
    echo
    echo -e "${ORANGE}The Q1 WALLET is still in beta. Use at your own risk.${NC}"
    echo
}

#=====================
# Helper Functions (Mostly Platform-Agnostic)
#=====================


format_title() {
    local title="$1"
    local width=${#title}
    local padding="=="
    local separator="-"
    
    echo -e "\n${BOLD}=== $title ===${NC}"
    printf "%s\n" "$(printf '%*s' $((width + 8)) | tr ' ' '-')"
}

error_message() {
    echo -e "${RED}❌ $1${NC}"
}

warning_message() {
    echo -e "${ORANGE}⚠️  $1${NC}"
}

confirm_proceed() {
    local action_name="$1"
    local description="$2"
    
    echo
    echo "$(format_title "$action_name")"
    [ -n "$description" ] && echo "$description"
    echo
    
    while true; do
        read -rp "Do you want to proceed with $action_name? (y/n): " confirm
        case $confirm in
            [Yy]* ) return 0 ;;
            [Nn]* ) 
                echo "Operation cancelled."
                display_menu
                return 1 ;;
            * ) echo "Please answer Y or N." ;;
        esac
    done
}

debug_info() {
    local command_to_debug="$1"
    
    echo
    echo "=== Debug Information ==="
    echo "------------------------"
    echo "System State:"
    echo "  Current directory: $(pwd)"
    echo "  Script directory: $QCLIENT_DIR"
    echo "  Wallets directory: $WALLETS_DIR"
    echo "  Current wallet: $WALLET_NAME"
    
    echo
    echo "Paths and Flags:"
    echo "  Qclient executable: $QCLIENT_EXEC"
    echo "  Config path: $WALLETS_DIR/$WALLET_NAME/.config"
    echo "  Full config flag: $FLAGS"
    
    echo
    echo "Command Construction:"
    echo "  Base executable: $QCLIENT_EXEC"
    echo "  Config flag: $FLAGS"
    if [ -n "$command_to_debug" ]; then
        echo "  Full command to execute: $command_to_debug"
        echo "  Command parsed pieces:"
        echo "    Program: $(echo "$command_to_debug" | cut -d' ' -f1)"
        echo "    Arguments: $(echo "$command_to_debug" | cut -d' ' -f2-)"
    fi
    
    echo
    echo "Directory Structure:"
    echo "  Main wallet dir ($WALLETS_DIR):"
    if [ -d "$WALLETS_DIR" ]; then
        ls -la "$WALLETS_DIR"
    else
        echo "  ❌ Directory does not exist"
    fi
    
    echo
    echo "  Current wallet dir ($WALLETS_DIR/$WALLET_NAME):"
    if [ -d "$WALLETS_DIR/$WALLET_NAME" ]; then
        ls -la "$WALLETS_DIR/$WALLET_NAME"
    else
        echo "  ❌ Directory does not exist"
    fi
    
    echo
    echo "  Config dir ($WALLETS_DIR/$WALLET_NAME/.config):"
    if [ -d "$WALLETS_DIR/$WALLET_NAME/.config" ]; then
        ls -la "$WALLETS_DIR/$WALLET_NAME/.config"
    else
        echo "  ❌ Directory does not exist"
    fi
    
    echo
    echo "------------------------"
}

validate_hash() {
    local hash="$1"
    local hash_regex="^0x[0-9a-fA-F]{64}$"
    
    if [[ ! $hash =~ $hash_regex ]]; then
        return 1
    fi
    return 0
}

wait_with_spinner() {
    local message="${1:-Wait for %s seconds...}"
    local seconds="$2"
    local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local pid

    message="${message//%s/"$seconds (CTRL+C to esc)"}"

    trap 'kill $pid 2>/dev/null; wait $pid 2>/dev/null; echo -en "\r\033[K"; echo -e "\n\nOperation cancelled. Returning to main menu..."; main; exit 0' INT

    (
        while true; do
            for (( i=0; i<${#chars}; i++ )); do
                echo -en "\r$message ${chars:$i:1} "
                sleep 0.1
            done
        done
    ) &
    pid=$!

    sleep "$seconds"
    kill $pid 2>/dev/null
    wait $pid 2>/dev/null
    echo -en "\r\033[K"
    
    trap - INT
}

check_exit() {
    local input="$1"
    if [[ "$input" == "e" ]]; then
        echo "Returning to main menu..."
        main
        exit 0
    fi
    return 1
}

check_qclient_binary() {
    if [ -z "$QCLIENT_EXEC" ]; then
        echo
        error_message "No Qclient found in: $QCLIENT_DIR."
        echo "Qclient is the software that creates/manages your Q wallet."
        download_latest_qclient
    else
        chmod +x "$QCLIENT_EXEC"
    fi
}

cleanup_old_releases() {
    local QCLIENT_DIR="$1"
    local NEW_VERSION="$2"
    
    echo
    echo "Cleaning up old release files..."
    echo "Directory: $QCLIENT_DIR"
    echo "New version: $NEW_VERSION"
    
    find "$QCLIENT_DIR" -maxdepth 1 -type f -name "qclient-*" | while read -r file; do
        local file_version
        file_version=$(echo "$file" | grep -o 'qclient-[0-9]\+\.[0-9]\+\.[0-9]\+\.*[0-9]*' | sed 's/qclient-//')
        
        echo "Found file: $file"
        echo "Extracted version: $file_version"
        
        if [ -z "$file_version" ] || [ "$file_version" = "$NEW_VERSION" ]; then
            echo "Skipping file (either no version found or matches new version)"
            continue
        fi
        
        echo "Removing old version files: qclient-$file_version*"
        rm -f "$QCLIENT_DIR/qclient-$file_version"*
    done
    
    echo "✅ Cleanup complete"
}

version_gt() {
    test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"
}

check_qclient_version() {
    echo
    echo "Checking Qclient version..."
    local REMOTE_VERSION
    REMOTE_VERSION=$(curl -s "$QCLIENT_RELEASE_URL" | grep -E "qclient-[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?" | head -n1 | sed -E 's/.*qclient-([0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/')
    
    if [ -z "$REMOTE_VERSION" ]; then
        error_message "Could not fetch remote version"
        return 1
    fi
    
    local QCLIENT_PATH
    QCLIENT_PATH=$(find "$QCLIENT_DIR" -maxdepth 1 -type f -name "qclient-*" ! -name "*.dgst*" ! -name "*.sig*" ! -name "*Zone.Identifier*" | sort -V | tail -n 1)
    
    if [ -z "$QCLIENT_PATH" ]; then
        error_message "No qclient binary found in $QCLIENT_DIR"
        echo "Would you like to download the latest version? (y/n)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            download_latest_qclient
        fi
        return 1
    fi
    
    local LOCAL_VERSION
    if [[ "$QCLIENT_PATH" =~ qclient-([0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?) ]]; then
        LOCAL_VERSION="${BASH_REMATCH[1]}"
    else
        error_message "Could not determine local version from binary: $QCLIENT_PATH"
        return 1
    fi
    
    echo
    echo "Current local version: $LOCAL_VERSION"
    echo "Latest remote version: $REMOTE_VERSION"
    
    if version_gt "$REMOTE_VERSION" "$LOCAL_VERSION"; then
        echo
        warning_message "A new version of Qclient is available!"
        echo
        
        if download_latest_qclient; then
            cleanup_old_releases "$QCLIENT_DIR" "$REMOTE_VERSION"
            echo "✅ Update completed successfully!"
            echo
            echo "Restarting script in 3 seconds..."
            sleep 3
            exec "$0"
        else
            error_message "Update failed"
            return 1
        fi
        return 2
    else
        echo
        echo "✅ You are running the latest version"
        echo
        return 0
    fi
}

show_error_and_confirm() {
    local error_msg="$1"
    error_message "$error_msg"
    echo
    read -p "Return to main menu? (y/n): " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        main
        return 1
    fi
}

download_latest_qclient() {
    echo
    echo "Proceed to download the latest Qclient version? (y/n)"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo
        echo "⏳ Downloading Qclient..."
        echo "This may take some time, don't close your terminal."
        echo
        
        if [ ! -d "$QCLIENT_DIR" ]; then
            mkdir -p "$QCLIENT_DIR"
        fi
        
        if [ ! -d "$QCLIENT_DIR/.config" ]; then
            mkdir -p "$QCLIENT_DIR/.config"
        fi
        
        cd "$QCLIENT_DIR" || exit 1
        
        # Cross-platform OS and architecture detection
        case "$OSTYPE" in
            "linux-gnu"*)
                release_os="linux"
                case "$(uname -m)" in
                    "x86_64") release_arch="amd64" ;;
                    "aarch64") release_arch="arm64" ;;
                    *) error_message "Error: Unsupported system architecture ($(uname -m))"; return 1 ;;
                esac ;;
            "darwin"*)
                release_os="darwin"
                case "$(uname -m)" in
                    "x86_64") release_arch="amd64" ;;
                    "arm64") release_arch="arm64" ;;
                    *) error_message "Error: Unsupported system architecture ($(uname -m))"; return 1 ;;
                esac ;;
            *) error_message "Error: Unsupported operating system ($OSTYPE)"; return 1 ;;
        esac

        if ! files=$(curl -s -f --connect-timeout 10 --max-time 30 "$QCLIENT_RELEASE_URL"); then
            error_message "Error: Failed to connect to $QCLIENT_RELEASE_URL"
            echo "Please check your internet connection and try again."
            return 1
        fi

        matched_files=$(echo "$files" | grep "$release_os-$release_arch" || true)
        if [ -z "$matched_files" ]; then
            error_message "Error: No qclient files found for $release_os-$release_arch"
            return 1
        fi

        VERSION_PATTERN="qclient-([0-9]+\.[0-9]+\.[0-9]+)"
        if [[ $(echo "$matched_files" | head -n1) =~ $VERSION_PATTERN ]]; then
            NEW_VERSION="${BASH_REMATCH[1]}"
            echo "Found version: $NEW_VERSION"
        else
            error_message "Error: Could not determine version from filenames"
            return 1
        fi

        echo "$matched_files" | while read -r file; do
            if [ ! -f "$file" ]; then
                echo "Downloading $file..."
                if ! curl -s -f --connect-timeout 10 --max-time 300 "$QUILIBRIUM_RELEASES/$file" > "$file"; then
                    error_message "Failed to download $file"
                    rm -f "$file"
                    continue
                fi
                
                if [[ ! $file =~ \.(dgst|sig)$ ]]; then
                    if ! chmod +x "$file"; then
                        error_message "Failed to make $file executable"
                        continue
                    fi
                fi
            else
                echo "File $file already exists, skipping"
            fi
        done

        QCLIENT_EXEC=$(find "$QCLIENT_DIR" -maxdepth 1 -type f -name "qclient-*" ! -name "*.dgst*" ! -name "*.sig*" ! -name "*Zone.Identifier*" | sort -V | tail -n 1)

        if [ -n "$QCLIENT_EXEC" ]; then
            echo "✅ Successfully downloaded Qclient to $QCLIENT_DIR"
            chmod +x "$QCLIENT_EXEC"
            return 0
        else
            error_message "Error: Could not locate downloaded qclient binary"
            return 1
        fi
    else
        error_message "Download cancelled. Please obtain the Qclient manually."
        return 1
    fi
}

check_wallet_encryption() {
    if [ ! -d "$WALLETS_DIR" ] && [ -f "$QCLIENT_DIR/wallets.zip" ]; then
        echo
        echo "Your wallets are encrypted."
        read -s -p "Password: " password
        echo
        
        if unzip -qq -P "$password" "$QCLIENT_DIR/wallets.zip" -d "$QCLIENT_DIR"; then
            if [ -d "$WALLETS_DIR" ]; then
                rm "$QCLIENT_DIR/wallets.zip"
                return 0
            else
                error_message "Decryption failed"
                return 1
            fi
        else
            error_message "Incorrect password"
            return 1
        fi
    fi
    return 0
}


#=====================
# Menu Functions
#=====================

press_any_key() {
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    echo
    display_menu
}

check_coins() {
    if ! check_wallet_encryption; then
        return 1
    fi
    echo
    echo "$(format_title "Individual coins")"
    echo
    tput sc
    echo "Loading your coins..."
    tput rc
    
    output=$($QCLIENT_EXEC token coins metadata $FLAGS | sort -n -k 6 -r)
    
    tput el
    echo "$output"
    echo
}

check_balance() {
    if ! check_wallet_encryption; then
        return 1
    fi
    echo
    echo "$(format_title "Token balance and account address")"
    echo
    $QCLIENT_EXEC token balance $FLAGS
    echo
}

create_transaction() {
    if ! check_wallet_encryption; then
        show_error_and_confirm "Wallet encryption check failed"
        return 1
    fi
    
    echo
    echo "$(format_title "Create Transaction")"
    echo "This will transfer a coin to another address."
    echo
    echo "IMPORTANT:"
    echo "- Make sure the recipient address is correct - this operation cannot be undone"
    echo "- The account address is different from the node peerID"
    echo "- Account addresses and coin IDs have the same format - don't send to a coin address"
    echo
        
    if ! confirm_proceed "Create Transaction" "$description"; then
        main
        return 1
    fi

    while true; do
        echo
        read -p "Enter the recipient's account address (or 'e' to exit): " to_address
        if [[ "$to_address" == "e" ]]; then
            echo "Transaction cancelled."
            main
            return 1
        fi
        
        if validate_hash "$to_address"; then
            break
        else
            error_message "Invalid address format. Address must start with '0x' followed by 64 hexadecimal characters."
            echo "Example: 0x7fe21cc8205c9031943daf4797307871fbf9ffe0851781acc694636d92712345"
            echo
            continue
        fi
    done

    echo
    echo "Your current coins before transaction:"
    echo "--------------------------------------"
    check_coins
    echo
    
    while true; do
        read -p "Enter the coin ID to transfer (or 'e' to exit): " coin_id
        if [[ "$coin_id" == "e" ]]; then
            echo "Transaction cancelled."
            main
            return 1
        fi
        
        if validate_hash "$coin_id"; then
            break
        else
            error_message "Invalid coin ID format. ID must start with '0x' followed by 64 hexadecimal characters."
            echo "Example: 0x1148092cdce78c721835601ef39f9c2cd8b48b7787cbea032dd3913a4106a58d"
            echo
            continue
        fi
    done

    cmd="$QCLIENT_EXEC token transfer $to_address $coin_id $FLAGS"
    echo
    echo "Transaction Details:"
    echo "--------------------"
    echo "Recipient: $to_address"
    echo "Coin ID: $coin_id"
    echo
    echo "Command that will be executed:"
    echo "$cmd"
    echo

    read -p "Do you want to proceed with this transaction? (y/n): " confirm

    read -p "Do you want to proceed with this transaction? (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
        if ! eval "$cmd"; then
            show_error_and_confirm "Transaction failed"
            return 1
        fi
        echo
        echo "Transaction sent. The receiver does not need to accept it."
        if ! wait_with_spinner "Checking updated coins in %s seconds..." 30; then
            show_error_and_confirm "Failed to update coin display"
            return 1
        fi
        echo
        echo "Your coins after transaction:"
        echo "-----------------------------"
        check_coins
        echo
        echo "If you don't see the changes yet, wait a moment and check your coins again from the main menu."
        main
        return 0
    else
        echo "Transaction cancelled."
        main
        return 1
    fi
}

token_split_advanced() {
    if ! check_wallet_encryption; then
        show_error_and_confirm "Wallet encryption check failed"
        return 1
    fi

    echo
    echo "$(format_title "Split Coins")"
    echo "This will split a coin into multiple new coins (up to 50) using different methods"
    echo

    while true; do
        echo
        echo "Choose split method:"
        echo "1) Split in custom amounts"
        echo "2) Split in equal amounts"
        echo "3) Split by percentages"
        echo
        read -p "Enter your choice (1-3 or 'e' to exit): " split_method

        case $split_method in
            "e")
                echo "Operation cancelled."
                main
                return 1
                ;;
            [1-3])
                break
                ;;
            *)  
                error_message "Invalid choice. Please enter 1, 2, 3, or 'e' to exit."
                continue
                ;;
        esac
    done

    echo
    echo "Your current coins:"
    echo "-----------------"
    check_coins
    echo

    while true; do
        read -p "Enter the coin ID to split (or 'e' to exit): " coin_id
        if [[ "$coin_id" == "e" ]]; then
            echo "Operation cancelled."
            main
            return 1
        fi
        if validate_hash "$coin_id"; then
            break
        else
            error_message "Invalid coin ID format. ID must start with '0x' followed by 64 hexadecimal characters."
            echo
            continue
        fi
    done

    coin_info=$($QCLIENT_EXEC token coins $FLAGS | grep "$coin_id")
    if [[ $coin_info =~ ([0-9]+\.[0-9]+)\ QUIL ]]; then
        total_amount=${BASH_REMATCH[1]}
    else
        show_error_and_confirm "Could not determine coin amount. Please try again."
        return 1
    fi

    echo
    echo "Selected coin amount: $total_amount QUIL"
    echo

    format_decimal() {
        local num="$1"
        if [[ $num =~ ^\..*$ ]]; then
            num="0$num"
        fi
        echo $num | sed 's/\.$//' | sed 's/0*$//'
    }

    case $split_method in
        1)
            while true; do
                echo
                echo "Enter amounts separated by comma (up to 100 values, must sum to $total_amount)"
                echo "Example: 1.5,2.3,0.7"
                read -p "> (or 'e' to exit) " amounts_input
                
                if [[ "$amounts_input" == "e" ]]; then
                    echo "Operation cancelled."
                    main
                    return 1
                fi

                IFS=',' read -ra amounts <<< "$amounts_input"
                
                if [ ${#amounts[@]} -gt 100 ]; then
                    error_message "Too many values (maximum 100)"
                    continue
                fi
                
                sum=0
                valid=true
                for amount in "${amounts[@]}"; do
                    if [[ ! $amount =~ ^[0-9]*\.?[0-9]+$ ]]; then
                        error_message "Invalid amount format: $amount"
                        valid=false
                        break
                    fi
                    sum=$(echo "scale=12; $sum + $amount" | bc)
                done

                if [ "$valid" = false ]; then
                    continue
                fi
                
                diff=$(echo "scale=12; ($sum - $total_amount)^2 < 0.000000000001" | bc)
                if [ "$diff" -eq 1 ]; then
                    formatted_amounts=()
                    for amount in "${amounts[@]}"; do
                        formatted_amounts+=($(format_decimal "$amount"))
                    done
                    amounts=("${formatted_amounts[@]}")
                    break
                else
                    error_message "Sum of amounts ($sum) does not match coin amount ($total_amount)"
                    continue
                fi
            done
            ;;
            
        2)
            while true; do
                echo
                read -p "Enter number of parts to split into (2-100 or 'e' to exit): " num_parts
                if [[ "$num_parts" == "e" ]]; then
                    echo "Operation cancelled."
                    main
                    return 1
                fi
                if ! [[ "$num_parts" =~ ^[2-9]|[1-9][0-9]|100$ ]]; then
                    error_message "Please enter a number between 2 and 100"
                    continue
                fi
                
                base_amount=$(echo "scale=12; $total_amount / $num_parts" | bc)
                
                amounts=()
                remaining=$total_amount
                
                for ((i=1; i<num_parts; i++)); do
                    current_amount=$(format_decimal "$base_amount")
                    amounts+=("$current_amount")
                    remaining=$(echo "scale=12; $remaining - $current_amount" | bc)
                done
                
                amounts+=($(format_decimal "$remaining"))
                break
            done
            ;;
            
        3)
            while true; do
                echo
                echo "Enter percentages separated by comma (must sum to 100)"
                echo "Example: 50,30,20"
                read -p "> (or 'e' to exit) " percentages_input
                
                if [[ "$percentages_input" == "e" ]]; then
                    echo "Operation cancelled."
                    main
                    return 1
                fi

                IFS=',' read -ra percentages <<< "$percentages_input"
                
                if [ ${#percentages[@]} -gt 100 ]; then
                    error_message "Too many values (maximum 100)"
                    continue
                fi
                
                sum=0
                valid=true
                for pct in "${percentages[@]}"; do
                    if [[ ! $pct =~ ^[0-9]*\.?[0-9]+$ ]]; then
                        error_message "Invalid percentage format: $pct"
                        valid=false
                        break
                    fi
                    sum=$(echo "scale=12; $sum + $pct" | bc)
                done

                if [ "$valid" = false ]; then
                    continue
                fi
                
                diff=$(echo "scale=12; ($sum - 100)^2 < 0.000000000001" | bc)
                if [ "$diff" -eq 1 ]; then
                    amounts=()
                    remaining=$total_amount
                    for ((i=0; i<${#percentages[@]}-1; i++)); do
                        amount=$(echo "scale=12; $total_amount * ${percentages[$i]} / 100" | bc)
                        formatted_amount=$(format_decimal "$amount")
                        amounts+=("$formatted_amount")
                        remaining=$(echo "scale=12; $remaining - $formatted_amount" | bc)
                    done
                    amounts+=($(format_decimal "$remaining"))
                    break
                else
                    error_message "Percentages must sum to 100 (current sum: $sum)"
                    continue
                fi
            done
            ;;
    esac

    cmd="$QCLIENT_EXEC token split $coin_id"
    for amount in "${amounts[@]}"; do
        cmd="$cmd $amount"
    done
    cmd="$cmd $FLAGS"

    echo
    echo "Split Details:"
    echo "--------------"
    echo "Original Coin: $coin_id"
    echo "Original Amount: $total_amount QUIL"
    echo "Number of parts: ${#amounts[@]}"
    echo "Split amounts:"
    for ((i=0; i<${#amounts[@]}; i++)); do
        echo "Part $((i+1)): ${amounts[$i]} QUIL"
    done
    echo
    echo "Command that will be executed:"
    echo "$cmd"
    echo

    read -p "Do you want to proceed with this split? (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
        if ! eval "$cmd"; then
            show_error_and_confirm "Split operation failed"
            return 1
        fi
        
        if ! wait_with_spinner "Showing your coins in %s secs..." 30; then
            show_error_and_confirm "Failed to update coin display"
            return 1
        fi
        
        echo
        echo "Your coins after splitting:"
        echo "---------------------------"
        check_coins
        echo
        echo "If you don't see the changes yet, wait a moment and check your coins again from the main menu."
        main
        return 0
    else
        echo "Split operation cancelled."
        main
        return 1
    fi
}

token_merge() {
    if ! check_wallet_encryption; then
        show_error_and_confirm "Wallet encryption check failed"
        return 1
    fi
    
    echo
    echo "$(format_title "Merge Coins")"
    echo "This function allows you to merge coins using different methods"
    echo
    
    while true; do
        echo
        echo "Choose merge option:"
        echo "1) Merge two specific coins"
        echo "2) Merge the last 'n' coins"
        echo "3) Merge all coins"
        echo
        read -p "Enter your choice (1-3 or 'e' to exit): " merge_choice

        case $merge_choice in
            "e")
                echo "Operation cancelled."
                main
                return 1
                ;;
            1|2|3)
                break
                ;;
            *)  
                error_message "Invalid choice. Please enter 1, 2, 3, or 'e' to exit."
                continue
                ;;
        esac
    done

    case $merge_choice in
        1)
            echo
            echo "Your current coins before merging:"
            echo "----------------------------------"
            coins_output=$($QCLIENT_EXEC token coins $FLAGS)
            echo "$coins_output"
            echo

            coin_count=$(echo "$coins_output" | grep -c "QUIL")

            if [ "$coin_count" -lt 2 ]; then
                show_error_and_confirm "Not enough coins to merge. You need at least 2 coins."
                return 1
            fi
            
            while true; do
                read -p "Enter the first coin ID (or 'e' to exit): " left_coin
                if [[ "$left_coin" == "e" ]]; then
                    echo "Operation cancelled."
                    main
                    return 1
                fi
                if validate_hash "$left_coin"; then
                    break
                else
                    error_message "Invalid coin ID format. ID must start with '0x' followed by 64 hexadecimal characters."
                    echo
                    continue
                fi
            done

            while true; do
                read -p "Enter the second coin ID (or 'e' to exit): " right_coin
                if [[ "$right_coin" == "e" ]]; then
                    echo "Operation cancelled."
                    main
                    return 1
                fi
                if validate_hash "$right_coin"; then
                    break
                else
                    error_message "Invalid coin ID format. ID must start with '0x' followed by 64 hexadecimal characters."
                    echo
                    continue
                fi
            done

            echo
            echo "Merge Details:"
            echo "--------------"
            echo "First Coin: $left_coin"
            echo "Second Coin: $right_coin"
            echo
            echo "Command that will be executed:"
            echo "$QCLIENT_EXEC token merge $left_coin $right_coin $FLAGS"
            echo

            read -p "Do you want to proceed with this merge? (y/n): " confirm
            if [[ "$confirm" == "y" ]]; then
                if ! $QCLIENT_EXEC token merge "$left_coin" "$right_coin" $FLAGS; then
                    show_error_and_confirm "Merge operation failed"
                    return 1
                fi
                echo "✅ Merge completed successfully"
            else
                echo "Merge operation cancelled."
                main
                return 1
            fi
            ;;

        2)
            echo
            echo "Checking your coins..."
            coins_output=$($QCLIENT_EXEC token coins $FLAGS)
            coin_count=$(echo "$coins_output" | grep -c "QUIL")
            echo "Your total coins: $coin_count"
            echo "----------------------------------"

            if [ "$coin_count" -lt 2 ]; then
                show_error_and_confirm "Not enough coins to merge. You need at least 2 coins."
                return 1
            fi

            while true; do
                read -p "Enter the number of coins to merge (2-$coin_count or 'e' to exit): " num_coins
                if [[ "$num_coins" == "e" ]]; then
                    echo "Operation cancelled."
                    main
                    return 1
                fi
                if ! [[ "$num_coins" =~ ^[0-9]+$ ]] || \
                   [ "$num_coins" -lt 2 ] || \
                   [ "$num_coins" -gt "$coin_count" ]; then
                    error_message "Invalid number. Please enter a number between 2 and $coin_count"
                    continue
                fi
                break
            done

            # Get the last 'n' coin addresses
            coin_addrs=$(echo "$coins_output" | grep -oP '(?<=Coin\s)[0-9a-fx]+' | tail -n "$num_coins" | tr '\n' ' ')
            
            if [[ -z "$coin_addrs" ]]; then
                show_error_and_confirm "Sorry, no coins were found to merge"
                return 1
            fi

            echo
            echo "Merge Details:"
            echo "--------------"
            echo "Number of coins to merge: $num_coins"
            echo

            read -p "Do you want to proceed with this merge? (y/n): " confirm
            if [[ "$confirm" == "y" ]]; then
                if ! $QCLIENT_EXEC token merge $coin_addrs $FLAGS; then
                    show_error_and_confirm "Merge operation failed"
                    return 1
                fi
                echo "✅ Merge of $num_coins coins completed successfully"
            else
                echo "Merge operation cancelled."
                main
                return 1
            fi
            ;;

        3)
            coin_count=$($QCLIENT_EXEC token coins $FLAGS | grep -c "QUIL")
            
            if [ "$coin_count" -lt 2 ]; then
                show_error_and_confirm "Not enough coins to merge. You need at least 2 coins."
                return 1
            fi

            echo "Command that will be executed:"
            echo "$QCLIENT_EXEC token merge all $FLAGS"
            echo
            
            read -p "Do you want to proceed with merging all coins? (y/n): " confirm
            if [[ "$confirm" == "y" ]]; then
                if ! $QCLIENT_EXEC token merge all $FLAGS; then
                    show_error_and_confirm "Merge operation failed"
                    return 1
                fi
                echo "✅ Merge of all coins completed successfully"
            else
                echo "Merge operation cancelled."
                main
                return 1
            fi
            ;;
    esac

    echo
    if ! wait_with_spinner "Showing your coins in %s secs..." 30; then
        show_error_and_confirm "Failed to update coin display"
        return 1
    fi
    
    echo
    echo "Your coins after merging:"
    echo "-------------------------"
    check_coins
    echo
    echo "If you don't see the changes yet, wait a moment and check your coins again from the main menu."
    main
    return 0
}


create_new_wallet() {
    if ! check_wallet_encryption; then
        show_error_and_confirm "Wallet encryption check failed"
        return 1
    fi
    
    echo
    echo "$(format_title "Create Wallet")"
    echo
    
    while true; do
        read -p "Enter new wallet name (or 'e' to exit): " new_wallet
        
        if [[ "$new_wallet" == "e" ]]; then
            echo "Operation cancelled."
            main
            return 1
        fi
        
        if [[ ! "$new_wallet" =~ ^[a-z0-9_-]+$ ]]; then
            error_message "Invalid wallet name. Use only lowercase letters, numbers, dashes (-) and underscores (_)"
            continue
        fi
        
        if [ -d "$WALLETS_DIR/$new_wallet" ]; then
            error_message "Wallet '$new_wallet' already exists"
            continue
        fi
        
        if ! mkdir -p "$WALLETS_DIR/$new_wallet/.config"; then
            show_error_and_confirm "Failed to create wallet directory"
            return 1
        fi
        
        WALLET_NAME="$new_wallet"
        if ! echo "$WALLET_NAME" > "$CURRENT_WALLET_FILE"; then
            show_error_and_confirm "Failed to update current wallet file"
            return 1
        fi
        
        FLAGS=$(get_config_flags)
        
        echo
        echo "✅ Created new wallet: $new_wallet"
        echo "✅ Switched to new wallet"
        echo
        
        if ! check_balance; then
            show_error_and_confirm "Wallet created but balance check failed"
            return 1
        fi
        
        echo
        echo "Your new wallet is ready to use!"
        main
        return 0
    done
}

switch_wallet() {
    if ! check_wallet_encryption; then
        show_error_and_confirm "Wallet encryption check failed"
        return 1
    fi
    
    echo
    echo "$(format_title "Switch Wallet")"
    echo
    
    if [ ! -d "$WALLETS_DIR" ]; then
        show_error_and_confirm "No wallets directory found"
        return 1
    fi
    
    wallets=()
    while IFS= read -r dir; do
        if [ -d "$dir/.config" ]; then
            wallet_name=$(basename "$dir")
            wallets+=("$wallet_name")
        fi
    done < <(find "$WALLETS_DIR" -mindepth 1 -maxdepth 1 -type d)
    
    if [ ${#wallets[@]} -eq 0 ]; then
        show_error_and_confirm "No valid wallets found"
        return 1
    fi

    while true; do
        echo "Available wallets:"
        echo "-----------------"
        for i in "${!wallets[@]}"; do
            if [ "${wallets[$i]}" == "$WALLET_NAME" ]; then
                echo "$((i+1))) ${wallets[$i]} (current)"
            else
                echo "$((i+1))) ${wallets[$i]}"
            fi
        done
        echo
        
        read -p "Select wallet number (1-${#wallets[@]} or 'e' to exit): " selection
        
        if [[ "$selection" == "e" ]]; then
            echo "Operation cancelled."
            main
            return 1
        fi
        
        if ! [[ "$selection" =~ ^[0-9]+$ ]] || \
           [ "$selection" -lt 1 ] || \
           [ "$selection" -gt ${#wallets[@]} ]; then
            error_message "Invalid selection. Please choose a number between 1 and ${#wallets[@]}"
            continue
        fi
        
        new_wallet="${wallets[$((selection-1))]}"
        
        if [ "$new_wallet" == "$WALLET_NAME" ]; then
            error_message "Already using this wallet"
            continue
        fi
        
        WALLET_NAME="$new_wallet"
        if ! echo "$WALLET_NAME" > "$CURRENT_WALLET_FILE"; then
            show_error_and_confirm "Failed to update current wallet file"
            return 1
        fi
        
        FLAGS=$(get_config_flags)
        
        echo
        echo "✅ Switched to wallet: $new_wallet"
        echo
        
        main
        return 0
    done
}

delete_wallet() {
    if ! check_wallet_encryption; then
        show_error_and_confirm "Wallet encryption check failed"
        return 1
    fi
    
    description="⚠️  WARNING: This operation cannot be undone!\nYou will lose access to the wallet keys and funds."
    
    if ! confirm_proceed "Delete Wallet" "$description"; then
        main
        return 1
    fi
    
    if [ ! -d "$WALLETS_DIR" ]; then
        show_error_and_confirm "No wallets directory found"
        return 1
    fi
    
    wallets=()
    while IFS= read -r dir; do
        if [ -d "$dir/.config" ]; then
            wallet_name=$(basename "$dir")
            wallets+=("$wallet_name")
        fi
    done < <(find "$WALLETS_DIR" -mindepth 1 -maxdepth 1 -type d)
    
    if [ ${#wallets[@]} -eq 0 ]; then
        show_error_and_confirm "No valid wallets found"
        return 1
    fi

    while true; do
        echo
        echo "Available wallets:"
        echo "-----------------"
        for i in "${!wallets[@]}"; do
            if [ "${wallets[$i]}" == "$WALLET_NAME" ]; then
                echo "$((i+1))) ${wallets[$i]} (current)"
            else
                echo "$((i+1))) ${wallets[$i]}"
            fi
        done
        echo
        
        read -p "Select wallet number to delete (1-${#wallets[@]} or 'e' to exit): " selection
        
        if [[ "$selection" == "e" ]]; then
            echo "Operation cancelled."
            main
            return 1
        fi
        
        if ! [[ "$selection" =~ ^[0-9]+$ ]] || \
           [ "$selection" -lt 1 ] || \
           [ "$selection" -gt ${#wallets[@]} ]; then
            error_message "Invalid selection. Please choose a number between 1 and ${#wallets[@]}"
            continue
        fi
        
        selected_wallet="${wallets[$((selection-1))]}"
        
        if [ "$selected_wallet" == "$WALLET_NAME" ]; then
            error_message "Cannot delete the currently active wallet. Please switch to a different wallet first"
            continue
        fi
        
        echo
        warning_message "You are about to delete wallet: $selected_wallet"
        echo "This action cannot be undone and you will lose all access to this wallet!"
        read -p "Are you absolutely sure you want to delete this wallet? (y/n): " confirm
        
        if [[ "$confirm" == "y" ]]; then
            echo
            echo "Final confirmation required."
            read -p "Type the wallet name '$selected_wallet' to confirm deletion: " confirmation
            
            if [[ "$confirmation" == "$selected_wallet" ]]; then
                if rm -rf "$WALLETS_DIR/$selected_wallet"; then
                    echo
                    echo "✅ Wallet '$selected_wallet' has been deleted."
                    main
                    return 0
                else
                    show_error_and_confirm "Error occurred while deleting the wallet"
                    return 1
                fi
            else
                error_message "Wallet name confirmation did not match. Deletion cancelled"
                continue
            fi
        else
            echo "Deletion cancelled."
            continue
        fi
    done
}

encrypt_decrypt_wallets() {
    if [ -f "$QCLIENT_DIR/wallets.zip" ] && [ ! -d "$WALLETS_DIR" ]; then
        echo
        echo "$(format_title "Wallet Encryption")"
        echo "This will decrypt your wallet files using your password."
        echo
        echo "Current status: Wallets are encrypted"
        echo
        
        while true; do
            read -p "Decrypt your wallets? (y/n or 'e' to exit): " choice
            case $choice in
                [Yy])
                    echo
                    read -s -p "Password: " password
                    echo
                    
                    if ! unzip -qq -P "$password" "$QCLIENT_DIR/wallets.zip" -d "$QCLIENT_DIR"; then
                        error_message "Decryption failed - incorrect password"
                        continue
                    fi
                    
                    if [ ! -d "$WALLETS_DIR" ]; then
                        error_message "Decryption failed - archive may be corrupted"
                        continue
                    fi
                    
                    echo "✅ Wallets decrypted successfully"
                    echo "Removing encrypted archive..."
                    if ! rm "$QCLIENT_DIR/wallets.zip"; then
                        show_error_and_confirm "Warning: Could not remove encrypted archive"
                        return 1
                    fi
                    echo "✅ Operation completed"
                    main
                    return 0
                    ;;
                [Nn])
                    echo "Operation cancelled."
                    main
                    return 1
                    ;;
                "e")
                    echo "Operation cancelled."
                    main
                    return 1
                    ;;
                *)
                    error_message "Please answer y or n"
                    continue
                    ;;
            esac
        done
        
    elif [ -d "$WALLETS_DIR" ] && [ ! -f "$QCLIENT_DIR/wallets.zip" ]; then
        echo
        echo "$(format_title "Wallet Encryption")"
        echo "This will encrypt your wallet files to secure them with a password."
        echo
        echo "Current status: Wallets are unprotected"
        echo
        warning_message "IMPORTANT: If you lose the password, your wallets cannot be recovered!"
        warning_message "Make sure to use a strong password and store it securely."
        echo
        
        while true; do
            read -p "Encrypt your wallets? (y/n or 'e' to exit): " choice
            case $choice in
                [Yy])
                    echo
                    if ! cd "$QCLIENT_DIR"; then
                        show_error_and_confirm "Failed to access wallet directory"
                        return 1
                    fi
                    
                    if ! zip -qq -r -e wallets.zip wallets/; then
                        show_error_and_confirm "Encryption failed"
                        rm -f wallets.zip
                        return 1
                    fi
                    
                    if [ ! -s wallets.zip ]; then
                        show_error_and_confirm "Encryption verification failed"
                        rm -f wallets.zip
                        return 1
                    fi
                    
                    echo "✅ Encryption successful"
                    echo "Removing unencrypted wallets..."
                    if ! rm -rf "$WALLETS_DIR"; then
                        show_error_and_confirm "Warning: Could not remove unencrypted wallets"
                        return 1
                    fi
                    echo "✅ Operation completed"
                    echo
                    echo "Your wallets are now encrypted in: $QCLIENT_DIR/wallets.zip"
                    echo "Keep this file and your password safe!"
                    # Pause and wait for any key press
                    read -p "Press any key to return to the menu... "
                    main
                    return 0
                    ;;
                [Nn])
                    echo "Operation cancelled."
                    main
                    return 1
                    ;;
                "e")
                    echo "Operation cancelled."
                    main
                    return 1
                    ;;
                *)
                    error_message "Please answer y or n"
                    continue
                    ;;
            esac
        done
        
    else
        if [ -f "$QCLIENT_DIR/wallets.zip" ] && [ -d "$WALLETS_DIR" ]; then
            show_error_and_confirm "Invalid state: Both encrypted and unencrypted wallets found.\nPlease manually remove either wallets.zip or the wallets directory"
            return 1
        else
            show_error_and_confirm "No wallets found to encrypt/decrypt"
            return 1
        fi
    fi
}

help() {
    cat << EOF

$(format_title "WALLET COMMANDS HELP")

BALANCE & TRANSACTIONS
---------------------
1 - Check Balance / Address
    View your current QUIL balance and wallet address for receiving funds

2 - Create Transaction
    Send QUIL to another wallet address by selecting specific coins to transfer

COIN MANAGEMENT
--------------
6 - Check Individual Coins
    Display detailed information about each coin in your wallet including amounts and metadata

7 - Merge Coins
    Combine multiple coins into a single coin. You can merge two specific coins or all coins at once

8 - Split Coins
    Divide a single coin into multiple coins with specified amounts

WALLET MANAGEMENT
-----------------
10 - Create New Wallet
     Generate a new wallet with its own address and configuration

11 - Import Wallet
     Import an existing wallet by adding its configuration files

12 - Switch Wallet
     Change between different wallets you have created or imported

13 - Encrypt/Decrypt Wallet
     Secure your wallet files with password protection or decrypt them for use

14 - Delete Wallet
     Remove a wallet and all its associated files (cannot be undone)

Note: Always ensure you have backups of your wallet configurations
      and never share your private keys or configuration files.

EOF
}

import_wallet() {
    echo
    echo "$(format_title "Import wallet")"
    echo "
To import a new wallet create a folder in $WALLETS_DIR (the folder name will be your wallet name),
then create a .config folder inside it, and paste there your current wallet config.yml file
"
}

donations() {
    echo
    echo "$(format_title "Donations")"
    echo '
To support us, you can send a donation to the Quilibrium Community Treasury.
This is the official treasury (you can verify the address on Discord).

Send ERC-20 tokens at this address:
0xE09e96E3A3CCBEafC0996d6c0214E10adFD01D65

Or visit this page: https://iri.quest/q-donations
'
}

disclaimer() {
    echo
    echo "$(format_title "Disclaimer")"
    echo '
This tool and all related scripts are unofficial and are being shared as-is.
I take no responsibility for potential bugs or any misuse of the available options. 

All scripts are open source; feel free to inspect them before use.
Repo: https://github.com/lamat1111/Q1-Wallet
'
}

security_settings() {
    echo
    echo "$(format_title "Security Settings")"
    echo '
This script performs QUIL transactions. You can inspect the source code by running:
cat "'$QCLIENT_DIR/menu.sh'"

The script also auto-updates to the latest version automatically.
If you want to disable auto-updates, comment out the line "check_for_updates"
in the script itself.

DISCLAIMER:
The author assumes no responsibility for any QUIL loss due to misuse of this script.
Use this script at your own risk and always verify transactions before confirming them.
'
}

check_for_updates() {
    local GITHUB_RAW_URL="https://raw.githubusercontent.com/lamat1111/Q1-Wallet/main/menu.sh"
    local SCRIPT_PATH="$QCLIENT_DIR/menu.sh"
    local LATEST_VERSION
    
    LATEST_VERSION=$(curl -sS "$GITHUB_RAW_URL" | sed -n 's/^SCRIPT_VERSION="\(.*\)"$/\1/p')
    
    if [ $? -ne 0 ] || [ -z "$LATEST_VERSION" ]; then
        return 1
    fi
    
    echo
    echo "Current local version: $SCRIPT_VERSION"
    echo "Latest remote version: $LATEST_VERSION"
    
    if version_gt "$LATEST_VERSION" "$SCRIPT_VERSION"; then
        echo
        warning_message "A new version is available!"
        echo
        
        if curl -sS -o "${SCRIPT_PATH}.tmp" "$GITHUB_RAW_URL"; then
            chmod +x "${SCRIPT_PATH}.tmp"
            mv "${SCRIPT_PATH}.tmp" "$SCRIPT_PATH"
            echo "✅ Update completed successfully!"
            echo
            echo "Restarting script in 3 seconds..."
            sleep 3
            exec "$SCRIPT_PATH"
        else
            error_message "Update failed"
            rm -f "${SCRIPT_PATH}.tmp"
            return 1
        fi
        return 2
    else
        echo
        echo "✅ You are running the latest version"
        echo
        return 0
    fi
}

#=====================
# Main Menu Loop
#=====================

main() {
    while true; do
        display_menu
        
        read -rp "Enter your choice: " choice
        
        case $choice in
            1) check_balance; press_any_key ;;
            2) create_transaction; press_any_key ;;
            6) check_coins; press_any_key ;;
            7) token_merge; press_any_key ;;
            8) token_split_advanced; press_any_key ;;
            10) create_new_wallet; press_any_key ;;
            11) import_wallet; press_any_key ;;
            12) switch_wallet; press_any_key ;;
            13) encrypt_decrypt_wallets; press_any_key ;;
            14) delete_wallet; press_any_key ;;
            [uU]) check_qclient_version; press_any_key ;;
            [sS]) security_settings; press_any_key ;;
            [dD]) donations; press_any_key ;;
            [xX]) disclaimer; press_any_key ;;
            [hH]) help; press_any_key ;;
            [eE]) echo; exit 0 ;;
            *) echo "Invalid option, please try again." ;;
        esac
    done
}

#=====================
# Run
#=====================

check_and_install_deps
check_qclient_binary
check_for_updates
main
