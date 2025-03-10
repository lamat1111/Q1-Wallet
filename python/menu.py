#!/usr/bin/env python3

import os
import sys
import platform
import subprocess
import re
import time
import shutil
import zipfile
from pathlib import Path
import threading

# Constants
SCRIPT_VERSION = "1.2.2"
QCLIENT_DIR = Path(__file__).parent.resolve()
VENV_DIR = QCLIENT_DIR / "venv"  # Match virtual environment from install.py
WALLETS_DIR = QCLIENT_DIR / "wallets"
CURRENT_WALLET_FILE = QCLIENT_DIR / ".current_wallet"
QCLIENT_RELEASE_URL = "https://releases.quilibrium.com/qclient-release"
QUILIBRIUM_RELEASES = "https://releases.quilibrium.com"

# Color definitions (using colorama after initialization)
RED = ""
ORANGE = ""
PURPLE = ""
BOLD = ""
NC = ""

# Global variables
WALLET_NAME = None
FLAGS = None
QCLIENT_EXEC = None

# Function to initialize colorama after dependencies are ensured
def init_colors():
    global RED, ORANGE, PURPLE, BOLD, NC
    from colorama import Fore, Style
    colorama.init()
    RED = Fore.RED + Style.BRIGHT
    ORANGE = Fore.YELLOW
    PURPLE = Fore.MAGENTA
    BOLD = Style.BRIGHT
    NC = Style.RESET_ALL

