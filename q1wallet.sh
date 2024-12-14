#!/bin/bash

# Define the version number here
SCRIPT_VERSION="2.0.5"

# Color definitions
RED='\033[1;31m'      # Bright red for errors
ORANGE='\033[0;33m'   # Orange for warnings
PURPLE='\033[0;35m'   # Purple for current wallet
BOLD='\033[1m'        # Bold for titles and menu
NC='\033[0m'          # No Color - reset

#=====================
# Variables
#=====================

# Get current directory (where the script is running)
QCLIENT_DIR="$(pwd)"

# Wallet management variables
WALLETS_DIR="$QCLIENT_DIR/wallets"
CURRENT_WALLET_FILE="$QCLIENT_DIR/.current_wallet"

# Initialize current wallet
if [ -f "$CURRENT_WALLET_FILE" ]; then
    WALLET_NAME=$(cat "$CURRENT_WALLET_FILE")
else
    WALLET_NAME="wallet_1"
    echo "$WALLET_NAME" > "$CURRENT_WALLET_FILE"
    # Create initial wallet structure
    mkdir -p "$WALLETS_DIR/$WALLET_NAME/.config"
fi

# Set config flag to point directly to the .config folder
FLAGS="--config $WALLETS_DIR/$WALLET_NAME/.config --public-rpc"

# Find qclient binary (excluding signature and identifier files)
QCLIENT_EXEC=$(find "$QCLIENT_DIR" -maxdepth 1 -type f -name "qclient-*" ! -name "*.dgst*" ! -name "*.sig*" ! -name "*Zone.Identifier*" | sort -V | tail -n 1)

# Qclient release urls
QCLIENT_RELEASE_URL="https://releases.quilibrium.com/qclient-release"
QUILIBRIUM_RELEASES="https://releases.quilibrium.com"

# Menu interface with fixed color display
display_menu() {
    clear
    # First part without colors
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
                              
================================================================="
    echo -e "${BOLD}Q1 WALLET (BETA) >> ${PURPLE}${BOLD}$WALLET_NAME${NC}"
    echo -e "=================================================================
1) Check balance / address       9) Create new wallet
2) Create transaction           10) Change wallet
6) Check individual coins       11) Encrypt/decrypt wallet
7) Merge coins                  12) Delete wallet
8) Split coins                               
-----------------------------------------------------------------
U) Check for updates             X) Disclaimer   
S) Security settings             H) Help
----------------------------------------------------------------- 
D) Donations 
-----------------------------------------------------------------    
E) Exit                          v $SCRIPT_VERSION"
echo
echo -e "${ORANGE}The Q1 WALLET is still in beta. Use at your own risk.${NC}"
echo
}

#=====================
# Helper functions
#=====================

# Modified helper functions with proper color display
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

