#!/usr/bin/env python3

import os
import sys
import platform
import subprocess
import re
import shutil
import tempfile
from pathlib import Path

# Constants
SCRIPT_VERSION = "1.1.5"
INSTALL_DIR = Path.home() / "q1wallet"
SYMLINK_NAME = "q1wallet"
SYMLINK_PATH = Path(f"/usr/local/bin/{SYMLINK_NAME}") if os.name != "nt" else (INSTALL_DIR / f"{SYMLINK_NAME}.bat")
MENU_URL = "https://raw.githubusercontent.com/lamat1111/Q1-Wallet/main/python/menu.py"
QCLIENT_RELEASE_URL = "https://releases.quilibrium.com/qclient-release"
QUILIBRIUM_RELEASES = "https://releases.quilibrium.com"

# Import colorama and define colors early
import colorama
from colorama import Fore, Style
colorama.init()
RED = Fore.RED + Style.BRIGHT
ORANGE = Fore.YELLOW
GREEN = Fore.GREEN
BOLD = Style.BRIGHT
NC = Style.RESET_ALL

# Helper functions
def error_message(msg):
    return f"{RED}❌ {msg}{NC}"

def warning_message(msg):
    return f"{ORANGE}⚠️ {msg}{NC}"

def success_message(msg):
    return f"{GREEN}✅ {msg}{NC}"

def clear_screen():
    os.system('cls' if os.name == 'nt' else 'clear')

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