def ensure_dependencies():
    required_modules = [("requests", "requests"), ("colorama", "colorama")]
    missing_modules = []
    
    # Determine the Python interpreter to use (prefer virtual environment)
    venv_python = VENV_DIR / ("Scripts" if platform.system().lower() == "windows" else "bin") / "python"
    if not VENV_DIR.exists() or not venv_python.exists():
        print(f"{RED}❌ Virtual environment not found at {VENV_DIR}. Please run install.py first.{NC}")
        print("Alternative solution: Use a manual virtual environment:")
        print(f"1. Create it: '{sys.executable} -m venv {VENV_DIR}'")
        print(f"2. Activate it: 'source {VENV_DIR}/bin/activate' (Linux/macOS) or '{VENV_DIR}\\Scripts\\activate' (Windows)")
        print(f"3. Run this script again: '{venv_python} {__file__}'")
        return False
    
    # Check if pip is available in the virtual environment
    try:
        # Corrected command to check pip version
        result = subprocess.run(
            [str(venv_python), "-m", "pip", "--version"],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        print(f"pip version: {result.stdout.strip()}")
    except subprocess.CalledProcessError as e:
        print(f"{RED}❌ Error: 'pip' is not available in the virtual environment.{NC}")
        print(f"Error details: {e.stderr}")
        print(f"Please ensure {VENV_DIR} is properly set up by running install.py.")
        return False
    
    # Check for missing modules
    for module_name, package_name in required_modules:
        try:
            subprocess.run([str(venv_python), "-c", f"import {module_name}"], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        except subprocess.CalledProcessError:
            missing_modules.append(package_name)
    
    if not missing_modules:
        return True
    
    print(f"{ORANGE}Missing required modules: {', '.join(missing_modules)}{NC}")
    print("Attempting to install them in the virtual environment...")
    
    # Use virtual environment's pip for installation
    pip_cmd = [str(venv_python), "-m", "pip", "install"]
    
    for package in missing_modules:
        print(f"Installing {package}...")
        try:
            subprocess.run(pip_cmd + [package], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            print(f"{BOLD}✅ Successfully installed {package}{NC}")
        except subprocess.CalledProcessError as e:
            print(f"{RED}❌ Failed to install {package}: {e}{NC}")
            print("Try manually within the virtual environment:")
            print(f"{venv_python} -m pip install {package}")
            return False
    
    # Verify imports work after installation
    for module_name, package_name in required_modules:
        try:
            subprocess.run([str(venv_python), "-c", f"import {module_name}"], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        except subprocess.CalledProcessError:
            print(f"{RED}❌ {package_name} installed but not importable.{NC}")
            return False
    
    print(f"{BOLD}✅ All dependencies are now installed.{NC}")
    return True

# Run dependency check before any imports that require external modules
if not ensure_dependencies():
    sys.exit(1)

# Now safe to import requests and colorama
import requests
import colorama
init_colors()

# Helper Functions
def clear_screen():
    os.system('cls' if os.name == 'nt' else 'clear')

def format_title(title):
    width = len(title) + 8
    return f"\n{BOLD}=== {title} ==={NC}\n{'-' * width}"

def error_message(msg):
    print(f"{RED}❌ {msg}{NC}")

def warning_message(msg):
    print(f"{ORANGE}⚠️  {msg}{NC}")

def confirm_proceed(action_name, description=""):
    print(format_title(action_name))
    if description:
        print(description)
    while True:
        choice = input(f"Do you want to proceed with {action_name}? (y/n): ").lower()
        if choice == 'y':
            return True
        elif choice == 'n':
            print("Operation cancelled.")
            return False
        print("Please answer y or n.")

def validate_hash(hash_str):
    return bool(re.match(r"^0x[0-9a-fA-F]{64}$", hash_str))

def wait_with_spinner(message, seconds):
    chars = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    stop_event = threading.Event()
    
    def spinner():
        i = 0
        while not stop_event.is_set():
            print(f"\r{message.format(seconds)} {chars[i % len(chars)]} ", end="", flush=True)
            i += 1
            time.sleep(0.1)
        print("\r" + " " * (len(message.format(seconds)) + 2), end="\r", flush=True)
    
    thread = threading.Thread(target=spinner)
    thread.start()
    time.sleep(seconds)
    stop_event.set()
    thread.join()

def get_config_flags():
    global WALLET_NAME
    return [f"--config", str(WALLETS_DIR / WALLET_NAME / ".config"), "--public-rpc"]

def setup_initial_wallet():
    global WALLET_NAME, FLAGS
    if CURRENT_WALLET_FILE.exists():
        with open(CURRENT_WALLET_FILE, 'r') as f:
            WALLET_NAME = f.read().strip()
    else:
        config_dirs = list(WALLETS_DIR.glob("*/.config"))
        if config_dirs:
            WALLET_NAME = config_dirs[0].parent.name
        else:
            WALLET_NAME = "Wallet_1"
            (WALLETS_DIR / WALLET_NAME / ".config").mkdir(parents=True, exist_ok=True)
        with open(CURRENT_WALLET_FILE, 'w') as f:
            f.write(WALLET_NAME)
    FLAGS = get_config_flags()

# Qclient Binary Management
def get_platform_info():
    system = platform.system().lower()
    arch = platform.machine().lower()
    suffix = ".exe" if system == "windows" else ""
    arch_map = {"x86_64": "amd64", "amd64": "amd64", "arm64": "arm64", "aarch64": "arm64"}
    os_map = {"windows": "windows", "linux": "linux", "darwin": "darwin"}
    mapped_arch = arch_map.get(arch)
    mapped_os = os_map.get(system)
    if not mapped_arch or not mapped_os:
        error_message(f"Unsupported platform: {system}/{arch}")
        return None, None, None
    return mapped_os, mapped_arch, suffix

def find_qclient_binary():
    global QCLIENT_EXEC
    os_name, arch, suffix = get_platform_info()
    if not os_name:
        return None
    pattern = f"qclient-*-{os_name}-{arch}{suffix}"
    binaries = sorted(
        [f for f in QCLIENT_DIR.glob(pattern) if not f.name.endswith((".dgst", ".sig", "Zone.Identifier"))],
        key=lambda x: re.search(r'qclient-(\d+\.\d+\.\d+\.\d*)', x.name).group(1) if re.search(r'qclient-(\d+\.\d+\.\d+\.\d*)', x.name) else "0.0.0.0"
    )
    if binaries:
        QCLIENT_EXEC = binaries[-1]
        try:
            QCLIENT_EXEC.chmod(QCLIENT_EXEC.stat().st_mode | 0o111)
        except PermissionError:
            warning_message(f"Permission denied setting executable bit on {QCLIENT_EXEC}. Try running with sudo or adjust permissions manually.")
        return QCLIENT_EXEC
    return None

def version_gt(v1, v2):
    v1_parts = [int(x) for x in v1.split('.')]
    v2_parts = [int(x) for x in v2.split('.')]
    return v1_parts > v2_parts

def check_qclient_version():
    print("\nChecking Qclient version...")
    os_name, arch, suffix = get_platform_info()
    if not os_name:
        return False
    try:
        files = requests.get(QCLIENT_RELEASE_URL, timeout=10).text.splitlines()
        version_pattern = r'qclient-(\d+\.\d+\.\d+\.\d*)-{}-{}'.format(os_name, arch)
        remote_versions = [re.search(version_pattern, f).group(1) for f in files if re.search(version_pattern, f)]
        if not remote_versions:
            error_message(f"No versions found for {os_name}-{arch}")
            return False
        remote_version = max(remote_versions, key=lambda x: [int(p) for p in x.split('.')])
        
        local_binary = find_qclient_binary()
        if not local_binary:
            print("No local Qclient found.")
            return download_latest_qclient()
        
        local_version = re.search(r'qclient-(\d+\.\d+\.\d+\.\d*)', local_binary.name).group(1) or "0.0.0.0"
        print(f"Current local version: {local_version}")
        print(f"Latest remote version: {remote_version}")
        
        if version_gt(remote_version, local_version):
            warning_message("A new version of Qclient is available!")
            if download_latest_qclient():
                cleanup_old_releases(remote_version)
                print("✅ Update completed successfully!")
                time.sleep(3)
                return True
            else:
                error_message("Update failed")
                return False
        else:
            print("\n✅ You are running the latest version")
            return True
    except Exception as e:
        error_message(f"Version check failed: {e}")
        return False

def download_latest_qclient():
    global QCLIENT_EXEC
    print("\nProceed to download the latest Qclient version? (y/n)")
    if input().lower() != 'y':
        error_message("Download cancelled.")
        return False
    os_name, arch, suffix = get_platform_info()
    if not os_name:
        return False
    print("\n⏳ Downloading Qclient...")
    try:
        files = requests.get(QCLIENT_RELEASE_URL, timeout=10).text.splitlines()
        version_pattern = r'qclient-(\d+\.\d+\.\d+\.\d*)-{}-{}'.format(os_name, arch)
        versions = [re.search(version_pattern, f).group(1) for f in files if re.search(version_pattern, f)]
        if not versions:
            error_message(f"No qclient files found for {os_name}-{arch}")
            return False
        latest_version = max(versions, key=lambda x: [int(p) for p in x.split('.')])
        matched_files = [f for f in files if f"qclient-{latest_version}-{os_name}-{arch}" in f]
        for file in matched_files:
            file_path = QCLIENT_DIR / file
            if not file_path.exists():
                print(f"Downloading {file}...")
                response = requests.get(f"{QUILIBRIUM_RELEASES}/{file}", timeout=300)
                with open(file_path, 'wb') as f:
                    f.write(response.content)
                if not file.endswith((".dgst", ".sig")):
                    file_path.chmod(0o755)
        QCLIENT_EXEC = find_qclient_binary()
        if QCLIENT_EXEC:
            print(f"✅ Successfully downloaded Qclient v{latest_version} to {QCLIENT_DIR}")
            return True
        else:
            error_message("Error: Could not locate downloaded qclient binary")
            return False
    except Exception as e:
        error_message(f"Download failed: {e}")
        return False

def cleanup_old_releases(new_version):
    print("\nCleaning up old release files...")
    os_name, arch, suffix = get_platform_info()
    if not os_name:
        return
    for file in QCLIENT_DIR.glob(f"qclient-*{os_name}-{arch}*"):
        version_match = re.search(r'qclient-(\d+\.\d+\.\d+\.\d*)', file.name)
        if version_match and version_match.group(1) != new_version:
            print(f"Removing {file.name}")
            file.unlink()
    print("✅ Cleanup complete")

def check_qclient_binary():
    global QCLIENT_EXEC
    QCLIENT_EXEC = find_qclient_binary()
    if not QCLIENT_EXEC:
        error_message(f"No Qclient found in: {QCLIENT_DIR}")
        print("Qclient is required to manage your wallet.")
        return download_latest_qclient()
    return check_qclient_version()

# Wallet Encryption
def check_wallet_encryption():
    if not WALLETS_DIR.exists() and (QCLIENT_DIR / "wallets.zip").exists():
        print("\nYour wallets are encrypted.")
        password = input("Password: ")
        try:
            with zipfile.ZipFile(QCLIENT_DIR / "wallets.zip", 'r') as zf:
                zf.extractall(QCLIENT_DIR, pwd=password.encode())
            if WALLETS_DIR.exists():
                (QCLIENT_DIR / "wallets.zip").unlink()
                return True
            else:
                error_message("Decryption failed")
                return False
        except Exception as e:
            error_message(f"Decryption failed - incorrect password or corrupted archive: {e}")
            return False
    return True

def encrypt_wallets():
    if WALLETS_DIR.exists() and not (QCLIENT_DIR / "wallets.zip").exists():
        print(format_title("Wallet Encryption"))
        print("This will encrypt your wallet files to secure them with a password.")
        warning_message("IMPORTANT: If you lose the password, your wallets cannot be recovered!")
        warning_message("Make sure to use a strong password and store it securely.")
        if not confirm_proceed("Encrypt Wallets"):
            return
        os.chdir(QCLIENT_DIR)
        password = input("Password: ")
        try:
            with zipfile.ZipFile("wallets.zip", 'w', zipfile.ZIP_DEFLATED) as zf:
                zf.setpassword(password.encode())
                for root, _, files in os.walk("wallets"):
                    for file in files:
                        zf.write(Path(root) / file, Path(root) / file)
            shutil.rmtree(WALLETS_DIR)
            print(f"{BOLD}✅ Wallets encrypted successfully{NC}")
            print(f"Your wallets are now encrypted in: {QCLIENT_DIR / 'wallets.zip'}")
            print("Keep this file and your password safe!")
        except Exception as e:
            error_message(f"Encryption failed: {e}")
            print("Ensure you have write permissions in {QCLIENT_DIR}")
    else:
        if (QCLIENT_DIR / "wallets.zip").exists() and WALLETS_DIR.exists():
            error_message("Invalid state: Both encrypted and unencrypted wallets found.")
            print("Remove either wallets.zip or the wallets directory manually.")
        else:
            error_message("No wallets found to encrypt.")

# Menu Interface and Functions (unchanged structure, adjusted for consistency)
def display_menu():
    global WALLET_NAME
    clear_screen()
    print(f"""
                Q1Q1Q1\\    Q1\\   
               Q1  __Q1\\ Q1Q1 |  
               Q1 |  Q1 |\\_Q1 |  
               Q1 |  Q1 |  Q1 |  
               Q1 |  Q1 |  Q1 |  
               Q1  Q1Q1 |  Q1 |  
               \\Q1Q1Q1 / Q1Q1Q1\\ 
                \\___Q1Q\\ \\______|  QUILIBRIUM.ONE
                    \\___|        
========================================================""")
    print(f"{BOLD}Q1 WALLET (BETA) {PURPLE}{BOLD}>> {WALLET_NAME}{NC}")
    print(f"""========================================================
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
E) Exit                      v {SCRIPT_VERSION}
""")
    print(f"{ORANGE}The Q1 WALLET is still in beta. Use at your own risk.{NC}\n")

def press_any_key():
    input("\nPress Enter to continue...")
    display_menu()

def show_error_and_confirm(error_msg):
    error_message(error_msg)
    if input("\nReturn to main menu? (y/n): ").lower() == 'y':
        main()

def check_balance():
    if not check_wallet_encryption():
        return
    print(format_title("Token balance and account address"))
    result = subprocess.run([str(QCLIENT_EXEC), "token", "balance"] + FLAGS, text=True, capture_output=True)
    print(result.stdout or result.stderr)
    press_any_key()

def check_coins():
    if not check_wallet_encryption():
        return
    print(format_title("Individual coins"))
    result = subprocess.run([str(QCLIENT_EXEC), "token", "coins", "metadata"] + FLAGS, text=True, capture_output=True)
    output = result.stdout or result.stderr
    print(output)
    press_any_key()

def create_transaction():
    if not check_wallet_encryption():
        show_error_and_confirm("Wallet encryption check failed")
        return
    print(format_title("Create Transaction"))
    print("This will transfer a coin to another address.\n")
    print("IMPORTANT:\n- Ensure the recipient address is correct\n- Account address ≠ node peerID")
    if not confirm_proceed("Create Transaction"):
        main()
        return
    
    while True:
        to_address = input("\nEnter recipient's account address (or 'e' to exit): ")
        if to_address.lower() == 'e':
            print("Transaction cancelled.")
            main()
            return
        if validate_hash(to_address):
            break
        error_message("Invalid address format (must be 0x + 64 hex chars)")
    
    print("\nYour current coins before transaction:")
    print("--------------------------------------")
    check_coins()
    
    while True:
        coin_id = input("\nEnter coin ID to transfer (or 'e' to exit): ")
        if coin_id.lower() == 'e':
            print("Transaction cancelled.")
            main()
            return
        if validate_hash(coin_id):
            break
        error_message("Invalid coin ID format (must be 0x + 64 hex chars)")
    
    cmd = [str(QCLIENT_EXEC), "token", "transfer", to_address, coin_id] + FLAGS
    print(f"\nTransaction Details:\n--------------------\nRecipient: {to_address}\nCoin ID: {coin_id}")
    print(f"Command: {' '.join(cmd)}")
    if input("\nProceed with transaction? (y/n): ").lower() == 'y':
        result = subprocess.run(cmd, text=True, capture_output=True)
        if result.returncode != 0:
            show_error_and_confirm("Transaction failed")
            return
        print("\nTransaction sent. The receiver does not need to accept it.")
        wait_with_spinner("Checking updated coins in {} seconds...", 30)
        print("\nYour coins after transaction:\n-----------------------------")
        check_coins()
        print("If you don't see the changes yet, wait and check again from the main menu.")
        main()
    else:
        print("Transaction cancelled.")
        main()

def token_split_advanced():
    if not check_wallet_encryption():
        show_error_and_confirm("Wallet encryption check failed")
        return
    print(format_title("Split Coins"))
    print("This will split a coin into multiple new coins (up to 50) using different methods")
    
    while True:
        print("\nChoose split method:\n1) Split in custom amounts\n2) Split in equal amounts\n3) Split by percentages")
        split_method = input("Enter your choice (1-3 or 'e' to exit): ")
        if split_method == 'e':
            print("Operation cancelled.")
            main()
            return
        if split_method in ('1', '2', '3'):
            break
        error_message("Invalid choice. Please enter 1, 2, 3, or 'e' to exit.")
    
    print("\nYour current coins:\n-----------------")
    check_coins()
    
    while True:
        coin_id = input("\nEnter coin ID to split (or 'e' to exit): ")
        if coin_id.lower() == 'e':
            print("Operation cancelled.")
            main()
            return
        if validate_hash(coin_id):
            break
        error_message("Invalid coin ID format (must be 0x + 64 hex chars)")
    
    coin_info = subprocess.run([str(QCLIENT_EXEC), "token", "coins"] + FLAGS, text=True, capture_output=True).stdout
    match = re.search(rf"{coin_id}.*?(\d+\.\d+)\s+QUIL", coin_info)
    if not match:
        show_error_and_confirm("Could not determine coin amount.")
        return
    total_amount = float(match.group(1))
    print(f"\nSelected coin amount: {total_amount} QUIL")
    
    if split_method == '1':
        while True:
            amounts_input = input(f"\nEnter amounts separated by comma (up to 100, must sum to {total_amount})\nExample: 1.5,2.3,0.7\n> (or 'e' to exit): ")
            if amounts_input.lower() == 'e':
                print("Operation cancelled.")
                main()
                return
            amounts = amounts_input.split(',')
            if len(amounts) > 100:
                error_message("Too many values (maximum 100)")
                continue
            try:
                amounts = [float(a) for a in amounts]
                if abs(sum(amounts) - total_amount) < 0.000000000001:
                    break
                error_message(f"Sum of amounts ({sum(amounts)}) does not match coin amount ({total_amount})")
            except ValueError:
                error_message("Invalid amount format")
    
    elif split_method == '2':
        while True:
            num_parts = input("\nEnter number of parts to split into (2-100 or 'e' to exit): ")
            if num_parts.lower() == 'e':
                print("Operation cancelled.")
                main()
                return
            if not num_parts.isdigit() or not 2 <= int(num_parts) <= 100:
                error_message("Please enter a number between 2 and 100")
                continue
            num_parts = int(num_parts)
            base_amount = total_amount / num_parts
            amounts = [base_amount] * (num_parts - 1) + [total_amount - base_amount * (num_parts - 1)]
            break
    
    elif split_method == '3':
        while True:
            percentages_input = input("\nEnter percentages separated by comma (must sum to 100)\nExample: 50,30,20\n> (or 'e' to exit): ")
            if percentages_input.lower() == 'e':
                print("Operation cancelled.")
                main()
                return
            percentages = percentages_input.split(',')
            if len(percentages) > 100:
                error_message("Too many values (maximum 100)")
                continue
            try:
                percentages = [float(p) for p in percentages]
                if abs(sum(percentages) - 100) < 0.000000000001:
                    amounts = [total_amount * p / 100 for p in percentages[:-1]]
                    amounts.append(total_amount - sum(amounts))
                    break
                error_message(f"Percentages must sum to 100 (current sum: {sum(percentages)})")
            except ValueError:
                error_message("Invalid percentage format")
    
    cmd = [str(QCLIENT_EXEC), "token", "split", coin_id] + [str(a) for a in amounts] + FLAGS
    print(f"\nSplit Details:\n--------------\nOriginal Coin: {coin_id}\nOriginal Amount: {total_amount} QUIL")
    print(f"Number of parts: {len(amounts)}\nSplit amounts:")
    for i, amount in enumerate(amounts, 1):
        print(f"Part {i}: {amount} QUIL")
    print(f"Command: {' '.join(cmd)}")
    if input("\nProceed with this split? (y/n): ").lower() == 'y':
        result = subprocess.run(cmd, text=True, capture_output=True)
        if result.returncode != 0:
            show_error_and_confirm("Split operation failed")
            return
        wait_with_spinner("Showing your coins in {} secs...", 30)
        print("\nYour coins after splitting:\n---------------------------")
        check_coins()
        print("If you don't see the changes yet, wait and check again from the main menu.")
        main()
    else:
        print("Split operation cancelled.")
        main()

def token_merge():
    if not check_wallet_encryption():
        show_error_and_confirm("Wallet encryption check failed")
        return
    print(format_title("Merge Coins"))
    print("This function allows you to merge either two specific coins or all your coins into a single coin")
    if not confirm_proceed("Merge Coins"):
        main()
        return
    
    while True:
        print("\nChoose merge option:\n1) Merge two specific coins\n2) Merge all coins")
        merge_choice = input("Enter your choice (1-2 or 'e' to exit): ")
        if merge_choice == 'e':
            print("Operation cancelled.")
            main()
            return
        if merge_choice in ('1', '2'):
            break
        error_message("Invalid choice. Please enter 1, 2, or 'e' to exit.")
    
    if merge_choice == '1':
        print("\nYour current coins before merging:\n----------------------------------")
        coins_output = subprocess.run([str(QCLIENT_EXEC), "token", "coins"] + FLAGS, text=True, capture_output=True).stdout
        print(coins_output)
        coin_count = len([line for line in coins_output.splitlines() if "QUIL" in line])
        if coin_count < 2:
            show_error_and_confirm("Not enough coins to merge. You need at least 2 coins.")
            return
        
        while True:
            left_coin = input("\nEnter the first coin ID (or 'e' to exit): ")
            if left_coin.lower() == 'e':
                print("Operation cancelled.")
                main()
                return
            if validate_hash(left_coin):
                break
            error_message("Invalid coin ID format (must be 0x + 64 hex chars)")
        
        while True:
            right_coin = input("Enter the second coin ID (or 'e' to exit): ")
            if right_coin.lower() == 'e':
                print("Operation cancelled.")
                main()
                return
            if validate_hash(right_coin):
                break
            error_message("Invalid coin ID format (must be 0x + 64 hex chars)")
        
        cmd = [str(QCLIENT_EXEC), "token", "merge", left_coin, right_coin] + FLAGS
        print(f"\nMerge Details:\n--------------\nFirst Coin: {left_coin}\nSecond Coin: {right_coin}")
        print(f"Command: {' '.join(cmd)}")
        if input("\nProceed with this merge? (y/n): ").lower() == 'y':
            result = subprocess.run(cmd, text=True, capture_output=True)
            if result.returncode != 0:
                show_error_and_confirm("Merge operation failed")
                return
    else:
        coin_count = len([line for line in subprocess.run([str(QCLIENT_EXEC), "token", "coins"] + FLAGS, text=True, capture_output=True).stdout.splitlines() if "QUIL" in line])
        if coin_count < 2:
            show_error_and_confirm("Not enough coins to merge. You need at least 2 coins.")
            return
        cmd = [str(QCLIENT_EXEC), "token", "merge", "all"] + FLAGS
        print(f"Command: {' '.join(cmd)}")
        if input("\nProceed with merging all coins? (y/n): ").lower() == 'y':
            result = subprocess.run(cmd, text=True, capture_output=True)
            if result.returncode != 0:
                show_error_and_confirm("Merge operation failed")
                return
    
    wait_with_spinner("Showing your coins in {} secs...", 30)
    print("\nYour coins after merging:\n-------------------------")
    check_coins()
    print("If you don't see the changes yet, wait and check again from the main menu.")
    main()

def create_new_wallet():
    global WALLET_NAME, FLAGS
    if not check_wallet_encryption():
        show_error_and_confirm("Wallet encryption check failed")
        return
    print(format_title("Create Wallet"))
    while True:
        new_wallet = input("\nEnter new wallet name (or 'e' to exit): ")
        if new_wallet.lower() == 'e':
            print("Operation cancelled.")
            main()
            return
        if not re.match(r"^[a-z0-9_-]+$", new_wallet):
            error_message("Invalid wallet name. Use only lowercase letters, numbers, dashes, underscores")
            continue
        wallet_path = WALLETS_DIR / new_wallet
        if wallet_path.exists():
            error_message(f"Wallet '{new_wallet}' already exists")
            continue
        (wallet_path / ".config").mkdir(parents=True)
        WALLET_NAME = new_wallet
        with open(CURRENT_WALLET_FILE, 'w') as f:
            f.write(WALLET_NAME)
        FLAGS = get_config_flags()
        print(f"\n{BOLD}✅ Created new wallet: {new_wallet}{NC}")
        print(f"{BOLD}✅ Switched to new wallet{NC}")
        check_balance()
        print("Your new wallet is ready to use!")
        main()
        return

def switch_wallet():
    global WALLET_NAME, FLAGS
    if not check_wallet_encryption():
        show_error_and_confirm("Wallet encryption check failed")
        return
    print(format_title("Switch Wallet"))
    wallets = [d.name for d in WALLETS_DIR.iterdir() if (d / ".config").exists()]
    if not wallets:
        show_error_and_confirm("No valid wallets found")
        return
    while True:
        print("\nAvailable wallets:\n-----------------")
        for i, w in enumerate(wallets, 1):
            suffix = " (current)" if w == WALLET_NAME else ""
            print(f"{i}) {w}{suffix}")
        selection = input(f"\nSelect wallet number (1-{len(wallets)} or 'e' to exit): ")
        if selection.lower() == 'e':
            print("Operation cancelled.")
            main()
            return
        if not selection.isdigit() or not 1 <= int(selection) <= len(wallets):
            error_message(f"Invalid selection. Choose 1-{len(wallets)}")
            continue
        new_wallet = wallets[int(selection) - 1]
        if new_wallet == WALLET_NAME:
            error_message("Already using this wallet")
            continue
        WALLET_NAME = new_wallet
        with open(CURRENT_WALLET_FILE, 'w') as f:
            f.write(WALLET_NAME)
        FLAGS = get_config_flags()
        print(f"\n{BOLD}✅ Switched to wallet: {new_wallet}{NC}")
        main()
        return

def delete_wallet():
    global WALLET_NAME
    if not check_wallet_encryption():
        show_error_and_confirm("Wallet encryption check failed")
        return
    description = "⚠️  WARNING: This operation cannot be undone!\nYou will lose access to the wallet keys and funds."
    if not confirm_proceed("Delete Wallet", description):
        main()
        return
    wallets = [d.name for d in WALLETS_DIR.iterdir() if (d / ".config").exists()]
    if not wallets:
        show_error_and_confirm("No valid wallets found")
        return
    while True:
        print("\nAvailable wallets:\n-----------------")
        for i, w in enumerate(wallets, 1):
            suffix = " (current)" if w == WALLET_NAME else ""
            print(f"{i}) {w}{suffix}")
        selection = input(f"\nSelect wallet number to delete (1-{len(wallets)} or 'e' to exit): ")
        if selection.lower() == 'e':
            print("Operation cancelled.")
            main()
            return
        if not selection.isdigit() or not 1 <= int(selection) <= len(wallets):
            error_message(f"Invalid selection. Choose 1-{len(wallets)}")
            continue
        selected_wallet = wallets[int(selection) - 1]
        if selected_wallet == WALLET_NAME:
            error_message("Cannot delete the currently active wallet. Switch first.")
            continue
        warning_message(f"You are about to delete wallet: {selected_wallet}")
        print("This action cannot be undone!")
        if input("\nAre you absolutely sure? (y/n): ").lower() != 'y':
            print("Deletion cancelled.")
            continue
        print("Final confirmation required.")
        if input(f"Type the wallet name '{selected_wallet}' to confirm: ") != selected_wallet:
            error_message("Wallet name confirmation did not match. Deletion cancelled")
            continue
        shutil.rmtree(WALLETS_DIR / selected_wallet)
        print(f"\n{BOLD}✅ Wallet '{selected_wallet}' has been deleted.{NC}")
        main()
        return

def encrypt_decrypt_wallets():
    if (QCLIENT_DIR / "wallets.zip").exists() and not WALLETS_DIR.exists():
        print(format_title("Wallet Decryption"))
        print("This will decrypt your wallet files using your password.")
        print("Current status: Wallets are encrypted")
        if not confirm_proceed("Decrypt Wallets"):
            return
        password = input("Password: ")
        try:
            with zipfile.ZipFile(QCLIENT_DIR / "wallets.zip", 'r') as zf:
                zf.extractall(QCLIENT_DIR, pwd=password.encode())
            (QCLIENT_DIR / "wallets.zip").unlink()
            print(f"{BOLD}✅ Wallets decrypted successfully{NC}")
        except Exception as e:
            error_message(f"Decryption failed - incorrect password or corrupted archive: {e}")
            print("Ensure you have write permissions in {QCLIENT_DIR}")
    else:
        encrypt_wallets()

def help_menu():
    print(format_title("WALLET COMMANDS HELP"))
    print("""
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
""")
    press_any_key()

def import_wallet():
    print(format_title("Import Wallet"))
    print(f"""
To import a new wallet, create a folder in {WALLETS_DIR} (the folder name will be your wallet name),
then create a .config folder inside it, and paste your current wallet config.yml file there.
""")
    press_any_key()

def donations():
    print(format_title("Donations"))
    print("""
Quilbrium.one is a one-man volunteer effort.
If you would like to chip in some financial help, thank you!

You can send native QUIL at this address:
0x0e15a09539c95784c8d7e1b80beb175f12967764daa7d19626cc526575483180

You can send ERC-20 tokens at this address:
0x0fd383A1cfbcf4d1F493Dd71b798ebca89e8a013

Or visit this page: https://iri.quest/q-donations
""")
    press_any_key()

def disclaimer():
    print(format_title("Disclaimer"))
    print("""
This tool and all related scripts are unofficial and are being shared as-is.
I take no responsibility for potential bugs or any misuse of the available options. 

All scripts are open source; feel free to inspect them before use.
Repo: https://github.com/lamat1111/Q1-Wallet
""")
    press_any_key()

def security_settings():
    print(format_title("Security Settings"))
    print(f"""
This script performs QUIL transactions. You can inspect the source code by viewing:
{QCLIENT_DIR / 'menu.py'}

The script also auto-updates to the latest version automatically.
If you want to disable auto-updates, comment out the 'check_for_updates()' call
in the script itself.

DISCLAIMER:
The author assumes no responsibility for any QUIL loss due to misuse of this script.
Use this script at your own risk and always verify transactions before confirming them.
""")
    press_any_key()

def check_for_updates():
    try:
        response = requests.get("https://raw.githubusercontent.com/lamat1111/Q1-Wallet/main/menu.py", timeout=10)
        latest_version = re.search(r'SCRIPT_VERSION = "([^"]+)"', response.text).group(1)
        print(f"\nCurrent local version: {SCRIPT_VERSION}\nLatest remote version: {latest_version}")
        if version_gt(latest_version, SCRIPT_VERSION):
            warning_message("A new version is available!")
            if confirm_proceed("Update Now"):
                temp_file = QCLIENT_DIR / "menu.py.new"
                with open(temp_file, 'wb') as f:
                    f.write(response.content)
                os.replace(temp_file, __file__)  # Atomic replace
                print("✅ Updated. Restarting...")
                os.execv(sys.executable, [sys.executable] + sys.argv)
        else:
            print("\n✅ Running latest version")
    except Exception as e:
        error_message(f"Update check failed: {e}")

# Main Menu Loop
def main():
    while True:
        display_menu()
        choice = input("Enter your choice: ").lower()
        if choice == '1':
            check_balance()
        elif choice == '2':
            create_transaction()
        elif choice == '6':
            check_coins()
        elif choice == '7':
            token_merge()
        elif choice == '8':
            token_split_advanced()
        elif choice == '10':
            create_new_wallet()
        elif choice == '11':
            import_wallet()
        elif choice == '12':
            switch_wallet()
        elif choice == '13':
            encrypt_decrypt_wallets()
        elif choice == '14':
            delete_wallet()
        elif choice == 'u':
            check_qclient_version()
        elif choice == 's':
            security_settings()
        elif choice == 'd':
            donations()
        elif choice == 'x':
            disclaimer()
        elif choice == 'h':
            help_menu()
        elif choice == 'e':
            print("\nExiting...")
            sys.exit(0)
        else:
            print("Invalid option, please try again.")
            press_any_key()

# Run
if __name__ == "__main__":
    if not check_qclient_binary():
        sys.exit(1)
    setup_initial_wallet()
    check_for_updates()  # Runs silently unless update needed, then flows to main()
    main()