# Pre-action confirmation function
confirm_proceed() {
    local action_name="$1"
    local description="$2"
    
    echo
    echo "$(format_title "$action_name")"
    [ -n "$description" ] && echo "$description"  # Removed the \n
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

# Debug function
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

# Function to validate Quilibrium hashes (addresses, transaction IDs, etc)
validate_hash() {
    local hash="$1"
    local hash_regex="^0x[0-9a-fA-F]{64}$"
    
    if [[ ! $hash =~ $hash_regex ]]; then
        return 1
    fi
    return 0
}

# wait with spinner - goes back to menu on CTRL + C
wait_with_spinner() {
    local message="${1:-Wait for %s seconds...}"
    local seconds="$2"
    local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local pid

    message="${message//%s/"$seconds (CTRL+C to esc)"}"

    # Set up trap for SIGINT (Ctrl+C)
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
    
    # Remove the trap after completion
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

# Function to check and setup qclient binary
check_qclient_binary() {
    if [ -z "$QCLIENT_EXEC" ]; then
        echo
        error_message "No Qclient found in: $QCLIENT_DIR."
        echo "Qclient is the software that creates/manages your Q wallet."
        download_latest_qclient
    else
        chmod +x "$QCLIENT_EXEC"
    fi

    # Debug output
    #echo "Found binary: $QCLIENT_EXEC"
    #echo "Found config: $QCLIENT_DIR/.config"
    #echo "Config flag: $FLAGS"

    # Test if everything is working
    $QCLIENT_EXEC --version
}

# Function to cleanup old release files
cleanup_old_releases() {
    local QCLIENT_DIR="$1"
    local NEW_VERSION="$2"
    
    echo
    echo "Cleaning up old release files..."
    echo "Directory: $QCLIENT_DIR"
    echo "New version: $NEW_VERSION"
    
    # Find all qclient files
    find "$QCLIENT_DIR" -maxdepth 1 -type f -name "qclient-*" | while read -r file; do
        local file_version
        file_version=$(echo "$file" | grep -o 'qclient-[0-9]\+\.[0-9]\+\.[0-9]\+\.*[0-9]*' | sed 's/qclient-//')
        
        echo "Found file: $file"
        echo "Extracted version: $file_version"
        
        # Skip if we couldn't extract a version or if it's the new version
        if [ -z "$file_version" ] || [ "$file_version" = "$NEW_VERSION" ]; then
            echo "Skipping file (either no version found or matches new version)"
            continue
        fi
        
        # Remove the old version and its associated files
        echo "Removing old version files: qclient-$file_version*"
        rm -f "$QCLIENT_DIR/qclient-$file_version"*
    done
    
    echo "✅ Cleanup complete"
}

# Function to compare version strings
version_gt() {
    test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"
}

check_qclient_version() {
    # Get remote version
    local REMOTE_VERSION
    REMOTE_VERSION=$(curl -s "$QCLIENT_RELEASE_URL" | grep -E "^qclient-[0-9]+(\.[0-9]+)*" | sed 's/^qclient-//' | cut -d '-' -f 1 | head -n 1)
    
    if [ -z "$REMOTE_VERSION" ]; then
        error_message "Could not fetch remote version"
        return 1
    fi
    
    # Get current directory (where the script is running)
    local QCLIENT_DIR="$(pwd)"
    
    # Find current version from local qclient binary
    local LOCAL_VERSION
    LOCAL_VERSION=$(find "$QCLIENT_DIR" -maxdepth 1 -type f -name "qclient-*" ! -name "*.dgst*" ! -name "*.sig*" ! -name "*Zone.Identifier*" | sort -V | tail -n 1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\.*[0-9]*')
    
    if [ -z "$LOCAL_VERSION" ]; then
        error_message "Could not determine local version"
        return 1
    fi
    
    echo
    echo "Current local version: $LOCAL_VERSION"
    echo "Latest remote version: $REMOTE_VERSION"
    
    if version_gt "$REMOTE_VERSION" "$LOCAL_VERSION"; then
        echo
        warning_message "A new version of Qclient is available!"
        echo
        
        # Download new version
        if download_latest_qclient; then
            # Only cleanup after successful download
            cleanup_old_releases "$QCLIENT_DIR" "$REMOTE_VERSION"
            echo "✅ Update completed successfully!"
            echo
            echo "Restarting script in 3 seconds..."
            sleep 3
            exec "$0"  # Restart the script after cleanup
        else
            error_message "Update failed"
            return 1
        fi
        return 2
    else
        echo
        echo "✅ You are running the latest version of Qclient"
        echo
        return 0
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
        
        # Create directories if they don't exist
        mkdir -p "$QCLIENT_DIR"
        mkdir -p "$QCLIENT_DIR/.config"
        cd "$QCLIENT_DIR" || exit 1
        
        # Detect OS and architecture
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

        # Fetch the file list with error handling
        if ! files=$(curl -s -f --connect-timeout 10 --max-time 30 "$QCLIENT_RELEASE_URL"); then
            error_message "Error: Failed to connect to $QCLIENT_RELEASE_URL"
            echo "Please check your internet connection and try again."
            return 1
        fi

        # Filter files for current architecture
        files=$(echo "$files" | grep "$release_os-$release_arch" || true)

        if [ -z "$files" ]; then
            error_message "Error: No qclient files found for $release_os-$release_arch"
            return 1
        fi

        # Download files
        for file in $files; do
            if ! test -f "./$file"; then
                echo "Downloading $file..."
                if ! curl -s -f --connect-timeout 10 --max-time 300 "$QUILIBRIUM_RELEASES/$file" > "$file"; then
                    error_message "Failed to download $file"
                    rm -f "$file" # Cleanup failed download
                    continue
                fi
                
                # Make binary executable if it's not a signature or digest file
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

        echo "✅ Successfully downloaded Qclient to $QCLIENT_DIR"
        return 0  # Return success but don't restart
    else
        error_message "Download cancelled. Please obtain the Qclient manually."
        return 1
    fi
}

# Function to check if wallets are encrypted and handle decryption if needed
# Function to check if wallets are encrypted and handle decryption if needed
check_wallet_encryption() {
    if [ ! -d "$WALLETS_DIR" ] && [ -f "$QCLIENT_DIR/wallets.zip" ]; then
        echo
        echo "Your wallets are encrypted."
        read -s -p "Password: " password
        echo  # New line after hidden password input
        
        if unzip -qq -P "$password" "$QCLIENT_DIR/wallets.zip" -d "$QCLIENT_DIR"; then
            if [ -d "$WALLETS_DIR" ]; then
                rm "$QCLIENT_DIR/wallets.zip"
                return 0  # Decryption successful
            else
                error_message "Decryption failed"
                return 1
            fi
        else
            error_message "Incorrect password"
            return 1
        fi
    fi
    return 0  # Wallets are not encrypted
}


#=====================
# Menu functions
#=====================

prompt_return_to_menu() {
    echo
    while true; do
    echo
    echo "----------------------------------------"
        read -rp "Go back to Q1 Wallet menu? (y/n): " choice
        case $choice in
            [Yy]* ) return 0 ;;  # Return true (0) to continue the loop
            [Nn]* ) return 1 ;;  # Return false (1) to break the loop
            * ) echo "Please answer Y or N." ;;
        esac
    done
}

# Handle "press any key" prompts
press_any_key() {
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    echo
    display_menu
}

check_balance() {
    # First check if wallets are encrypted
    if ! check_wallet_encryption; then
        return 1
    fi
    echo
    echo "$(format_title "Token balance and account address")"
    echo
    $QCLIENT_EXEC token balance $FLAGS
    echo
}

check_coins() {
    # First check if wallets are encrypted
    if ! check_wallet_encryption; then
        return 1
    fi
   echo
   echo "$(format_title "Individual coins")"
   echo
   tput sc  # Save cursor position
   echo "Loading your coins..."
   tput rc  # Restore cursor position
   
   output=$($QCLIENT_EXEC token coins metadata $FLAGS | awk '{gsub("Timestamp ", ""); frame=$(NF-2); ts=$NF; gsub("T", " ", ts); gsub("+01:00", "", ts); cmd="date -d \""ts"\" \"+%d/%m/%Y %H.%M.%S\" 2>/dev/null"; cmd | getline newts; close(cmd); $(NF)=newts; print frame, $0}' | sort -k1,1nr | cut -d' ' -f2- | awk -F'Frame ' '{num=substr($2,1,index($2,",")-1); print num"|"$0}' | sort -t'|' -k1nr | cut -d'|' -f2-)
   
   tput el  # Clear line
   echo "$output"
   echo
}

