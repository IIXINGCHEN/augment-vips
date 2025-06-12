#!/bin/bash
# platforms/linux.sh
#
# Enterprise-grade Linux implementation for Augment VIP
# Production-ready with comprehensive error handling and security
# Uses core modules for zero-redundancy architecture

set -euo pipefail

# Script metadata
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="augment-vip-linux"

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source core modules
source "${PROJECT_ROOT}/core/common.sh"
source "${PROJECT_ROOT}/core/platform.sh"
source "${PROJECT_ROOT}/core/security.sh"
source "${PROJECT_ROOT}/core/validation.sh"
source "${PROJECT_ROOT}/core/dependencies.sh"
source "${PROJECT_ROOT}/core/paths.sh"
source "${PROJECT_ROOT}/core/database.sh"
source "${PROJECT_ROOT}/core/telemetry.sh"
source "${PROJECT_ROOT}/core/backup.sh"
source "${PROJECT_ROOT}/core/logging.sh"

# Default configuration
DEFAULT_OPERATION="help"
DRY_RUN=false
VERBOSE=false
CONFIG_FILE="config/settings.json"

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --operation|-o)
                OPERATION="$2"
                shift 2
                ;;
            --dry-run|-d)
                DRY_RUN=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                CURRENT_LOG_LEVEL=${LOG_LEVEL_DEBUG}
                shift
                ;;
            --config|-c)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown argument: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Set default operation if not specified
    OPERATION="${OPERATION:-${DEFAULT_OPERATION}}"
}

# Initialize Linux platform
init_linux_platform() {
    log_info "Initializing Linux platform implementation..."
    
    # Initialize core modules
    init_common "logs"
    init_platform
    init_security
    init_validation
    init_dependencies
    init_paths
    init_database
    init_telemetry
    init_backup
    init_logging
    
    # Validate Linux platform
    if [[ "${DETECTED_PLATFORM}" != "linux" ]]; then
        log_error "This script is designed for Linux platforms only"
        return 1
    fi
    
    # Check Linux distribution
    log_info "Linux distribution: ${PLATFORM_VERSION}"
    log_info "Package manager: ${PACKAGE_MANAGER}"
    
    audit_log "LINUX_INIT" "Linux platform initialized successfully"
    log_success "Linux platform implementation initialized"
}

# Validate Linux environment
validate_linux_environment() {
    log_info "Validating Linux environment..."
    
    # Check kernel version
    local kernel_version
    kernel_version=$(uname -r)
    log_debug "Kernel version: ${kernel_version}"
    
    # Check if running as root (warn if true)
    if is_root; then
        log_warn "Running as root is not recommended for security reasons"
    fi
    
    # Check required directories
    local required_dirs=("${HOME}/.config" "${HOME}/.vscode")
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "${dir}" ]]; then
            log_debug "Directory does not exist: ${dir}"
        fi
    done
    
    # Check for VS Code processes
    if is_process_running "code"; then
        log_warn "VS Code is currently running. Please close it before proceeding."
        read -p "Continue anyway? (y/N): " response
        if [[ "${response}" != "y" && "${response}" != "Y" ]]; then
            log_info "Operation cancelled by user"
            return 1
        fi
    fi
    
    audit_log "LINUX_VALIDATE" "Linux environment validated"
    log_success "Linux environment validation completed"
}

# Handle dependency installation
handle_dependencies() {
    log_info "Checking and installing dependencies..."
    
    # Check all dependencies
    check_all_dependencies
    
    if [[ "${DEPENDENCIES_SATISFIED}" != "true" ]]; then
        log_warn "Some required dependencies are missing"
        
        # Ask user for permission to install
        read -p "Install missing dependencies? (y/N): " response
        if [[ "${response}" == "y" || "${response}" == "Y" ]]; then
            if install_missing_dependencies true; then
                log_success "Dependencies installed successfully"
            else
                log_error "Failed to install dependencies"
                return 1
            fi
        else
            log_error "Required dependencies not available"
            return 1
        fi
    fi
    
    # Validate dependency versions
    if ! validate_dependency_versions; then
        log_warn "Some dependency versions may be outdated"
    fi
    
    audit_log "DEPENDENCIES_HANDLE" "Dependencies handled successfully"
    return 0
}

