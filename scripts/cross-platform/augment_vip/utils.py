"""
Utility functions for the Augment VIP project
Cross-platform support for Windows, macOS, and Linux
"""

import os
import sys
import platform
import json
import sqlite3
import uuid
import shutil
from pathlib import Path
from typing import List, Dict, Any, Optional, Tuple

# Console colors
try:
    from colorama import init, Fore, Style
    init()  # Initialize colorama for Windows support
    
    def info(msg: str) -> None:
        """Print an info message in blue"""
        print(f"{Fore.BLUE}[INFO]{Style.RESET_ALL} {msg}")
    
    def success(msg: str) -> None:
        """Print a success message in green"""
        print(f"{Fore.GREEN}[SUCCESS]{Style.RESET_ALL} {msg}")
    
    def warning(msg: str) -> None:
        """Print a warning message in yellow"""
        print(f"{Fore.YELLOW}[WARNING]{Style.RESET_ALL} {msg}")
    
    def error(msg: str) -> None:
        """Print an error message in red"""
        print(f"{Fore.RED}[ERROR]{Style.RESET_ALL} {msg}")

except ImportError:
    # Fallback if colorama is not installed
    def info(msg: str) -> None:
        print(f"[INFO] {msg}")
    
    def success(msg: str) -> None:
        print(f"[SUCCESS] {msg}")
    
    def warning(msg: str) -> None:
        print(f"[WARNING] {msg}")
    
    def error(msg: str) -> None:
        print(f"[ERROR] {msg}")


def get_vscode_paths() -> Dict[str, Path]:
    """
    Get VS Code paths based on the operating system
    
    Returns:
        Dict with paths to VS Code directories and files
    """
    system = platform.system()
    paths = {}
    
    if system == "Windows":
        appdata = os.environ.get("APPDATA")
        if not appdata:
            error("APPDATA environment variable not found")
            sys.exit(1)
        base_dir = Path(appdata) / "Code" / "User"
        
    elif system == "Darwin":  # macOS
        base_dir = Path.home() / "Library" / "Application Support" / "Code" / "User"
        
    elif system == "Linux":
        base_dir = Path.home() / ".config" / "Code" / "User"
        
    else:
        error(f"Unsupported operating system: {system}")
        sys.exit(1)
    
    # Common paths
    paths["base_dir"] = base_dir
    paths["storage_json"] = base_dir / "globalStorage" / "storage.json"
    paths["state_db"] = base_dir / "globalStorage" / "state.vscdb"
    paths["workspace_storage"] = base_dir / "workspaceStorage"
    
    return paths


def get_all_vscode_databases() -> List[Path]:
    """
    Get all VS Code database files
    
    Returns:
        List of paths to VS Code database files
    """
    paths = get_vscode_paths()
    database_files = []
    
    # Add global state database
    if paths["state_db"].exists():
        database_files.append(paths["state_db"])
    
    # Add workspace databases
    workspace_dir = paths["workspace_storage"]
    if workspace_dir.exists():
        for workspace_folder in workspace_dir.iterdir():
            if workspace_folder.is_dir():
                state_db = workspace_folder / "state.vscdb"
                if state_db.exists():
                    database_files.append(state_db)
    
    return database_files


def backup_file(file_path: Path) -> Path:
    """
    Create a backup of a file
    
    Args:
        file_path: Path to the file to backup
        
    Returns:
        Path to the backup file
    """
    if not file_path.exists():
        error(f"File not found: {file_path}")
        sys.exit(1)
    
    backup_path = Path(f"{file_path}.backup")
    shutil.copy2(file_path, backup_path)
    success(f"Created backup at: {backup_path}")
    return backup_path


def generate_machine_id() -> str:
    """Generate a random 64-character hex string for machineId"""
    return uuid.uuid4().hex + uuid.uuid4().hex


def generate_device_id() -> str:
    """Generate a random UUID v4 for devDeviceId"""
    return str(uuid.uuid4())


def generate_sqm_id() -> str:
    """Generate a random UUID v4 for sqmId"""
    return str(uuid.uuid4())


def get_system_info() -> Dict[str, str]:
    """
    Get system information
    
    Returns:
        Dictionary with system information
    """
    return {
        "system": platform.system(),
        "release": platform.release(),
        "version": platform.version(),
        "machine": platform.machine(),
        "processor": platform.processor(),
        "python_version": platform.python_version()
    }


def check_vscode_running() -> bool:
    """
    Check if VS Code is currently running
    
    Returns:
        True if VS Code is running, False otherwise
    """
    import psutil
    
    try:
        for proc in psutil.process_iter(['pid', 'name']):
            if proc.info['name'] and 'code' in proc.info['name'].lower():
                return True
    except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
        pass
    except ImportError:
        warning("psutil not available, cannot check if VS Code is running")
    
    return False