create_transaction() {
    # First check if wallets are encrypted
    if ! check_wallet_encryption; then
        return 1
    fi
    description="This will transfer a coin to another address.

IMPORTANT:
- Make sure the recipient address is correct - this operation cannot be undone
- The account address is different from the node peerID
- Account addresses and coin IDs have the same format - don't send to a coin address"
        
    if ! confirm_proceed "Create Transaction" "$description"; then
        return 1
    fi

    # Get and validate recipient address
    while true; do
            echo
        read -p "Enter the recipient's account address: " to_address
        check_exit "$to_address" && return 1
        if validate_hash "$to_address"; then
            break
        else
            error_message "Invalid address format. Address must start with '0x' followed by 64 hexadecimal characters."
            echo "Example: 0x7fe21cc8205c9031943daf4797307871fbf9ffe0851781acc694636d92712345"
            echo
        fi
    done

    # Get coin ID
    echo
    echo "Your current coins before transaction:"
    echo "--------------------------------------"
    check_coins
    echo
    
    while true; do
        read -p "Enter the coin ID to transfer: " coin_id
        check_exit "$coin_id" && return 1
        if validate_hash "$coin_id"; then
            break
        else
            error_message "Invalid coin ID format. ID must start with '0x' followed by 64 hexadecimal characters."
            echo "Example: 0x1148092cdce78c721835601ef39f9c2cd8b48b7787cbea032dd3913a4106a58d"
            echo
        fi
    done

    # Construct and show command
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

    if [[ ${confirm,,} == "y" ]]; then
        eval "$cmd"
        echo
        echo "Transaction sent. The receiver does not need to accept it."
        
        wait_with_spinner "Checking updated coins in %s seconds..." 30
        echo
        echo "Your coins after transaction:"
        echo "-----------------------------"
        check_coins
        echo
        echo "If you don't see the changes yet, wait a moment and check your coins again from the main menu."
    else
        error_message "Transaction cancelled."
    fi
}

# This one has both amount or ofcoin options, needs to be corrected
create_transaction_qclient_2.1.x() {
    # First check if wallets are encrypted
    if ! check_wallet_encryption; then
        return 1
    fi
    echo "$(format_title "Create transaction")"
    description="This will transfer a coin to another address.

IMPORTANT:
- Make sure the recipient address is correct - this operation cannot be undone
- The account address is different from the node peerID
- Account addresses and coin IDs have the same format - don't send to a coin address"

    # Get and validate recipient address
    while true; do
        read -p "Enter the recipient's address: " to_address
        check_exit "$to_address" && return 1
        if validate_hash "$to_address"; then
            break
        else
            error_message "Invalid address format. Address must start with '0x' followed by 64 hexadecimal characters."
            echo "Example: 0x7fe21cc8205c9031943daf4797307871fbf9ffe0851781acc694636d92712345"
            echo
        fi
    done

    # Get amount or coin ID
    echo
    echo "How would you like to make the transfer?"
    echo "1) Transfer a specific amount - not available yet in the current Qclient version!"
    echo "2) Transfer a specific coin"
    read -p "Enter your choice (only 2 is available): " transfer_type

    if [[ $transfer_type == "1" ]]; then
        while true; do
            echo
            read -p "Enter the QUIL amount to transfer (format 0.000000): " amount
            check_exit "$amount" && return 1
            # Validate amount is a positive number
            if [[ ! $amount =~ ^[0-9]*\.?[0-9]+$ ]] || [[ $(echo "$amount <= 0" | bc -l) -eq 1 ]]; then
                error_message "Invalid amount. Please enter a positive number."
                continue
            fi
            transfer_param="$amount"
            break
        done
    elif [[ $transfer_type == "2" ]]; then
        while true; do
            # Show current coins before transaction
            echo "Your current coins before transaction:"
            echo "--------------------------------------"
            check_coins
            echo
            read -p "Enter the coin ID to transfer: " coin_id
            check_exit "$coin_id" && return 1
            if validate_hash "$coin_id"; then
                break
            else
                error_message "Invalid coin ID format. ID must start with '0x' followed by 64 hexadecimal characters."
                echo "Example: 0x1148092cdce78c721835601ef39f9c2cd8b48b7787cbea032dd3913a4106a58d"
                echo
            fi
        done
        transfer_param="$coin_id"
    else
        error_message "Invalid option. Aborting transaction creation."
        return
    fi

    # Construct the command
    cmd="$QCLIENT_EXEC token transfer $to_address $transfer_param $FLAGS"

    # Show transaction details for confirmation
    echo
    echo "Transaction Details:"
    echo "--------------------"
    echo "Recipient: $to_address"
    if [[ $transfer_type == "1" ]]; then
        echo "Amount: $amount QUIL"
    else
        echo "Coin ID: $coin_id"
    fi
    echo
    echo "Command that will be executed:"
    echo "$cmd"
    echo

    # Ask for confirmation
    read -p "Do you want to proceed with this transaction? (y/n): " confirm

    if [[ ${confirm,,} == "y" ]]; then
        eval "$cmd"
        echo
        echo "Currently there is no transaction ID, and the receiver does not have to accept the transaction."
        echo "Unless you received an error, your transaction should be already on its way to the receiver."
        
        # Show updated coins after transaction
        echo
        wait_with_spinner "Showing your coins in %s secs..." 30
        echo
        echo "Your coins after transaction:"
        echo "-----------------------------"
        check_coins
        echo
        echo "If you don't see the changes yet, wait a moment and check your coins again from the main menu."
        echo "If still nothing changes, you may want to try to execute the operation again."
    else
        error_message "Transaction cancelled."
    fi
}

