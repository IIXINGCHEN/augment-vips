"""
VS Code database cleaner module
Cross-platform support for Windows, macOS, and Linux
"""

import os
import sys
import sqlite3
import shutil
from pathlib import Path
from typing import List, Dict, Any, Optional

# Security exception class
class SecurityError(Exception):
    """Raised when a security violation is detected"""
    pass

# SECURITY FIX: Add common directory to path with validation
common_path = os.path.join(os.path.dirname(__file__), '..', '..', 'common')
# Validate the path doesn't escape the project directory
common_path = os.path.abspath(common_path)
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
if not common_path.startswith(project_root):
    raise SecurityError(f"SECURITY: Path traversal detected - common path outside project: {common_path}")
sys.path.append(common_path)

from .utils import (
    info, success, error, warning,
    get_all_vscode_databases, backup_file,
    check_vscode_running, validate_file_path, sanitize_error_message
)

try:
    from config_loader import get_cleaning_patterns
    from transaction_manager import (
        begin_transaction, add_file_operation, commit_transaction,
        rollback_transaction, with_transaction
    )
    TRANSACTION_SUPPORT = True
except ImportError:
    # Fallback if config loader or transaction manager is not available
    def get_cleaning_patterns(pattern_type: str) -> List[str]:
        """Fallback pattern provider"""
        patterns = {
            "augment": ['%augment%', '%Augment%', '%AUGMENT%', '%context7%', '%Context7%', '%CONTEXT7%'],
            "telemetry": ['%telemetry%', '%machineId%', '%deviceId%', '%sqmId%'],
            "extensions": ['%augment.%', '%context7.%'],
            "custom": []
        }
        return patterns.get(pattern_type, [])

    # Dummy transaction functions
    def begin_transaction(): return "dummy"
    def add_file_operation(*args, **kwargs): pass
    def commit_transaction(): return True
    def rollback_transaction(): return True
    def with_transaction(func): return func
    TRANSACTION_SUPPORT = False


@with_transaction
def clean_database_file(db_path: Path, create_backup: bool = True) -> bool:
    """
    Clean a single VS Code database file
    
    Args:
        db_path: Path to the database file
        create_backup: Whether to create a backup before cleaning
        
    Returns:
        True if successful, False otherwise
    """
    if not db_path.exists():
        warning(f"Database file not found: {db_path}")
        return False
    
    info(f"Cleaning database: {db_path}")
    
    # Create backup if requested
    backup_path = None
    if create_backup:
        try:
            backup_path = backup_file(db_path)
            # Add to transaction for rollback capability
            if TRANSACTION_SUPPORT:
                add_file_operation("db_modify", str(db_path), str(backup_path))
        except Exception as e:
            error(f"Failed to create backup: {sanitize_error_message(str(e))}")
            return False
    
    # Connect to the database and clean it
    try:
        conn = sqlite3.connect(str(db_path))
        cursor = conn.cursor()
        
        # Get the count of records before deletion using parameterized query
        cursor.execute("SELECT COUNT(*) FROM ItemTable WHERE key LIKE ?", ('%augment%',))
        count_before = cursor.fetchone()[0]
        
        if count_before == 0:
            info("No Augment-related entries found in this database")
            conn.close()
            return True
        
        # Delete records using configuration-driven patterns
        patterns = get_cleaning_patterns("augment")
        total_deleted = 0
        
        for pattern in patterns:
            cursor.execute("DELETE FROM ItemTable WHERE key LIKE ?", (pattern,))
            deleted = cursor.rowcount
            total_deleted += deleted
            if deleted > 0:
                info(f"Deleted {deleted} entries matching pattern: {pattern}")
        
        conn.commit()
        conn.close()
        
        if total_deleted > 0:
            success(f"Removed {total_deleted} Augment-related entries from {db_path.name}")
        else:
            info(f"No entries to remove from {db_path.name}")
        
        return True
        
    except sqlite3.Error as e:
        error(f"SQLite error while cleaning {db_path}: {e}")
        
        # Restore from backup if there was an error
        if backup_path and backup_path.exists():
            info("Restoring from backup...")
            try:
                shutil.copy2(backup_path, db_path)
                success("Restored from backup")
            except Exception as restore_error:
                error(f"Failed to restore from backup: {restore_error}")
        
        return False
        
    except Exception as e:
        error(f"Unexpected error while cleaning {db_path}: {e}")
        return False


def clean_vscode_db(create_backup: bool = True) -> bool:
    """
    Clean all VS Code databases by removing entries containing "augment"
    
    Args:
        create_backup: Whether to create backups before cleaning
        
    Returns:
        True if successful, False otherwise
    """
    info("Starting VS Code database cleanup process")
    
    # Check if VS Code is running
    if check_vscode_running():
        warning("VS Code appears to be running. Please close VS Code before running the cleanup.")
        response = input("Continue anyway? (y/N): ").strip().lower()
        if response not in ['y', 'yes']:
            info("Cleanup cancelled by user")
            return False
    
    # Get all database files
    database_files = get_all_vscode_databases()
    
    if not database_files:
        warning("No VS Code database files found")
        info("This might be normal if:")
        info("  - VS Code has never been run on this system")
        info("  - VS Code is installed in a non-standard location")
        info("  - You're using a portable version of VS Code")
        return False
    
    info(f"Found {len(database_files)} database file(s) to clean")
    
    # Clean each database file
    success_count = 0
    failure_count = 0
    
    for db_path in database_files:
        if clean_database_file(db_path, create_backup):
            success_count += 1
        else:
            failure_count += 1
    
    # Report results
    info("Database cleanup completed")
    success(f"Successfully cleaned: {success_count}/{len(database_files)} databases")
    
    if failure_count > 0:
        warning(f"Failed to clean: {failure_count} databases")
        return False
    
    if success_count > 0:
        info("You may need to restart VS Code for changes to take effect")
    
    return True


def preview_cleanup() -> bool:
    """
    Preview what would be cleaned without making changes
    
    Returns:
        True if preview completed successfully
    """
    info("Previewing VS Code database cleanup (no changes will be made)")
    
    # Get all database files
    database_files = get_all_vscode_databases()
    
    if not database_files:
        warning("No VS Code database files found")
        return False
    
    info(f"Found {len(database_files)} database file(s)")
    
    total_entries = 0
    
    for db_path in database_files:
        if not db_path.exists():
            continue
            
        try:
            conn = sqlite3.connect(str(db_path))
            cursor = conn.cursor()
            
            # Count entries that would be deleted using configuration-driven patterns
            patterns = get_cleaning_patterns("augment")
            entries_count = 0
            
            for pattern in patterns:
                cursor.execute("SELECT COUNT(*) FROM ItemTable WHERE key LIKE ?", (pattern,))
                count = cursor.fetchone()[0]
                entries_count += count
            
            conn.close()
            
            if entries_count > 0:
                info(f"  {db_path.name}: {entries_count} entries would be removed")
                total_entries += entries_count
            else:
                info(f"  {db_path.name}: No entries to remove")
                
        except sqlite3.Error as e:
            warning(f"Could not read {db_path}: {e}")
        except Exception as e:
            warning(f"Unexpected error reading {db_path}: {e}")
    
    info(f"Total entries that would be removed: {total_entries}")
    return True