# Set up virtual environment
VENV_DIR = Path(INSTALL_DIR) / "venv"
def setup_virtualenv():
    print("Setting up virtual environment...")
    
    # Check if ensurepip is available by attempting a temporary venv creation
    temp_dir = tempfile.mkdtemp()
    #print(f"DEBUG: Testing venv creation in {temp_dir}")
    try:
        subprocess.run([sys.executable, "-m", "venv", temp_dir], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        shutil.rmtree(temp_dir)  # Clean up temp directory
        #print("DEBUG: Test venv creation succeeded")
    except subprocess.CalledProcessError as e:
        error_output = e.stdout.decode().lower().replace('\n', ' ').strip()  # Normalize newlines to spaces
        #print(f"DEBUG: error_output = '{error_output}'")
        #print(f"DEBUG: error_output length = {len(error_output)}")
        #print(f"DEBUG: error_output raw = {repr(error_output)}")
        #print(f"DEBUG: 'ensurepip is not available' in error_output? {'ensurepip is not available' in error_output}")
        
        if "ensurepip is not available" in error_output:
            print(warning_message("ensurepip is not available, required for virtual environment setup"))
            is_debian = platform.system().lower() == "linux" and os.path.exists("/etc/debian_version")
            #print(f"DEBUG: Is Debian-based? {is_debian}")
            if is_debian:
                print("Attempting to install python3-venv automatically...")
                try:
                    #print("DEBUG: Running 'sudo apt update' (this may take a moment)...")
                    subprocess.run(["sudo", "apt", "update"], check=True)  # No stdout/stderr redirection
                    python_version = platform.python_version_tuple()  # e.g., ('3', '10', '0')
                    venv_package = f"python{python_version[0]}.{python_version[1]}-venv"
                    #print(f"DEBUG: Running 'sudo apt install -y {venv_package}' (this may take a moment)...")
                    subprocess.run(["sudo", "apt", "install", "-y", venv_package], check=True)  # No stdout/stderr redirection
                    print(success_message(f"{venv_package} installed successfully"))
                except subprocess.CalledProcessError as install_error:
                    print(error_message(f"Failed to install {venv_package}: {install_error}"))
                    print("Please run the following commands manually:")
                    print("  sudo apt update")
                    print(f"  sudo apt install {venv_package}")
                    sys.exit(1)
            else:
                print(error_message("ensurepip is not available and automatic installation is not supported on this system"))
                print("Please install the appropriate python3-venv package manually for your distribution.")
                sys.exit(1)
        else:
            print(error_message(f"Unexpected error during venv test: {e}"))
            print(f"Command output: {e.stdout.decode()}")
            print(f"Command error: {e.stderr.decode()}")
            sys.exit(1)

    # Now create the actual virtual environment
    #print("DEBUG: Creating actual virtual environment")
    try:
        result = subprocess.run([sys.executable, "-m", "venv", "--clear", str(VENV_DIR)], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        print(success_message("Virtual environment created successfully"))
    except subprocess.CalledProcessError as e:
        print(f"Command output: {e.stdout.decode()}")
        print(f"Command error: {e.stderr.decode()}")
        print(error_message(f"Failed to create virtual environment: {e}"))
        sys.exit(1)

# Get the Python executable from the virtual environment
def get_venv_python():
    if platform.system().lower() == "windows":
        return VENV_DIR / "Scripts" / "python.exe"
    else:
        return VENV_DIR / "bin" / "python"

# Now check and install Python module dependencies in the virtual environment
def ensure_dependencies():
    required_modules = [("requests", "requests"), ("colorama", "colorama")]
    missing_modules = []
    
    venv_python = get_venv_python()
    
    for module_name, package_name in required_modules:
        try:
            subprocess.run([str(venv_python), "-c", f"import {module_name}"], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        except subprocess.CalledProcessError:
            missing_modules.append(package_name)
    
    if not missing_modules:
        return True
    
    print(f"Missing required Python modules: {', '.join(missing_modules)}")
    print("Attempting to install them automatically in the virtual environment...")
    
    if platform.system().lower() == "windows":
        pip_cmd = [str(venv_python), "-m", "pip", "install"]
    else:
        pip_cmd = [str(venv_python), "-m", "pip", "install"]
    
    for package in missing_modules:
        print(f"Installing {package}...")
        try:
            subprocess.run(pip_cmd + [package], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            print(f"✅ Successfully installed {package}")
        except subprocess.CalledProcessError as e:
            print(error_message(f"Failed to install {package}: {e}"))
            return False
    
    return True

# Call virtual environment setup before dependency installation
setup_virtualenv()
if not ensure_dependencies():
    sys.exit(1)

import requests

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
        if item.name not in ["wallets", "venv"]:
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

# Updated setup_symlink function
def setup_symlink(system):
    print("\nQuick command setup")
    print("-------------------")
    venv_python = get_venv_python()
    menu_script = INSTALL_DIR / "menu.py"
    
    if system == "windows":
        print(f"Creating '{SYMLINK_NAME}.bat' in {INSTALL_DIR}")
        bat_content = f"""@echo off
"{venv_python}" "{menu_script}" %*
"""
        with open(SYMLINK_PATH, "w") as f:
            f.write(bat_content)
        SYMLINK_PATH.chmod(0o755)  # Not strictly necessary but kept for consistency
        print(success_message(f"Created '{SYMLINK_NAME}.bat' in {INSTALL_DIR}"))
        
        if input(f"Add {INSTALL_DIR} to PATH for '{SYMLINK_NAME}' command? (requires admin, y/n): ").lower() == "y":
            if not check_sudo():
                print(error_message("Admin access required. Skipping PATH update."))
                print(f"Run manually with: {SYMLINK_PATH}")
                return
            try:
                current_path = os.environ["PATH"]
                if str(INSTALL_DIR) not in current_path:
                    subprocess.run(f'setx PATH "%PATH%;{INSTALL_DIR}"', shell=True, check=True)
                    print(success_message(f"Added to PATH. Restart your terminal to use '{SYMLINK_NAME}'"))
                else:
                    print(success_message("Already in PATH"))
            except subprocess.CalledProcessError:
                print(error_message("Failed to update PATH"))
                print(f"Run manually with: {SYMLINK_PATH}")
        else:
            print(f"To use, run: {SYMLINK_PATH}")
    
    else:  # Linux (WSL), macOS
        print(f"Installing '{SYMLINK_NAME}' to {SYMLINK_PATH} for easy access...")
        shell_script = f"""#!/bin/bash
"{venv_python}" "{menu_script}" "$@"
"""
        # Write to a temporary location first (user-writable)
        temp_script = INSTALL_DIR / "q1python_temp.sh"
        with open(temp_script, "w") as f:
            f.write(shell_script)
        temp_script.chmod(0o755)
        
        # Move to /usr/local/bin with sudo
        if check_sudo():
            try:
                subprocess.run(["sudo", "mv", str(temp_script), str(SYMLINK_PATH)], check=True)
                subprocess.run(["sudo", "chmod", "+x", str(SYMLINK_PATH)], check=True)
                print(success_message(f"'{SYMLINK_NAME}' installed! Type '{SYMLINK_NAME}' to use it."))
            except subprocess.CalledProcessError as e:
                print(error_message(f"Failed to install '{SYMLINK_NAME}': {e}"))
                print("Please run this script with 'sudo python3 install.py' or check your permissions.")
                temp_script.unlink()  # Clean up temp file
                sys.exit(1)
        else:
            print(error_message("Admin password required to install to /usr/local/bin"))
            print("Please run this script with 'sudo python3 install.py'.")
            temp_script.unlink()  # Clean up temp file
            sys.exit(1)

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
    venv_python = get_venv_python()
    subprocess.run([str(venv_python), str(INSTALL_DIR / "menu.py")])