token_split() {
    # First check if wallets are encrypted
    if ! check_wallet_encryption; then
        return 1
    fi
    description="This will split a coin into two new coins with specified amounts"

    if ! confirm_proceed "Split Coins" "$description"; then
        return 1
    fi
    
    # Show current coins
    echo
    echo "Your current coins before splitting:"
    echo "------------------------------------"
    check_coins
    echo "Please select one of the above coins to split."
    echo

    # Get and validate the coin ID to split
    while true; do
        read -p "Enter the coin ID to split: " coin_id
        check_exit "$coin_id" && return 1
        if validate_hash "$coin_id"; then
            break
        else
            error_message "Invalid coin ID format. ID must start with '0x' followed by 64 hexadecimal characters."
            echo "Example: 0x1148092cdce78c721835601ef39f9c2cd8b48b7787cbea032dd3913a4106a58d"
            echo
        fi
    done

    # Get and validate the first amount
    while true; do
        echo
        warning_message "The 2 splitted amounts must add up exactly to the coin original amount."
        echo
        read -p "Enter the amount for the first coin  (format 0.000000): " left_amount
        check_exit "$left_amount" && return 1
        if [[ ! $left_amount =~ ^[0-9]*\.?[0-9]+$ ]] || [[ $(echo "$left_amount <= 0" | bc -l) -eq 1 ]]; then
            error_message "Invalid amount. Please enter a positive number."
            continue
        fi
        break
    done

    # Get and validate the second amount
    while true; do
        read -p "Enter the amount for the second coin  (format 0.000000): " right_amount
        check_exit "$right_amount" && return 1
        if [[ ! $right_amount =~ ^[0-9]*\.?[0-9]+$ ]] || [[ $(echo "$right_amount <= 0" | bc -l) -eq 1 ]]; then
            error_message "Invalid amount. Please enter a positive number."
            continue
        fi
        break
    done

    # Show split details for confirmation
    echo
    echo "Split Details:"
    echo "--------------"
    echo "Original Coin: $coin_id"
    echo "First Amount: $left_amount QUIL"
    echo "Second Amount: $right_amount QUIL"
    echo
    echo "Command that will be executed:"
    echo "$QCLIENT_EXEC token split $coin_id $left_amount $right_amount $FLAGS"
    echo

    # Ask for confirmation
    read -p "Do you want to proceed with this split? (y/n): " confirm

    if [[ ${confirm,,} == "y" ]]; then
        $QCLIENT_EXEC token split "$coin_id" "$left_amount" "$right_amount" $FLAGS
        
        # Show updated coins after split
        echo
        wait_with_spinner "Showing your coins in %s secs..." 30
        echo
        echo "Your coins after splitting:"
        echo "---------------------------"
        check_coins
        echo
        echo "If you don't see the changes yet, wait a moment and check your coins again from the main menu."
        echo "If still nothing changes, you may want to try to execute the operation again."
    else
        error_message "Split operation cancelled."
    fi
}

token_split_advanced() {
    # First check if wallets are encrypted
    if ! check_wallet_encryption; then
        return 1
    fi
    description="This will split a coin into multiple new coins (up to 50) using different methods"

    if ! confirm_proceed "Split Coins" "$description"; then
        return 1
    fi

    # Show split options first
    echo
    echo "Choose split method:"
    echo "1) Split in custom amounts"
    echo "2) Split in equal amounts"
    echo "3) Split by percentages"
    echo
    read -p "Enter your choice (1-3): " split_method

    case $split_method in
        [1-3])  # Valid choice, continue
            ;;
        *)  error_message "Invalid choice"
            return 1
            ;;
    esac

    # Now show coins and get coin selection
    echo
    echo "Your current coins:"
    echo "-----------------"
    check_coins
    echo

    # Get and validate the coin ID to split
    while true; do
        read -p "Enter the coin ID to split: " coin_id
        check_exit "$coin_id" && return 1
        if validate_hash "$coin_id"; then
            break
        else
            error_message "Invalid coin ID format. ID must start with '0x' followed by 64 hexadecimal characters."
            echo
        fi
    done

    # Get the coin amount for the selected coin
    coin_info=$($QCLIENT_EXEC token coins $FLAGS | grep "$coin_id")
    if [[ $coin_info =~ ([0-9]+\.[0-9]+)\ QUIL ]]; then
        total_amount=${BASH_REMATCH[1]}
    else
        error_message "Could not determine coin amount. Please try again."
        return 1
    fi

    echo
    echo "Selected coin amount: $total_amount QUIL"
    echo

    # Function to format decimal number with leading zero and trim trailing zeros
    format_decimal() {
        local num="$1"
        # Ensure leading zero
        if [[ $num =~ ^\..*$ ]]; then
            num="0$num"
        fi
        # Trim trailing zeros but maintain required decimals
        echo $num | sed 's/\.$//' | sed 's/0*$//'
    }

    case $split_method in
        1)  # Custom amounts
            while true; do
                echo
                echo "Enter amounts separated by comma (up to 100 values, must sum to $total_amount)"
                echo "Example: 1.5,2.3,0.7"
                read -p "> " amounts_input
                
                IFS=',' read -ra amounts <<< "$amounts_input"
                
                if [ ${#amounts[@]} -gt 100 ]; then
                    error_message "Too many values (maximum 100)"
                    continue
                fi
                
                # Calculate sum with full precision
                sum=0
                for amount in "${amounts[@]}"; do
                    if [[ ! $amount =~ ^[0-9]*\.?[0-9]+$ ]]; then
                        error_message "Invalid amount format: $amount"
                        continue 2
                    fi
                    sum=$(echo "scale=12; $sum + $amount" | bc)
                done
                
                # Compare with total amount (allowing for small rounding differences)
                diff=$(echo "scale=12; ($sum - $total_amount)^2 < 0.000000000001" | bc)
                if [ "$diff" -eq 1 ]; then
                    # Format amounts
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
            
        2)  # Equal amounts
            while true; do
                echo
                read -p "Enter number of parts to split into (2-100): " num_parts
                if ! [[ "$num_parts" =~ ^[2-9]|[1-9][0-9]|100$ ]]; then
                    error_message "Please enter a number between 2 and 100"
                    continue
                fi
                
                # Calculate base amount with full precision
                base_amount=$(echo "scale=12; $total_amount / $num_parts" | bc)
                
                # Generate array of amounts
                amounts=()
                remaining=$total_amount
                
                # For all parts except the last one
                for ((i=1; i<num_parts; i++)); do
                    current_amount=$(format_decimal "$base_amount")
                    amounts+=("$current_amount")
                    remaining=$(echo "scale=12; $remaining - $current_amount" | bc)
                done
                
                # Last amount is the remaining value
                amounts+=($(format_decimal "$remaining"))
                break
            done
            ;;
            
        3)  # Percentage split
            while true; do
                echo
                echo "Enter percentages separated by comma (must sum to 100)"
                echo "Example: 50,30,20"
                read -p "> " percentages_input
                
                IFS=',' read -ra percentages <<< "$percentages_input"
                
                if [ ${#percentages[@]} -gt 100 ]; then
                    error_message "Too many values (maximum 100)"
                    continue
                fi
                
                # Calculate sum of percentages
                sum=0
                for pct in "${percentages[@]}"; do
                    if [[ ! $pct =~ ^[0-9]*\.?[0-9]+$ ]]; then
                        error_message "Invalid percentage format: $pct"
                        continue 2
                    fi
                    sum=$(echo "scale=12; $sum + $pct" | bc)
                done
                
                # Check if percentages sum to 100
                diff=$(echo "scale=12; ($sum - 100)^2 < 0.000000000001" | bc)
                if [ "$diff" -eq 1 ]; then
                    # Convert percentages to amounts
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
            
        *)  error_message "Invalid choice"
            return 1
            ;;
    esac

    # Construct command with all amounts
    cmd="$QCLIENT_EXEC token split $coin_id"
    for amount in "${amounts[@]}"; do
        cmd="$cmd $amount"
    done
    cmd="$cmd $FLAGS"

    # Show split details for confirmation
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

    # Ask for confirmation
    read -p "Do you want to proceed with this split? (y/n): " confirm

    if [[ ${confirm,,} == "y" ]]; then
        eval "$cmd"
        
        # Show updated coins after split
        echo
        wait_with_spinner "Showing your coins in %s secs..." 30
        echo
        echo "Your coins after splitting:"
        echo "---------------------------"
        check_coins
        echo
        echo "If you don't see the changes yet, wait a moment and check your coins again from the main menu."
    else
        error_message "Split operation cancelled."
    fi
}

