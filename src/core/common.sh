#!/bin/bash
# core/common.sh
#
# Enterprise-grade common functions library
# Zero-redundancy design with shared core logic
# Production-ready with comprehensive error handling

# Prevent multiple loading
if [[ "${COMMON_SH_LOADED:-}" == "true" ]]; then
    return 0
fi
readonly COMMON_SH_LOADED="true"

set -euo pipefail

# Global constants (only define if not already defined)
if [[ -z "${SCRIPT_VERSION:-}" ]]; then
    readonly SCRIPT_VERSION="1.0.0"
fi
if [[ -z "${SCRIPT_NAME:-}" ]]; then
    readonly SCRIPT_NAME="augment-vip"
fi
if [[ -z "${LOG_LEVEL_ERROR:-}" ]]; then
    readonly LOG_LEVEL_ERROR=1
fi
if [[ -z "${LOG_LEVEL_WARN:-}" ]]; then
    readonly LOG_LEVEL_WARN=2
fi
if [[ -z "${LOG_LEVEL_INFO:-}" ]]; then
    readonly LOG_LEVEL_INFO=3
fi
if [[ -z "${LOG_LEVEL_DEBUG:-}" ]]; then
    readonly LOG_LEVEL_DEBUG=4
fi

# Global variables
CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO}
LOG_FILE=""
AUDIT_LOG_FILE=""

# Color codes for output formatting (only define if not already defined)
if [[ -z "${COLOR_RED:-}" ]]; then
    readonly COLOR_RED='\033[0;31m'
fi
if [[ -z "${COLOR_GREEN:-}" ]]; then
    readonly COLOR_GREEN='\033[0;32m'
fi
if [[ -z "${COLOR_YELLOW:-}" ]]; then
    readonly COLOR_YELLOW='\033[1;33m'
fi
if [[ -z "${COLOR_BLUE:-}" ]]; then
    readonly COLOR_BLUE='\033[0;34m'
fi
if [[ -z "${COLOR_CYAN:-}" ]]; then
    readonly COLOR_CYAN='\033[0;36m'
fi
if [[ -z "${COLOR_RESET:-}" ]]; then
    readonly COLOR_RESET='\033[0m'
fi

# Initialize common environment
init_common() {
    local log_dir="${1:-logs}"
    
    # Create log directory if it doesn't exist
    mkdir -p "${log_dir}"
    
    # Set log files with timestamp
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    LOG_FILE="${log_dir}/${SCRIPT_NAME}_${timestamp}.log"
    AUDIT_LOG_FILE="${log_dir}/${SCRIPT_NAME}_audit_${timestamp}.log"
    
    # Initialize log files
    echo "=== ${SCRIPT_NAME} v${SCRIPT_VERSION} Started at $(date) ===" >> "${LOG_FILE}"
    echo "=== Audit Log Started at $(date) ===" >> "${AUDIT_LOG_FILE}"
    
    log_info "Common library initialized"
}

# Logging functions with enterprise-grade features
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local caller="${BASH_SOURCE[2]##*/}:${BASH_LINENO[1]}"
    
    # Format log entry
    local log_entry="[${timestamp}] [${level}] [${caller}] ${message}"
    
    # Write to log file if available
    if [[ -n "${LOG_FILE}" ]]; then
        echo "${log_entry}" >> "${LOG_FILE}"
    fi
    
    # Output to console based on log level
    case "${level}" in
        "ERROR")
            echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} ${message}" >&2
            ;;
        "WARN")
            echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} ${message}" >&2
            ;;
        "INFO")
            echo -e "${COLOR_CYAN}[INFO]${COLOR_RESET} ${message}"
            ;;
        "DEBUG")
            if [[ ${CURRENT_LOG_LEVEL} -ge ${LOG_LEVEL_DEBUG} ]]; then
                echo -e "${COLOR_BLUE}[DEBUG]${COLOR_RESET} ${message}"
            fi
            ;;
        "SUCCESS")
            echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} ${message}"
            ;;
    esac
}

