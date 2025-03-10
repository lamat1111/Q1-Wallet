#!/usr/bin/env python3

import os
import sys
import platform
import subprocess
import re
import shutil
from pathlib import Path

# Initial dependency check for Python and pip
def check_python_and_pip():
    try:
        subprocess.run([sys.executable, "--version"], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except FileNotFoundError:
        print(error_message("Python 3 is not installed or not in PATH"))
        if platform.system().lower() == "linux":
            print("Install it with: sudo apt install python3")
        elif platform.system().lower() == "darwin":
            print("Install it with: brew install python3")
        elif platform.system().lower() == "windows":
            print("Download from: https://www.python.org/downloads/")
        sys.exit(1)
    
    try:
        subprocess.run([sys.executable, "-m", "pip", "--version"], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except subprocess.CalledProcessError:
        print(error_message("pip is not installed"))
        if platform.system().lower() == "linux":
            print("Install it with: sudo apt install python3-pip")
        elif platform.system().lower() == "darwin":
            print("Install it with: brew install python3")
        elif platform.system().lower() == "windows":
            print("Run: python -m ensurepip --upgrade && python -m pip install --upgrade pip")
        sys.exit(1)

check_python_and_pip()

# Now check and install Python module dependencies
def ensure_dependencies():
    required_modules = [("requests", "requests"), ("colorama", "colorama")]
    missing_modules = []
    
    for module_name, package_name in required_modules:
        try:
            __import__(module_name)
        except ImportError:
            missing_modules.append(package_name)
    
    if not missing_modules:
        return True
    
    print(f"Missing required Python modules: {', '.join(missing_modules)}")
    print("Attempting to install them automatically...")
    pip_cmd = [sys.executable, "-m", "pip", "install"]
    
    for package in missing_modules:
        print(f"Installing {package}...")
        try:
            subprocess.run(pip_cmd + [package], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            print(f"✅ Successfully installed {package}")
        except subprocess.CalledProcessError as e:
            print(error_message(f"Failed to install {package}: {e}"))
            return False
    
    return True

if not ensure_dependencies():
    sys.exit(1)

import requests
import colorama
from colorama import Fore, Style

# Initialize colorama
colorama.init()

# Constants
SCRIPT_VERSION = "1.1.4"
INSTALL_DIR = Path.home() / "q1wallet"  # Change this to Path.home() / "q1wallet_python" for your test
SYMLINK_PATH = Path("/usr/local/bin/q1wallet") if os.name != "nt" else (INSTALL_DIR / "q1wallet.bat")
MENU_URL = "https://raw.githubusercontent.com/lamat1111/Q1-Wallet/main/test/menu.py"
QCLIENT_RELEASE_URL = "https://releases.quilibrium.com/qclient-release"
QUILIBRIUM_RELEASES = "https://releases.quilibrium.com"

# Color definitions
RED = Fore.RED + Style.BRIGHT
ORANGE = Fore.YELLOW
GREEN = Fore.GREEN
BOLD = Style.BRIGHT
NC = Style.RESET_ALL

# Helper Functions
def error_message(msg):
    return f"{RED}❌ {msg}{NC}"

def warning_message(msg):
    return f"{ORANGE}⚠️ {msg}{NC}"

def success_message(msg):
    return f"{GREEN}✅ {msg}{NC}"

def clear_screen():
    os.system('cls' if os.name == 'nt' else 'clear')

def check_sudo():
    if os.name == "nt":
        try:
            import ctypes
            return ctypes.windll.shell32.IsUserAnAdmin() != 0
        except:
            return False
    try:
        subprocess.run(["sudo", "-n", "true"], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return True
    except subprocess.CalledProcessError:
        print("Sudo access is required to create the quick command.")
        try:
            subprocess.run(["sudo", "true"], check=True)
            return True
        except subprocess.CalledProcessError:
            print(error_message("Failed to obtain sudo privileges. Command creation aborted."))
            return False

def check_system_compatibility():
    system = platform.system().lower()
    arch = platform.machine().lower()
    supported_os = {"linux": ["x86_64", "aarch64"], "darwin": ["x86_64", "arm64"], "windows": ["x86_64", "amd64"]}
    if system not in supported_os:
        print(error_message(f"Unsupported operating system: {system}"))
        sys.exit(1)
    if arch not in supported_os[system]:
        print(error_message(f"Unsupported architecture: {arch} on {system}"))
        sys.exit(1)
    return system, arch

def check_existing_installation():
    if (INSTALL_DIR / "menu.py").exists() and INSTALL_DIR.exists():
        print(f"\n{ORANGE}Existing Q1 Wallet installation detected!{NC}")
        print(f"Location: {INSTALL_DIR}")
        
        wallet_dirs = [d for d in (INSTALL_DIR / "wallets").glob("*") if d.is_dir()]
        if wallet_dirs:
            print("\nExisting wallets found:")
            for wallet in wallet_dirs:
                print(f"- {wallet.name}")
        
        print("\nPlease choose an option:")
        print("1. Exit installation")
        print("2. Reinstall software only (keeps wallets and configuration)")
        print(f"3. Complete reinstall ({RED}WARNING: WILL DELETE ALL EXISTING WALLETS{NC})")
        
        while True:
            choice = input("Enter your choice (1-3): ")
            if choice == "1":
                print("Installation cancelled")
                sys.exit(0)
            elif choice == "2":
                reinstall_software_only()
                return True
            elif choice == "3":
                confirm_full_reinstall()
                return True
            print(error_message("Invalid choice. Please enter 1, 2, or 3"))

def reinstall_software_only():
    print("\nReinstalling Q1 Wallet software...")
    print("Keeping existing wallets and configuration")
    
    current_wallet = INSTALL_DIR / ".current_wallet"
    if current_wallet.exists():
        shutil.copy(current_wallet, INSTALL_DIR / ".current_wallet.bak")
    
    for item in INSTALL_DIR.iterdir():
        if item.name != "wallets":
            if item.is_dir():
                shutil.rmtree(item)
            else:
                item.unlink()
    
    if (INSTALL_DIR / ".current_wallet.bak").exists():
        shutil.move(INSTALL_DIR / ".current_wallet.bak", current_wallet)

def confirm_full_reinstall():
    print(f"\n{RED}WARNING: This will delete ALL existing wallets and data in {INSTALL_DIR}{NC}")
    print("This action cannot be undone!")
    if input("Do you want to proceed? (y/n): ").lower() != "y":
        print("Installation cancelled")
        sys.exit(0)
    shutil.rmtree(INSTALL_DIR, ignore_errors=True)
    INSTALL_DIR.mkdir(parents=True)

def check_wallet_exists(wallet_name):
    return (INSTALL_DIR / "wallets" / wallet_name).exists()

def handle_wallet_creation(wallet_name):
    if wallet_name:
        if check_wallet_exists(wallet_name):
            print(warning_message(f"Wallet '{wallet_name}' already exists"))
            if input("Would you like to create a different wallet? (y/n): ").lower() == "y":
                while True:
                    wallet_name = input("Enter new wallet name (a-z, 0-9, -, _): ")
                    if not re.match(r"^[a-z0-9_-]+$", wallet_name):
                        print(error_message("Invalid wallet name. Use only lowercase letters, numbers, dashes, underscores"))
                        continue
                    if check_wallet_exists(wallet_name):
                        print(error_message(f"Wallet '{wallet_name}' already exists"))
                        continue
                    break
            else:
                return ""
        (INSTALL_DIR / "wallets" / wallet_name / ".config").mkdir(parents=True)
        with open(INSTALL_DIR / ".current_wallet", "w") as f:
            f.write(wallet_name)
        print(success_message(f"Wallet '{wallet_name}' created successfully"))
        return wallet_name
    return ""

def setup_symlink(system):
    print("\nQuick command setup")
    print("-------------------")
    if system == "windows":
        print("Creating a 'q1wallet.bat' file for easy access.")
        bat_content = f"""@echo off
"{sys.executable}" "{INSTALL_DIR / 'menu.py'}" %*
"""
        with open(SYMLINK_PATH, "w") as f:
            f.write(bat_content)
        SYMLINK_PATH.chmod(0o755)
        
        if input("Add to PATH for 'q1wallet' command? (requires admin, y/n): ").lower() == "y":
            if not check_sudo():
                print(error_message("Admin access required to modify PATH"))
                print(f"Run manually with: {SYMLINK_PATH}")
                return
            try:
                current_path = os.environ["PATH"]
                if str(INSTALL_DIR) not in current_path:
                    subprocess.run(f'setx PATH "%PATH%;{INSTALL_DIR}"', shell=True, check=True)
                    print(success_message("Added to PATH. Restart your terminal to use 'q1wallet'"))
                else:
                    print(success_message("Already in PATH"))
            except subprocess.CalledProcessError:
                print(error_message("Failed to update PATH"))
                print(f"Run manually with: {SYMLINK_PATH}")
        else:
            print(f"Run manually with: {SYMLINK_PATH}")
    else:
        print("Create a 'q1wallet' command to call the menu from anywhere.")
        if input("Would you like to set up the quick command? (y/n): ").lower() != "y":
            print(f"Skipping quick command setup. Run 'python3 {INSTALL_DIR / 'menu.py'}' to use.")
            return
        
        if SYMLINK_PATH.exists() and SYMLINK_PATH.resolve() == (INSTALL_DIR / "menu.py"):
            print(success_message("Command 'q1wallet' is already set up correctly"))
            return
        
        if not check_sudo():
            print(f"To create it later, run: sudo ln -sf {INSTALL_DIR / 'menu.py'} {SYMLINK_PATH}")
            return
        
        SYMLINK_PATH.parent.mkdir(parents=True, exist_ok=True)
        if SYMLINK_PATH.exists() and not SYMLINK_PATH.is_symlink():
            print(error_message(f"A file exists at {SYMLINK_PATH} but is not a symlink. Remove it manually"))
            return
        
        try:
            subprocess.run(["sudo", "ln", "-sf", str(INSTALL_DIR / "menu.py"), str(SYMLINK_PATH)], check=True)
            if SYMLINK_PATH.exists():
                print(success_message("Command 'q1wallet' installed successfully!"))
                print("You can now run 'q1wallet' from anywhere")
            else:
                print(error_message("Symlink creation failed"))
        except subprocess.CalledProcessError:
            print(error_message("Failed to create quick command 'q1wallet'"))
            print(f"To create it later, run: sudo ln -sf {INSTALL_DIR / 'menu.py'} {SYMLINK_PATH}")

# Main Installer Logic
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
=================================================================
             Welcome to Q1 Wallet Installer - {SCRIPT_VERSION}
=================================================================""")
system, arch = check_system_compatibility()
check_existing_installation()
os.chdir(INSTALL_DIR)

print("\nWould you like to create a new wallet now? (y/n): ")
wallet_name = ""
if input().lower() == "y":
    while True:
        wallet_name = input("Enter wallet name (a-z, 0-9, -, _): ")
        if not re.match(r"^[a-z0-9_-]+$", wallet_name):
            print(error_message("Invalid wallet name. Use only lowercase letters, numbers, dashes, underscores"))
            continue
        if check_wallet_exists(wallet_name):
            print(error_message(f"Wallet '{wallet_name}' already exists"))
            continue
        break

print("\nCreating directory structure...")
(INSTALL_DIR / "wallets").mkdir(parents=True, exist_ok=True)

print("Downloading Q1 Wallet script...")
response = requests.get(MENU_URL)
with open(INSTALL_DIR / "menu.py", "wb") as f:
    f.write(response.content)
(INSTALL_DIR / "menu.py").chmod(0o755)

print(f"Detecting system: {system}-{arch}")
os_map = {"linux": "linux", "darwin": "darwin", "windows": "windows"}
arch_map = {"x86_64": "amd64", "amd64": "amd64", "aarch64": "arm64", "arm64": "arm64"}
release_os = os_map[system]
release_arch = arch_map[arch]
suffix = ".exe" if system == "windows" else ""

print(f"\nDownloading qclient for {release_os}-{release_arch}...")
files = requests.get(QCLIENT_RELEASE_URL).text.splitlines()
version_pattern = rf"qclient-(\d+\.\d+\.\d+\.\d*)-{release_os}-{release_arch}{suffix}"
versions = [re.search(version_pattern, f).group(1) for f in files if re.search(version_pattern, f)]
if not versions:
    print(error_message(f"No qclient files found for {release_os}-{release_arch}"))
    sys.exit(1)
latest_version = max(versions, key=lambda x: [int(p) for p in x.split('.')])
matched_files = [f for f in files if f"qclient-{latest_version}-{release_os}-{release_arch}" in f]
for file in matched_files:
    print(f"Downloading {file}...")
    response = requests.get(f"{QUILIBRIUM_RELEASES}/{file}", timeout=300)
    with open(INSTALL_DIR / file, "wb") as f:
        f.write(response.content)
    if not file.endswith((".dgst", ".sig")):
        (INSTALL_DIR / file).chmod(0o755)

wallet_name = handle_wallet_creation(wallet_name)

print("\n" + success_message("Installation completed successfully!"))
print(f"\nInstallation details:\n--------------------\nLocation: {INSTALL_DIR}")
if wallet_name:
    print(f"Wallet created: {wallet_name}")
print("""
IMPORTANT SECURITY STEPS:
------------------------
1. Back up your wallet keys:
   After creating your wallet, locate the key files in:
   {}/wallets/{}
   Copy these to an encrypted USB drive for secure storage.
   DO NOT upload them online.

2. Encrypt your wallet files:
   Use the 'Encrypt Wallet' option from the menu to secure your wallet files
   with a password when not in use.
""".format(INSTALL_DIR, wallet_name or "<wallet_name>"))

setup_symlink(system)

if input("\nWould you like to start Q1 Wallet now? (y/n): ").lower() == "y":
    subprocess.run([sys.executable, str(INSTALL_DIR / "menu.py")])