token_merge() {
    # First check if wallets are encrypted
    if ! check_wallet_encryption; then
        return 1
    fi
    description="This function allows you to merge either two specific coins or all your coins into a single coin"

    if ! confirm_proceed "Merge Coins" "$description"; then
        return 1
    fi
    
    # Display merge options first
    echo
    echo "Choose merge option:"
    echo "1) Merge two specific coins"
    echo "2) Merge all coins"
    echo
    read -p "Enter your choice (1-2): " merge_choice

    case $merge_choice in
        1)  # Merge two specific coins
            echo
            echo "Your current coins before merging:"
            echo "----------------------------------"
            coins_output=$($QCLIENT_EXEC token coins $FLAGS)
            echo "$coins_output"
            echo

            # Count coins by counting lines containing "QUIL"
            coin_count=$(echo "$coins_output" | grep -c "QUIL")

            if [ "$coin_count" -lt 2 ]; then
                error_message "Not enough coins to merge. You need at least 2 coins."
                echo
                read -p "Press Enter to return to the main menu..."
                return 1
            fi
            
            # Get and validate the first coin ID
            while true; do
                read -p "Enter the first coin ID: " left_coin
                check_exit "$left_coin" && return 1
                if validate_hash "$left_coin"; then
                    break
                else
                    error_message "Invalid coin ID format. ID must start with '0x' followed by 64 hexadecimal characters."
                    echo
                fi
            done

            # Get and validate the second coin ID
            while true; do
                read -p "Enter the second coin ID: " right_coin
                check_exit "$right_coin" && return 1
                if validate_hash "$right_coin"; then
                    break
                else
                    error_message "Invalid coin ID format. ID must start with '0x' followed by 64 hexadecimal characters."
                    echo
                fi
            done

            # Show merge details and confirm
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
            if [[ ${confirm,,} == "y" ]]; then
                $QCLIENT_EXEC token merge "$left_coin" "$right_coin" $FLAGS
            else
                error_message "Merge operation cancelled."
                return 1
            fi
            ;;

        2)  # Merge all coins
            # Verify we have enough coins to merge
            coin_count=$($QCLIENT_EXEC token coins $FLAGS | grep -c "QUIL")
            
            if [ "$coin_count" -lt 2 ]; then
                error_message "Not enough coins to merge. You need at least 2 coins."
                echo
                read -p "Press Enter to return to the main menu..."
                return 1
            fi

            # Show command and confirm
            echo "Command that will be executed:"
            echo "$QCLIENT_EXEC token merge all $FLAGS"
            echo
            
            read -p "Do you want to proceed with merging all coins? (y/n): " confirm
            if [[ ${confirm,,} == "y" ]]; then
                $QCLIENT_EXEC token merge all $FLAGS
            else
                error_message "Merge operation cancelled."
                return 1
            fi
            ;;

        *)  error_message "Invalid choice"
            return 1
            ;;
    esac

    # Show updated coins after merge
    echo
    wait_with_spinner "Showing your coins in %s secs..." 30
    echo
    echo "Your coins after merging:"
    echo "-------------------------"
    check_coins
    echo
    echo "If you don't see the changes yet, wait a moment and check your coins again from the main menu."
    echo "If still nothing changes, you may want to try to execute the operation again."
}