log_error() { log_message "ERROR" "$1"; }
log_warn() { log_message "WARN" "$1"; }
log_info() { log_message "INFO" "$1"; }
log_debug() { log_message "DEBUG" "$1"; }
log_success() { log_message "SUCCESS" "$1"; }

# Audit logging for security compliance
audit_log() {
    local action="$1"
    local details="$2"
    local user="${USER:-unknown}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local pid=$$
    
    local audit_entry="[${timestamp}] [PID:${pid}] [USER:${user}] [ACTION:${action}] ${details}"
    
    if [[ -n "${AUDIT_LOG_FILE}" ]]; then
        echo "${audit_entry}" >> "${AUDIT_LOG_FILE}"
    fi
    
    log_debug "Audit: ${action} - ${details}"
}

# Error handling with cleanup
handle_error() {
    local exit_code=$?
    local line_number=$1
    local command="$2"
    
    log_error "Command failed with exit code ${exit_code} at line ${line_number}: ${command}"
    audit_log "ERROR" "Script failed at line ${line_number} with exit code ${exit_code}"
    
    # Perform cleanup if cleanup function exists
    if declare -f cleanup > /dev/null; then
        log_info "Performing cleanup..."
        cleanup
    fi
    
    exit ${exit_code}
}

# Set up error trap
trap 'handle_error ${LINENO} "$BASH_COMMAND"' ERR

# Utility functions
is_command_available() {
    command -v "$1" >/dev/null 2>&1
}

is_root() {
    [[ $EUID -eq 0 ]]
}

get_timestamp() {
    date '+%Y%m%d_%H%M%S'
}

# File operations with safety checks
safe_copy() {
    local src="$1"
    local dest="$2"
    
    if [[ ! -f "${src}" ]]; then
        log_error "Source file does not exist: ${src}"
        return 1
    fi
    
    if [[ -f "${dest}" ]]; then
        log_warn "Destination file exists, creating backup: ${dest}.backup"
        cp "${dest}" "${dest}.backup"
    fi
    
    cp "${src}" "${dest}"
    audit_log "FILE_COPY" "Copied ${src} to ${dest}"
    log_success "File copied successfully: ${src} -> ${dest}"
}

safe_remove() {
    local file="$1"
    
    if [[ ! -f "${file}" ]]; then
        log_warn "File does not exist: ${file}"
        return 0
    fi
    
    rm -f "${file}"
    audit_log "FILE_REMOVE" "Removed file: ${file}"
    log_success "File removed successfully: ${file}"
}

# Process management
is_process_running() {
    local process_name="$1"
    pgrep -f "${process_name}" >/dev/null 2>&1
}

wait_for_process_stop() {
    local process_name="$1"
    local timeout="${2:-30}"
    local count=0
    
    while is_process_running "${process_name}" && [[ ${count} -lt ${timeout} ]]; do
        sleep 1
        ((count++))
    done
    
    if is_process_running "${process_name}"; then
        log_error "Process ${process_name} did not stop within ${timeout} seconds"
        return 1
    fi
    
    log_success "Process ${process_name} stopped successfully"
    return 0
}

# Configuration management
load_config() {
    local config_file="$1"
    
    if [[ ! -f "${config_file}" ]]; then
        log_error "Configuration file not found: ${config_file}"
        return 1
    fi
    
    # Source configuration file safely
    set +u  # Temporarily allow undefined variables
    source "${config_file}"
    set -u
    
    audit_log "CONFIG_LOAD" "Loaded configuration from: ${config_file}"
    log_success "Configuration loaded: ${config_file}"
}

# Cleanup function (can be overridden by calling scripts)
cleanup() {
    log_info "Performing default cleanup..."
    # Default cleanup actions can be added here
}

# Export functions for use in other scripts
export -f log_error log_warn log_info log_debug log_success
export -f audit_log handle_error is_command_available is_root
export -f safe_copy safe_remove is_process_running wait_for_process_stop
export -f load_config get_timestamp

log_debug "Common library functions exported"
