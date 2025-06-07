"""
VS Code telemetry ID modifier module
Cross-platform support for Windows, macOS, and Linux
"""

import os
import sys
import json
from pathlib import Path
from typing import Dict, Any, Optional

from .utils import (
    info, success, error, warning, 
    get_vscode_paths, backup_file, 
    generate_machine_id, generate_device_id, generate_sqm_id,
    check_vscode_running
)


def modify_telemetry_ids(create_backup: bool = True) -> bool:
    """
    Modify telemetry IDs in VS Code storage.json file
    
    Args:
        create_backup: Whether to create a backup before modification
        
    Returns:
        True if successful, False otherwise
    """
    info("Starting VS Code telemetry ID modification")
    
    # Check if VS Code is running
    if check_vscode_running():
        warning("VS Code appears to be running. Please close VS Code before modifying telemetry IDs.")
        response = input("Continue anyway? (y/N): ").strip().lower()
        if response not in ['y', 'yes']:
            info("Modification cancelled by user")
            return False
    
    # Get VS Code paths
    paths = get_vscode_paths()
    storage_json = paths["storage_json"]
    
    if not storage_json.exists():
        warning(f"VS Code storage.json not found at: {storage_json}")
        info("This might be normal if:")
        info("  - VS Code has never been run on this system")
        info("  - VS Code is installed in a non-standard location")
        info("  - You're using a portable version of VS Code")
        return False
    
    info(f"Found storage.json at: {storage_json}")
    
    # Create backup if requested
    if create_backup:
        try:
            backup_file(storage_json)
        except Exception as e:
            error(f"Failed to create backup: {e}")
            return False
    
    # Generate new IDs
    info("Generating new telemetry IDs...")
    machine_id = generate_machine_id()
    device_id = generate_device_id()
    sqm_id = generate_sqm_id()
    
    # Read the current file
    try:
        with open(storage_json, 'r', encoding='utf-8') as f:
            content = json.load(f)
        
        # Update the values
        content["telemetry.machineId"] = machine_id
        content["telemetry.devDeviceId"] = device_id
        content["telemetry.sqmId"] = sqm_id
        
        # Also update other telemetry-related fields if they exist
        if "telemetry.sessionId" in content:
            content["telemetry.sessionId"] = generate_device_id()
        
        if "telemetry.instanceId" in content:
            content["telemetry.instanceId"] = generate_device_id()
        
        # Write the updated content back to the file
        with open(storage_json, 'w', encoding='utf-8') as f:
            json.dump(content, f, indent=2)
        
        success("Successfully updated telemetry IDs")
        info(f"New telemetry.machineId: {machine_id}")
        info(f"New telemetry.devDeviceId: {device_id}")
        info(f"New telemetry.sqmId: {sqm_id}")
        info("You may need to restart VS Code for changes to take effect")
        
        return True
        
    except json.JSONDecodeError as e:
        error(f"The storage file is not valid JSON: {e}")
        return False
        
    except FileNotFoundError:
        error(f"Storage file not found: {storage_json}")
        return False
        
    except PermissionError:
        error(f"Permission denied accessing: {storage_json}")
        return False
        
    except Exception as e:
        error(f"Unexpected error: {e}")
        return False


def preview_telemetry_modification() -> bool:
    """
    Preview what telemetry IDs would be modified without making changes
    
    Returns:
        True if preview completed successfully
    """
    info("Previewing VS Code telemetry ID modification (no changes will be made)")
    
    # Get VS Code paths
    paths = get_vscode_paths()
    storage_json = paths["storage_json"]
    
    if not storage_json.exists():
        warning(f"VS Code storage.json not found at: {storage_json}")
        return False
    
    info(f"Found storage.json at: {storage_json}")
    
    # Read the current file
    try:
        with open(storage_json, 'r', encoding='utf-8') as f:
            content = json.load(f)
        
        # Show current values
        telemetry_fields = [
            "telemetry.machineId",
            "telemetry.devDeviceId", 
            "telemetry.sqmId",
            "telemetry.sessionId",
            "telemetry.instanceId"
        ]
        
        info("Current telemetry IDs:")
        found_fields = 0
        for field in telemetry_fields:
            if field in content:
                current_value = content[field]
                info(f"  {field}: {current_value}")
                found_fields += 1
        
        if found_fields == 0:
            warning("No telemetry fields found in storage.json")
            return False
        
        # Show what new values would be
        info("\nNew telemetry IDs that would be generated:")
        info(f"  telemetry.machineId: {generate_machine_id()}")
        info(f"  telemetry.devDeviceId: {generate_device_id()}")
        info(f"  telemetry.sqmId: {generate_sqm_id()}")
        
        return True
        
    except json.JSONDecodeError as e:
        error(f"The storage file is not valid JSON: {e}")
        return False
        
    except Exception as e:
        error(f"Unexpected error: {e}")
        return False


def show_current_telemetry_ids() -> bool:
    """
    Show current telemetry IDs without making any changes
    
    Returns:
        True if successful
    """
    info("Showing current VS Code telemetry IDs")
    
    # Get VS Code paths
    paths = get_vscode_paths()
    storage_json = paths["storage_json"]
    
    if not storage_json.exists():
        warning(f"VS Code storage.json not found at: {storage_json}")
        return False
    
    info(f"Reading from: {storage_json}")
    
    try:
        with open(storage_json, 'r', encoding='utf-8') as f:
            content = json.load(f)
        
        # Show current values
        telemetry_fields = [
            "telemetry.machineId",
            "telemetry.devDeviceId", 
            "telemetry.sqmId",
            "telemetry.sessionId",
            "telemetry.instanceId",
            "telemetry.firstSessionDate",
            "telemetry.lastSessionDate"
        ]
        
        info("Current telemetry configuration:")
        found_fields = 0
        for field in telemetry_fields:
            if field in content:
                current_value = content[field]
                info(f"  {field}: {current_value}")
                found_fields += 1
        
        if found_fields == 0:
            warning("No telemetry fields found in storage.json")
            return False
        
        return True
        
    except json.JSONDecodeError as e:
        error(f"The storage file is not valid JSON: {e}")
        return False
        
    except Exception as e:
        error(f"Unexpected error: {e}")
        return False