token_merge_simple() {
    # First check if wallets are encrypted
    if ! check_wallet_encryption; then
        return 1
    fi
    description="This will merge two coins into a single new coin"

    if ! confirm_proceed "Merge Coins" "$description"; then
        return 1
    fi
    
    # Show current coins
    echo
    echo "Your current coins before merging:"
    echo "----------------------------------"
    check_coins
    echo "Please select two of the above coins to merge."
    echo
    
    # Get and validate the first coin ID
    while true; do
        read -p "Enter the first coin ID: " left_coin
        check_exit "$left_coin" && return 1
        if validate_hash "$left_coin"; then
            break
        else
            error_message "Invalid coin ID format. ID must start with '0x' followed by 64 hexadecimal characters."
            echo "Example: 0x1148092cdce78c721835601ef39f9c2cd8b48b7787cbea032dd3913a4106a58d"
            echo
        fi
    done

    # Get and validate the second coin ID
    while true; do
        read -p "Enter the second coin ID: " right_coin
        check_exit "$right_coin" && return 1
        if validate_hash "$right_coin"; then
            break
        else
            error_message "Invalid coin ID format. ID must start with '0x' followed by 64 hexadecimal characters."
            echo "Example: 0x0140e01731256793bba03914f3844d645fbece26553acdea8ac4de4d84f91690"
            echo
        fi
    done

    # Show merge details for confirmation
    echo
    echo "Merge Details:"
    echo "--------------"
    echo "First Coin: $left_coin"
    echo "Second Coin: $right_coin"
    echo
    echo "Command that will be executed:"
    echo "$QCLIENT_EXEC token merge $left_coin $right_coin $FLAGS"
    echo

    # Ask for confirmation
    read -p "Do you want to proceed with this merge? (y/n): " confirm

    if [[ ${confirm,,} == "y" ]]; then
        $QCLIENT_EXEC token merge "$left_coin" "$right_coin" $FLAGS
        
        # Show updated coins after merge
        echo
        wait_with_spinner "Showing your coins in %s secs..." 30
        echo
        echo "Your coins after merging:"
        echo "-------------------------"
        check_coins
        echo
        echo "If you don't see the changes yet, wait a moment and check your coins again from the main menu."
        echo "If still nothing changes, you may want to try to execute the operation again."
    else
        error_message "Merge operation cancelled."
    fi
}

token_merge_all() {
    # First check if wallets are encrypted
    if ! check_wallet_encryption; then
        return 1
    fi
    description="This will merge all your coins into a single coin."

    if ! confirm_proceed "Merge All Coins" "$description"; then
        return 1
    fi

    echo "Current coins that will be merged:"
    echo "---------------------------------"
    coins_output=$($QCLIENT_EXEC token coins $FLAGS)
    echo "$coins_output"
    echo

    # Count coins by counting lines containing "QUIL"
    coin_count=$(echo "$coins_output" | grep -c "QUIL")

    if [ "$coin_count" -lt 2 ]; then
        error_message "Not enough coins to merge. You need at least 2 coins."
        echo
        read -p "Press Enter to return to the main menu..."
        return 1
    fi

    # Extract coin values and calculate total
    total_value=0
    while read -r line; do
        if [[ $line =~ ([0-9]+\.[0-9]+)\ QUIL ]]; then
            value=${BASH_REMATCH[1]}
            total_value=$(echo "$total_value + $value" | bc)
        fi
    done <<< "$coins_output"

    echo "Found $coin_count coins to merge"
    echo "Total amount in QUIL will be $total_value"
    echo

    # Ask for confirmation
    read -p "Do you want to proceed? (y/n): " confirm
    if [[ ${confirm,,} != "y" ]]; then
        error_message "Operation cancelled."
        return 1
    fi

    echo
    $QCLIENT_EXEC token merge all $FLAGS

    # Show updated coins after merge
    echo
    wait_with_spinner "Showing your coins in %s secs..." 30
    echo
    echo "Your coins after merging:"
    echo "-------------------------"
    check_coins
    echo
    echo "If you don't see the changes yet, wait a moment and check your coins again from the main menu."
    echo "If still nothing changes, you may want to try to execute the operation again."
}

# Function to create a new wallet
create_new_wallet() {
    # First check if wallets are encrypted
    if ! check_wallet_encryption; then
        return 1
    fi
    echo
    echo "$(format_title "Create New Wallet")"
    echo
    
    while true; do
        read -p "Enter new wallet name: " new_wallet
        
        # Validate wallet name (allowing letters, numbers, dashes, and underscores)
        if [[ ! "$new_wallet" =~ ^[a-z0-9_-]+$ ]]; then
            error_message "Invalid wallet name. Use only lowercase letters, numbers, dashes (-) and underscores (_)."
            continue
        fi
        
        # Check if wallet already exists
        if [ -d "$WALLETS_DIR/$new_wallet" ]; then
            error_message "Wallet '$new_wallet' already exists."
            continue
        fi
        
        # Create new wallet directory structure
        mkdir -p "$WALLETS_DIR/$new_wallet/.config"
        
        if [ $? -eq 0 ]; then
            # Update current wallet
            WALLET_NAME="$new_wallet"
            echo "$WALLET_NAME" > "$CURRENT_WALLET_FILE"
            CONFIG_FLAG="--config $WALLETS_DIR/$WALLET_NAME/.config --public-rpc"
            
            echo "✅ Created new wallet: $new_wallet"
            echo "✅ Switched to new wallet"
            #debug_info  # Debug output
            echo
            check_balance
            break
        else
            error_message "Failed to create wallet directory"
            break
        fi
    done
}

