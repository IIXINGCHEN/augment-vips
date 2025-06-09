"""
Augment VIP Cleaner - Cross-platform VS Code cleanup utility

A professional toolkit for Augment VIP users, providing tools to manage and clean VS Code databases.
Cross-platform compatibility for Windows, macOS, and Linux.

Based on: https://github.com/azrilaiman2003/augment-vip
Enhanced for enterprise use with PowerShell integration on Windows.
"""

__version__ = "1.0.0"
__author__ = "Augment VIP Cleaner Project"
__description__ = "Professional cross-platform VS Code data cleanup and privacy protection tool"

# Import main functions for easy access
from .db_cleaner import clean_vscode_db
from .id_modifier import modify_telemetry_ids
from .utils import info, success, warning, error

__all__ = [
    'clean_vscode_db',
    'modify_telemetry_ids',
    'info',
    'success', 
    'warning',
    'error'
]
