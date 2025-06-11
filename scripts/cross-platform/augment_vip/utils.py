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
import re
from pathlib import Path
from typing import List, Dict, Any, Optional, Tuple

# Security exception class
class SecurityError(Exception):
    """Raised when a security violation is detected"""
    pass

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
    Create a backup of a file with security validation

    Args:
        file_path: Path to the file to backup

    Returns:
        Path to the backup file
    """
    # Validate file path for security
    if not validate_file_path(str(file_path)):
        error("Invalid file path provided")
        sys.exit(1)

    if not file_path.exists():
        error(f"File not found: {sanitize_error_message(str(file_path))}")
        sys.exit(1)

    backup_path = Path(f"{file_path}.backup")

    # Validate backup path as well
    if not validate_file_path(str(backup_path)):
        error("Invalid backup path generated")
        sys.exit(1)

    try:
        shutil.copy2(file_path, backup_path)
        success(f"Created backup at: {sanitize_error_message(str(backup_path))}")
        return backup_path
    except Exception as e:
        error(f"Failed to create backup: {sanitize_error_message(str(e))}")
        sys.exit(1)


# ID generation functions moved to unified service
# Import from common ID generator for consistency
try:
    # SECURITY FIX: Add common directory to path with validation
    common_path = os.path.join(os.path.dirname(__file__), '..', '..', 'common')
    # Validate the path doesn't escape the project directory
    common_path = os.path.abspath(common_path)
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
    if not common_path.startswith(project_root):
        raise SecurityError(f"SECURITY: Path traversal detected - common path outside project: {common_path}")
    sys.path.append(common_path)
    from id_generator import (
        generate_machine_id, generate_device_id, generate_sqm_id,
        generate_session_id, generate_instance_id, generate_timestamp
    )
except ImportError:
    # Fallback implementations if unified service is not available
    def generate_machine_id() -> str:
        """Generate a random 64-character hex string for machineId"""
        return uuid.uuid4().hex + uuid.uuid4().hex

    def generate_device_id() -> str:
        """Generate a random UUID v4 for devDeviceId"""
        return str(uuid.uuid4())

    def generate_sqm_id() -> str:
        """Generate a random UUID v4 for sqmId"""
        return str(uuid.uuid4())

    def generate_session_id() -> str:
        """Generate a random UUID v4 for sessionId"""
        return str(uuid.uuid4())

    def generate_instance_id() -> str:
        """Generate a random UUID v4 for instanceId"""
        return str(uuid.uuid4())

    def generate_timestamp() -> str:
        """Generate timestamp in ISO format"""
        from datetime import datetime
        return datetime.utcnow().isoformat() + "Z"


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


def validate_file_path(file_path: str) -> bool:
    """
    Validate file path to prevent path traversal attacks

    Args:
        file_path: File path to validate

    Returns:
        True if path is safe, False otherwise
    """
    if not file_path:
        return False

    # Convert to Path object for normalization
    try:
        path = Path(file_path).resolve()
    except (OSError, ValueError):
        return False

    # Check for dangerous patterns
    dangerous_patterns = [
        r'\.\.[\\/]',  # Parent directory traversal
        r'^[\\/]',     # Absolute paths starting with / or \
        r'[<>:"|?*]',  # Invalid filename characters
        r'^\s*$',      # Empty or whitespace-only
    ]

    path_str = str(path)
    for pattern in dangerous_patterns:
        if re.search(pattern, path_str):
            return False

    return True


def sanitize_input(input_str: str) -> str:
    """
    Sanitize user input to remove potentially dangerous characters

    Args:
        input_str: Input string to sanitize

    Returns:
        Sanitized string
    """
    if not input_str:
        return ""

    # Remove null bytes and control characters
    sanitized = re.sub(r'[\x00-\x1f\x7f-\x9f]', '', input_str)

    # Remove SQL injection patterns
    sql_patterns = [
        r'[;\'"\\]',     # SQL metacharacters
        r'--',           # SQL comments
        r'/\*.*?\*/',    # SQL block comments
        r'\b(DROP|DELETE|INSERT|UPDATE|CREATE|ALTER|EXEC|EXECUTE)\b',  # SQL keywords
    ]

    for pattern in sql_patterns:
        sanitized = re.sub(pattern, '', sanitized, flags=re.IGNORECASE)

    return sanitized.strip()


def sanitize_error_message(error_msg: str) -> str:
    """
    Sanitize error messages to remove sensitive information

    Args:
        error_msg: Original error message

    Returns:
        Sanitized error message
    """
    if not error_msg:
        return "Unknown error occurred"

    # Remove file paths
    sanitized = re.sub(r'[A-Za-z]:\\[^\\/:*?"<>|\r\n]+', '[PATH]', error_msg)
    sanitized = re.sub(r'/[^/\s:*?"<>|\r\n]+', '[PATH]', sanitized)

    # Remove usernames
    sanitized = re.sub(r'\\Users\\[^\\]+', '\\Users\\[USER]', sanitized)
    sanitized = re.sub(r'/home/[^/]+', '/home/[USER]', sanitized)

    # Remove IP addresses
    sanitized = re.sub(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b', '[IP]', sanitized)

    return sanitized


def check_vscode_running() -> bool:
    """
    Check if VS Code is currently running

    Returns:
        True if VS Code is running, False otherwise
    """
    try:
        import psutil

        for proc in psutil.process_iter(['pid', 'name']):
            if proc.info['name'] and 'code' in proc.info['name'].lower():
                return True
    except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
        pass
    except ImportError:
        warning("psutil not available, cannot check if VS Code is running")

    return False