# Function to switch between wallets
switch_wallet() {
    # First check if wallets are encrypted
    if ! check_wallet_encryption; then
        return 1
    fi
    echo
    echo "$(format_title "Switch Wallet")"
    echo
    
    # List available wallets
    if [ ! -d "$WALLETS_DIR" ]; then
        error_message "No wallets directory found"
        return 1
    fi
    
    # Only list directories that contain .config
    wallets=()
    while IFS= read -r dir; do
        if [ -d "$dir/.config" ]; then
            wallet_name=$(basename "$dir")
            wallets+=("$wallet_name")
        fi
    done < <(find "$WALLETS_DIR" -mindepth 1 -maxdepth 1 -type d)
    
    if [ ${#wallets[@]} -eq 0 ]; then
        error_message "No valid wallets found"
        return 1
    fi
    
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
    
    while true; do
        read -p "Select wallet number (1-${#wallets[@]}): " selection
        
        # Validate input
        if ! [[ "$selection" =~ ^[0-9]+$ ]] || \
           [ "$selection" -lt 1 ] || \
           [ "$selection" -gt ${#wallets[@]} ]; then
            error_message "Invalid selection"
            continue
        fi
        
        # Switch wallet
        new_wallet="${wallets[$((selection-1))]}"
        WALLET_NAME="$new_wallet"
        echo "$WALLET_NAME" > "$CURRENT_WALLET_FILE"
        CONFIG_FLAG="--config $WALLETS_DIR/$WALLET_NAME/.config --public-rpc"
        
        echo "✅ Switched to wallet: $new_wallet"
        break
    done
}

# Function to delete a wallet
delete_wallet() {
    # First check if wallets are encrypted
    if ! check_wallet_encryption; then
        return 1
    fi
    echo
    echo "$(format_title "Delete Wallet")"
    echo
    warning_message "Warning: This operation cannot be undone!\nYou will lose access to the wallet keys and funds."
    echo
    
    # List available wallets
    if [ ! -d "$WALLETS_DIR" ]; then
        error_message "No wallets directory found"
        return 1
    fi
    
    # Only list directories that contain .config
    wallets=()
    while IFS= read -r dir; do
        if [ -d "$dir/.config" ]; then
            wallet_name=$(basename "$dir")
            wallets+=("$wallet_name")
        fi
    done < <(find "$WALLETS_DIR" -mindepth 1 -maxdepth 1 -type d)
    
    if [ ${#wallets[@]} -eq 0 ]; then
        error_message "No valid wallets found"
        return 1
    fi
    
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
    
    while true; do
        read -p "Select wallet number to delete (1-${#wallets[@]}) or 'e' to exit: " selection
        
        # Check for exit
        if [[ ${selection,,} == "e" ]]; then
            echo "Operation cancelled."
            return 1
        fi
        
        # Validate input
        if ! [[ "$selection" =~ ^[0-9]+$ ]] || \
           [ "$selection" -lt 1 ] || \
           [ "$selection" -gt ${#wallets[@]} ]; then
            error_message "Invalid selection"
            continue
        fi
        
        # Get selected wallet name
        selected_wallet="${wallets[$((selection-1))]}"
        
        # Prevent deletion of current wallet
        if [ "$selected_wallet" == "$WALLET_NAME" ]; then
            error_message "Cannot delete the currently active wallet."
            echo "Please switch to a different wallet first."
            return 1
        fi
        
        echo
        warning_message "You are about to delete wallet: $selected_wallet"
        read -p "Are you sure you want to delete this wallet? (y/n): " confirm
        
        if [[ ${confirm,,} == "y" ]]; then
            # Proceed with deletion
            if rm -rf "$WALLETS_DIR/$selected_wallet"; then
                echo "✅ Wallet '$selected_wallet' has been deleted."
            else
                error_message "Error occurred while deleting the wallet."
            fi
        else
            echo "Operation cancelled."
        fi
        break
    done
}

encrypt_decrypt_wallets() {
    echo
    echo "$(format_title "Wallet Encryption")"
    echo

    # Check current state
    if [ -f "$QCLIENT_DIR/wallets.zip" ] && [ ! -d "$WALLETS_DIR" ]; then
        # Encrypted state: only offer decrypt option
        echo "Current status: Wallets are encrypted"
        echo
        read -p "Decrypt your wallets? (y/n): " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            echo
            read -s -p "Password: " password
            echo  # New line after hidden password input
            
            if unzip -qq -P "$password" "$QCLIENT_DIR/wallets.zip" -d "$QCLIENT_DIR"; then
                if [ -d "$WALLETS_DIR" ]; then
                    echo "✅ Wallets decrypted successfully"
                    echo "Removing encrypted archive..."
                    rm "$QCLIENT_DIR/wallets.zip"
                    echo "✅ Operation completed"
                else
                    error_message "Decryption verification failed"
                fi
            else
                error_message "Decryption failed"
            fi
        else
            echo "Operation cancelled"
        fi
    elif [ -d "$WALLETS_DIR" ] && [ ! -f "$QCLIENT_DIR/wallets.zip" ]; then
        # Unencrypted state: only offer encrypt option
        echo "Current status: Wallets are unprotected"
        echo
        warning_message "IMPORTANT: If you lose the password, your wallets cannot be recovered!"
        echo "Make sure to use a strong password and store it securely."
        echo
        read -p "Encrypt your wallets? (y/n): " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            echo
            cd "$QCLIENT_DIR" || return 1
            
            # Create encrypted zip without showing the file list
            if zip -qq -r -e wallets.zip wallets/; then
                if [ -s wallets.zip ]; then
                    echo "✅ Encryption successful"
                    echo "Removing unencrypted wallets..."
                    rm -rf "$WALLETS_DIR"
                    echo "✅ Operation completed"
                    echo
                    echo "Your wallets are now encrypted in: $QCLIENT_DIR/wallets.zip"
                    echo "Keep this file and your password safe!"
                else
                    error_message "Encryption verification failed"
                    rm -f wallets.zip
                fi
            else
                error_message "Encryption failed"
            fi
        else
            echo "Operation cancelled"
        fi
    else
        # Invalid state (both or neither exist)
        if [ -f "$QCLIENT_DIR/wallets.zip" ] && [ -d "$WALLETS_DIR" ]; then
            error_message "Invalid state: Both encrypted and unencrypted wallets found"
            echo "Please manually remove either wallets.zip or the wallets directory"
        else
            error_message "No wallets found to encrypt/decrypt"
        fi
    fi
}
count_coins() {
    echo
    echo "$(format_title "Count Coins")"
    
    # Run the coins command and capture output silently
    coins_output=$($QCLIENT_EXEC token coins $FLAGS)
    
    # Count coins by counting lines containing "QUIL"
    coin_count=$(echo "$coins_output" | grep -c "QUIL")
    
    # Calculate total value
    total_value=0
    while read -r line; do
        if [[ $line =~ ([0-9]+\.[0-9]+)\ QUIL ]]; then
            value=${BASH_REMATCH[1]}
            total_value=$(echo "$total_value + $value" | bc)
        fi
    done <<< "$coins_output"
    
    echo "You currently have $coin_count coins"
    echo "Total value: $total_value QUIL"
    echo
}

help() {
    echo
    $QCLIENT_EXEC --help
    echo
}

donations() {
    echo
    echo "$(format_title "Donations")"
    echo '
Quilbrium.one is a one-man volunteer effort.
If you would like to chip in some financial help, thank you!

You can send native QUIL at this address:
0x0e15a09539c95784c8d7e1b80beb175f12967764daa7d19626cc526575483180

You can send ERC-20 tokens at this address:
0x0fd383A1cfbcf4d1F493Dd71b798ebca89e8a013

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
Repo: https://github.com/lamat1111/QuilibriumScripts
'
}

best_providers() {
    echo
    echo "$(format_title "Best Server Providers")"
    echo '
Check out the best server providers for your node
at ★ https://iri.quest/q-best-providers ★

Avoid using providers that specifically ban crypto and mining.
'
}

security_settings() {
    echo
    echo "$(format_title "Security Settings")"
    echo '
This script performs QUIL transactions. You can inspect the source code by running:
cat "'$SCRIPT_PATH/qclient_actions.sh'"

The script also auto-updates to the latest version automatically.
If you want to disable auto-updates, comment out the line "check_for_updates"
in the script itself.

DISCLAIMER:
The author assumes no responsibility for any QUIL loss due to misuse of this script.
Use this script at your own risk and always verify transactions before confirming them.
'
}


#=====================
# One-time alias setup
#=====================

# Replace the current SCRIPT_DIR definition with:
SCRIPT_DIR="$HOME/scripts"  # Hardcoded path
# Or use this more dynamic approach that follows symlinks:
#SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

ALIAS_MARKER_FILE="$SCRIPT_DIR/.q1wallet_alias_added"

add_alias_if_needed() {
    if [ ! -f "$ALIAS_MARKER_FILE" ]; then
        local comment_line="# This alias calls the \"Q1 wallet\" menu by typing \"q1wallet\""
        local alias_line="alias q1wallet='/root/scripts/$(basename "${BASH_SOURCE[0]}")'"  # Hardcoded path
        if ! grep -q "$alias_line" "$HOME/.bashrc"; then
            echo "" >> "$HOME/.bashrc"  # Add a blank line for better readability
            echo "$comment_line" >> "$HOME/.bashrc"
            echo "$alias_line" >> "$HOME/.bashrc"
            echo "Alias added to .bashrc."
            
            # Source .bashrc to make the alias immediately available
            if [ -n "$BASH_VERSION" ]; then
                source "$HOME/.bashrc"
                echo "Alias 'q1wallet' is now active."
            else
                echo "Please run 'source ~/.bashrc' or restart your terminal to use the 'qclient' command."
            fi
        fi
        touch "$ALIAS_MARKER_FILE"
    fi
}


#=====================
# Check for updates
#=====================

check_for_updates() {
    # Check if curl is available
    if ! command -v curl &> /dev/null; then
        return 1
    fi

    local GITHUB_RAW_URL="https://raw.githubusercontent.com/lamat1111/Q1-Wallet/main/q1wallet.sh"
    local SCRIPT_PATH="$QCLIENT_DIR/q1wallet.sh"  # Use QCLIENT_DIR which is already defined as $(pwd)
    local LATEST_VERSION
    
    # Fetch and extract the latest version from GitHub
    LATEST_VERSION=$(curl -sS "$GITHUB_RAW_URL" | sed -n 's/^SCRIPT_VERSION="\(.*\)"$/\1/p')
    
    # Check if version fetch was successful
    if [ $? -ne 0 ] || [ -z "$LATEST_VERSION" ]; then
        return 1
    fi
    
    echo
    echo "Current local version: $SCRIPT_VERSION"
    echo "Latest remote version: $LATEST_VERSION"
    
    # Version comparison
    if version_gt "$LATEST_VERSION" "$SCRIPT_VERSION"; then
        echo
        warning_message "A new version is available!"
        echo
        
        # Download and replace the script
        if curl -sS -o "${SCRIPT_PATH}.tmp" "$GITHUB_RAW_URL"; then
            chmod +x "${SCRIPT_PATH}.tmp"
            mv "${SCRIPT_PATH}.tmp" "$SCRIPT_PATH"
            echo "✅ Update completed successfully!"
            echo
            echo "Restarting script in 3 seconds..."
            sleep 3
            exec "$SCRIPT_PATH"  # Restart the script
        else
            error_message "Update failed"
            rm -f "${SCRIPT_PATH}.tmp"  # Clean up failed download
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
            1) check_balance; prompt_return_to_menu || break ;;
            2) create_transaction; prompt_return_to_menu || break ;;
            3) accept_transaction; prompt_return_to_menu || break ;;
            4) reject_transaction; prompt_return_to_menu || break ;;
            5) mutual_transfer; prompt_return_to_menu || break ;;
            6) check_coins; prompt_return_to_menu || break ;;
            7) token_split_advanced && prompt_return_to_menu || break;;
            8) token_merge && prompt_return_to_menu || break ;;
            9) create_new_wallet; press_any_key ;;
            10) switch_wallet; press_any_key ;;
            11) encrypt_decrypt_wallets; press_any_key ;;
            12) delete_wallet; press_any_key ;;
            [uU]) check_qclient_version; press_any_key ;;
            [sS]) security_settings; press_any_key ;;
            [bB]) best_providers; press_any_key ;;
            [dD]) donations; press_any_key ;;
            [xX]) disclaimer; press_any_key ;;
            [hH]) help; press_any_key ;;
            [eE]) echo; break ;;
            *) echo "Invalid option, please try again." ;;
        esac
    done
}


#=====================
# Run
#=====================

check_qclient_binary
#check_for_updates
#add_alias_if_needed

main
