"""
Command-line interface for Augment VIP
Cross-platform support for Windows, macOS, and Linux
"""

import sys
import argparse
from typing import List, Optional

from . import __version__, __description__
from .utils import info, success, error, warning, get_system_info
from .db_cleaner import clean_vscode_db, preview_cleanup
from .id_modifier import modify_telemetry_ids, preview_telemetry_modification, show_current_telemetry_ids


def show_system_info():
    """Display system information"""
    info("System Information:")
    sys_info = get_system_info()
    for key, value in sys_info.items():
        info(f"  {key}: {value}")


def main():
    """Main CLI entry point"""
    parser = argparse.ArgumentParser(
        description=__description__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s clean                    # Clean VS Code databases
  %(prog)s modify-ids               # Modify telemetry IDs
  %(prog)s all                      # Run all operations
  %(prog)s preview                  # Preview operations without changes
  %(prog)s --version                # Show version information
        """
    )
    
    parser.add_argument(
        '--version', 
        action='version', 
        version=f'Augment VIP Cleaner {__version__}'
    )
    
    parser.add_argument(
        '--no-backup',
        action='store_true',
        help='Skip creating backups (not recommended)'
    )
    
    parser.add_argument(
        '--system-info',
        action='store_true',
        help='Show system information'
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # Clean command
    clean_parser = subparsers.add_parser(
        'clean', 
        help='Clean VS Code databases by removing Augment-related entries'
    )
    clean_parser.add_argument(
        '--preview',
        action='store_true',
        help='Preview what would be cleaned without making changes'
    )
    
    # Modify IDs command
    modify_parser = subparsers.add_parser(
        'modify-ids',
        help='Modify VS Code telemetry IDs'
    )
    modify_parser.add_argument(
        '--preview',
        action='store_true',
        help='Preview what would be modified without making changes'
    )
    modify_parser.add_argument(
        '--show-current',
        action='store_true',
        help='Show current telemetry IDs without making changes'
    )
    
    # All command
    all_parser = subparsers.add_parser(
        'all',
        help='Run all operations (clean databases and modify telemetry IDs)'
    )
    all_parser.add_argument(
        '--preview',
        action='store_true',
        help='Preview all operations without making changes'
    )
    
    # Preview command
    preview_parser = subparsers.add_parser(
        'preview',
        help='Preview all operations without making changes'
    )
    
    args = parser.parse_args()
    
    # Show system info if requested
    if args.system_info:
        show_system_info()
        return 0
    
    # If no command specified, show help
    if not args.command:
        parser.print_help()
        return 1
    
    create_backup = not args.no_backup
    
    try:
        if args.command == 'clean':
            if hasattr(args, 'preview') and args.preview:
                success_result = preview_cleanup()
            else:
                success_result = clean_vscode_db(create_backup)
                
        elif args.command == 'modify-ids':
            if hasattr(args, 'show_current') and args.show_current:
                success_result = show_current_telemetry_ids()
            elif hasattr(args, 'preview') and args.preview:
                success_result = preview_telemetry_modification()
            else:
                success_result = modify_telemetry_ids(create_backup)
                
        elif args.command == 'all':
            if hasattr(args, 'preview') and args.preview:
                info("=== Database Cleanup Preview ===")
                clean_success = preview_cleanup()
                info("\n=== Telemetry ID Modification Preview ===")
                modify_success = preview_telemetry_modification()
                success_result = clean_success and modify_success
            else:
                info("=== Starting Database Cleanup ===")
                clean_success = clean_vscode_db(create_backup)
                info("\n=== Starting Telemetry ID Modification ===")
                modify_success = modify_telemetry_ids(create_backup)
                success_result = clean_success and modify_success
                
        elif args.command == 'preview':
            info("=== Database Cleanup Preview ===")
            clean_success = preview_cleanup()
            info("\n=== Telemetry ID Modification Preview ===")
            modify_success = preview_telemetry_modification()
            success_result = clean_success and modify_success
            
        else:
            error(f"Unknown command: {args.command}")
            return 1
        
        if success_result:
            success("Operation completed successfully!")
            return 0
        else:
            error("Operation completed with errors")
            return 1
            
    except KeyboardInterrupt:
        warning("\nOperation cancelled by user")
        return 130
        
    except Exception as e:
        error(f"Unexpected error: {e}")
        return 1


if __name__ == '__main__':
    sys.exit(main())
