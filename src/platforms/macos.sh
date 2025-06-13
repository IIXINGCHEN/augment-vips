#!/bin/bash
# platforms/macos.sh
#
# Enterprise-grade macOS implementation for Augment VIP
# Production-ready with comprehensive error handling and security
# Uses core modules for zero-redundancy architecture

set -euo pipefail

# Script metadata
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="augment-vip-macos"

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

# Initialize macOS platform
init_macos_platform() {
    log_info "Initializing macOS platform implementation..."
    
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
    
    # Validate macOS platform
    if [[ "${DETECTED_PLATFORM}" != "macos" ]]; then
        log_error "This script is designed for macOS platforms only"
        return 1
    fi
    
    # Check macOS version
    log_info "macOS version: ${PLATFORM_VERSION}"
    log_info "Package manager: ${PACKAGE_MANAGER}"
    
    # Check for Xcode Command Line Tools
    if ! xcode-select -p >/dev/null 2>&1; then
        log_warn "Xcode Command Line Tools not found"
        log_info "Some operations may require Command Line Tools"
    fi
    
    audit_log "MACOS_INIT" "macOS platform initialized successfully"
    log_success "macOS platform implementation initialized"
}

# Validate macOS environment
validate_macos_environment() {
    log_info "Validating macOS environment..."
    
    # Check macOS version compatibility
    local macos_version
    macos_version=$(sw_vers -productVersion)
    local major_version
    major_version=$(echo "${macos_version}" | cut -d. -f1)
    
    if [[ ${major_version} -lt 10 ]]; then
        log_error "macOS 10.12 or higher is required. Current version: ${macos_version}"
        return 1
    fi
    
    # Check System Integrity Protection (SIP) status
    if is_command_available csrutil; then
        local sip_status
        sip_status=$(csrutil status 2>/dev/null || echo "unknown")
        log_debug "System Integrity Protection: ${sip_status}"
    fi
    
    # Check if running as root (warn if true)
    if is_root; then
        log_warn "Running as root is not recommended for security reasons"
    fi
    
    # Check required directories
    local required_dirs=("${HOME}/Library" "${HOME}/.vscode")
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "${dir}" ]]; then
            log_debug "Directory does not exist: ${dir}"
        fi
    done
    
    # Check for VS Code processes
    if is_process_running "Visual Studio Code"; then
        log_warn "VS Code is currently running. Please close it before proceeding."
        read -p "Continue anyway? (y/N): " response
        if [[ "${response}" != "y" && "${response}" != "Y" ]]; then
            log_info "Operation cancelled by user"
            return 1
        fi
    fi
    
    # Check for Homebrew if needed
    if [[ "${PACKAGE_MANAGER}" == "unknown" ]]; then
        log_warn "No package manager detected. Homebrew installation may be required."
        log_info "Visit https://brew.sh for Homebrew installation instructions"
    fi
    
    audit_log "MACOS_VALIDATE" "macOS environment validated"
    log_success "macOS environment validation completed"
}

# Handle dependency installation with Homebrew
handle_dependencies() {
    log_info "Checking and installing dependencies..."
    
    # Check all dependencies
    check_all_dependencies
    
    if [[ "${DEPENDENCIES_SATISFIED}" != "true" ]]; then
        log_warn "Some required dependencies are missing"
        
        # Check if Homebrew is available
        if [[ "${PACKAGE_MANAGER}" == "unknown" ]]; then
            log_error "No package manager available for dependency installation"
            log_info "Please install Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            return 1
        fi
        
        # Ask user for permission to install
        read -p "Install missing dependencies using ${PACKAGE_MANAGER}? (y/N): " response
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

# Discover VS Code installations on macOS
discover_vscode() {
    log_info "Discovering VS Code installations on macOS..."
    
    # Initialize path discovery
    if ! init_paths; then
        log_error "Failed to initialize path discovery"
        return 1
    fi
    
    # Check if any VS Code installations were found
    if [[ ${#VSCODE_PATHS[@]} -eq 0 ]]; then
        log_error "No VS Code installations found"
        log_info "Please ensure VS Code is installed in /Applications or ~/Applications"
        log_info "Download from: https://code.visualstudio.com/"
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
        log_info "Please run VS Code at least once to create data files"
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
    local report_file="logs/macos_operation_report.txt"
    
    log_info "Generating operation report: ${report_file}"
    
    {
        echo "=== macOS Platform Operation Report ==="
        echo "Generated: $(date)"
        echo "Operation: ${operation}"
        echo "Platform: ${DETECTED_PLATFORM} ${PLATFORM_VERSION}"
        echo "Package Manager: ${PACKAGE_MANAGER}"
        echo "Architecture: ${ARCHITECTURE}"
        echo ""
        
        echo "System Information:"
        echo "  Hardware: $(system_profiler SPHardwareDataType | grep 'Model Name' | cut -d: -f2 | xargs || echo 'Unknown')"
        echo "  Processor: $(system_profiler SPHardwareDataType | grep 'Processor Name' | cut -d: -f2 | xargs || echo 'Unknown')"
        echo "  Memory: $(system_profiler SPHardwareDataType | grep 'Memory' | cut -d: -f2 | xargs || echo 'Unknown')"
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
    
    log_info "Starting Augment VIP macOS operation: ${operation}"
    
    # Initialize platform
    if ! init_macos_platform; then
        log_error "Platform initialization failed"
        return 1
    fi
    
    # Validate environment
    if ! validate_macos_environment; then
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
    
    log_success "Augment VIP macOS operation completed successfully"
    audit_log "OPERATION_COMPLETE" "Operation: ${operation}, DryRun: ${dry_run}"
    
    return 0
}

# Show help information
show_help() {
    cat << EOF
Augment VIP - macOS Platform Implementation v${SCRIPT_VERSION}

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
    - macOS 10.12 or higher
    - Bash 4.0 or higher (install via Homebrew if needed)
    - Homebrew package manager
    - sqlite3, curl, jq (auto-installable via Homebrew)

INSTALLATION:
    1. Install Homebrew: /bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    2. Install dependencies: brew install sqlite3 curl jq
    3. Run this script

NOTES:
    - VS Code must be closed before running operations
    - Backups are automatically created before modifications
    - All operations are logged for audit purposes

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