# Discover VS Code installations
discover_vscode() {
    log_info "Discovering VS Code installations on Linux..."
    
    # Initialize path discovery
    if ! init_paths; then
        log_error "Failed to initialize path discovery"
        return 1
    fi
    
    # Check if any VS Code installations were found
    if [[ ${#VSCODE_PATHS[@]} -eq 0 ]]; then
        log_error "No VS Code installations found"
        log_info "Please ensure VS Code is installed and has been run at least once"
        return 1
    fi
    
    # Log discovered installations
    log_info "Found ${#VSCODE_PATHS[@]} VS Code installation(s):"
    for path_type in "${!VSCODE_PATHS[@]}"; do
        log_info "  ${path_type}: ${VSCODE_PATHS["${path_type}"]}"
    done
    
    # Discover data files
    discover_vscode_files
    
    if [[ ${#DISCOVERED_FILES[@]} -eq 0 ]]; then
        log_warn "No VS Code data files found"
        return 1
    fi
    
    log_info "Found ${#DISCOVERED_FILES[@]} VS Code data file(s)"
    
    audit_log "VSCODE_DISCOVER" "VS Code discovery completed: ${#VSCODE_PATHS[@]} installations, ${#DISCOVERED_FILES[@]} files"
    return 0
}

# Execute database cleaning operation
execute_database_cleaning() {
    local dry_run="$1"
    
    log_info "Executing database cleaning operation (dry_run: ${dry_run})..."
    
    # Get database files
    local db_files
    mapfile -t db_files < <(get_database_files)
    
    if [[ ${#db_files[@]} -eq 0 ]]; then
        log_warn "No database files found for cleaning"
        return 0
    fi
    
    log_info "Found ${#db_files[@]} database file(s) to process"
    
    local processed=0
    local errors=0
    
    # Process each database file
    for db_file in "${db_files[@]}"; do
        log_info "Processing database: ${db_file}"
        
        if clean_vscode_database "${db_file}" "${dry_run}"; then
            ((processed++))
            log_success "Database processed successfully: ${db_file}"
        else
            ((errors++))
            log_error "Failed to process database: ${db_file}"
        fi
    done
    
    log_info "Database cleaning completed: ${processed} processed, ${errors} errors"
    audit_log "DATABASE_CLEAN_COMPLETE" "Processed: ${processed}, Errors: ${errors}, DryRun: ${dry_run}"
    
    return 0
}

# Execute telemetry ID modification
execute_telemetry_modification() {
    local dry_run="$1"
    
    log_info "Executing telemetry ID modification (dry_run: ${dry_run})..."
    
    # Get storage files
    local storage_files
    mapfile -t storage_files < <(get_storage_files)
    
    if [[ ${#storage_files[@]} -eq 0 ]]; then
        log_warn "No storage files found for modification"
        return 0
    fi
    
    log_info "Found ${#storage_files[@]} storage file(s) to process"
    
    local modified=0
    local errors=0
    
    # Process each storage file
    for storage_file in "${storage_files[@]}"; do
        log_info "Processing storage file: ${storage_file}"
        
        if modify_telemetry_ids "${storage_file}" "${dry_run}"; then
            ((modified++))
            log_success "Storage file processed successfully: ${storage_file}"
        else
            ((errors++))
            log_error "Failed to process storage file: ${storage_file}"
        fi
    done
    
    log_info "Telemetry modification completed: ${modified} modified, ${errors} errors"
    audit_log "TELEMETRY_MODIFY_COMPLETE" "Modified: ${modified}, Errors: ${errors}, DryRun: ${dry_run}"
    
    return 0
}

# Generate operation report
generate_operation_report() {
    local operation="$1"
    local report_file="logs/linux_operation_report.txt"
    
    log_info "Generating operation report: ${report_file}"
    
    {
        echo "=== Linux Platform Operation Report ==="
        echo "Generated: $(date)"
        echo "Operation: ${operation}"
        echo "Platform: ${DETECTED_PLATFORM} ${PLATFORM_VERSION}"
        echo "Package Manager: ${PACKAGE_MANAGER}"
        echo ""
        
        echo "VS Code Installations:"
        for path_type in "${!VSCODE_PATHS[@]}"; do
            echo "  ${path_type}: ${VSCODE_PATHS["${path_type}"]}"
        done
        echo ""
        
        echo "Data Files Discovered:"
        for file_key in "${!DISCOVERED_FILES[@]}"; do
            echo "  ${file_key}: ${DISCOVERED_FILES["${file_key}"]}"
        done
        echo ""
        
        echo "Operation Statistics:"
        echo "  Database operations: ${DB_STATS["databases_processed"]:-0}"
        echo "  Telemetry operations: ${TELEMETRY_STATS["files_processed"]:-0}"
        echo "  Backups created: ${BACKUP_STATS["backups_created"]:-0}"
        echo "  Total errors: $((${DB_STATS["errors_encountered"]:-0} + ${TELEMETRY_STATS["errors_encountered"]:-0}))"
        
    } > "${report_file}"
    
    log_success "Operation report generated: ${report_file}"
}

# Main execution function
main() {
    local operation="$1"
    local dry_run="$2"
    
    log_info "Starting Augment VIP Linux operation: ${operation}"
    
    # Initialize platform
    if ! init_linux_platform; then
        log_error "Platform initialization failed"
        return 1
    fi
    
    # Validate environment
    if ! validate_linux_environment; then
        log_error "Environment validation failed"
        return 1
    fi
    
    # Handle dependencies
    if ! handle_dependencies; then
        log_error "Dependency handling failed"
        return 1
    fi
    
    # Discover VS Code
    if ! discover_vscode; then
        log_error "VS Code discovery failed"
        return 1
    fi
    
    # Execute operation
    case "${operation}" in
        "clean")
            execute_database_cleaning "${dry_run}"
            ;;
        "modify-ids")
            execute_telemetry_modification "${dry_run}"
            ;;
        "all")
            execute_database_cleaning "${dry_run}"
            execute_telemetry_modification "${dry_run}"
            ;;
        "help")
            show_help
            return 0
            ;;
        *)
            log_error "Unknown operation: ${operation}"
            show_help
            return 1
            ;;
    esac
    
    # Generate reports
    generate_operation_report "${operation}"
    generate_dependency_report
    generate_database_report
    generate_telemetry_report
    generate_backup_report
    generate_path_report
    
    log_success "Augment VIP Linux operation completed successfully"
    audit_log "OPERATION_COMPLETE" "Operation: ${operation}, DryRun: ${dry_run}"
    
    return 0
}

# Show help information
show_help() {
    cat << EOF
Augment VIP - Linux Platform Implementation v${SCRIPT_VERSION}

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -o, --operation OPERATION   Specify operation to perform
    -d, --dry-run              Perform a dry run without making changes
    -v, --verbose              Enable verbose output
    -c, --config FILE          Specify configuration file
    -h, --help                 Show this help message

OPERATIONS:
    clean                      Clean VS Code databases (remove Augment entries)
    modify-ids                 Modify VS Code telemetry IDs
    all                        Perform both cleaning and ID modification
    help                       Show this help message

EXAMPLES:
    $0 --operation clean
    $0 --operation modify-ids --dry-run
    $0 --operation all --verbose

REQUIREMENTS:
    - Linux distribution with package manager (apt, dnf, yum)
    - Bash 4.0 or higher
    - sqlite3, curl, jq (auto-installable)

SUPPORTED DISTRIBUTIONS:
    - Ubuntu/Debian (apt)
    - Fedora/RHEL/CentOS (dnf/yum)
    - Other distributions with compatible package managers

EOF
}

# Cleanup function
cleanup() {
    log_info "Performing cleanup..."
    
    # Clean up temporary files
    if [[ -n "${TEMP_FILES:-}" ]]; then
        for temp_file in ${TEMP_FILES}; do
            if [[ -f "${temp_file}" ]]; then
                rm -f "${temp_file}"
                log_debug "Removed temporary file: ${temp_file}"
            fi
        done
    fi
    
    # Clean up old backups if configured
    if [[ "${BACKUP_CLEANUP:-true}" == "true" ]]; then
        cleanup_old_backups
    fi
    
    log_debug "Cleanup completed"
}

# Set up signal handlers
trap cleanup EXIT
trap 'log_error "Script interrupted"; exit 130' INT TERM

# Main script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Parse command line arguments
    parse_arguments "$@"
    
    # Execute main function
    if main "${OPERATION}" "${DRY_RUN}"; then
        exit 0
    else
        exit 1
    fi
fi
