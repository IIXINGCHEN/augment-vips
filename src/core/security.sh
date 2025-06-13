#!/bin/bash
# core/security.sh
#
# Enterprise-grade security validation and audit module
# Production-ready with comprehensive security controls
# Zero-trust security model implementation

# Prevent multiple loading
if [[ "${SECURITY_SH_LOADED:-}" == "true" ]]; then
    return 0
fi
readonly SECURITY_SH_LOADED="true"

set -euo pipefail

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Security constants (only define if not already defined)
if [[ -z "${SECURITY_LEVEL_LOW:-}" ]]; then
    readonly SECURITY_LEVEL_LOW=1
fi
if [[ -z "${SECURITY_LEVEL_MEDIUM:-}" ]]; then
    readonly SECURITY_LEVEL_MEDIUM=2
fi
if [[ -z "${SECURITY_LEVEL_HIGH:-}" ]]; then
    readonly SECURITY_LEVEL_HIGH=3
fi
if [[ -z "${SECURITY_LEVEL_CRITICAL:-}" ]]; then
    readonly SECURITY_LEVEL_CRITICAL=4
fi

if [[ -z "${MAX_PATH_LENGTH:-}" ]]; then
    readonly MAX_PATH_LENGTH=4096
fi
if [[ -z "${MAX_FILENAME_LENGTH:-}" ]]; then
    readonly MAX_FILENAME_LENGTH=255
fi
if [[ -z "${ALLOWED_FILE_EXTENSIONS:-}" ]]; then
    readonly ALLOWED_FILE_EXTENSIONS=("vscdb" "json" "backup")
fi

# Global security variables
CURRENT_SECURITY_LEVEL=${SECURITY_LEVEL_HIGH}
SECURITY_POLICY_FILE=""
ALLOWED_OPERATIONS=()
RESTRICTED_PATHS=()

# Initialize security module
init_security() {
    local policy_file="${1:-config/security.json}"
    
    log_info "Initializing security module..."
    
    # Set security policy file
    SECURITY_POLICY_FILE="${policy_file}"
    
    # Load security policy if available
    if [[ -f "${SECURITY_POLICY_FILE}" ]]; then
        load_security_policy
    else
        log_warn "Security policy file not found, using defaults: ${SECURITY_POLICY_FILE}"
        set_default_security_policy
    fi
    
    # Initialize audit logging
    audit_log "SECURITY_INIT" "Security module initialized with level ${CURRENT_SECURITY_LEVEL}"
    
    log_success "Security module initialized"
}

# Load security policy from configuration
load_security_policy() {
    log_info "Loading security policy from: ${SECURITY_POLICY_FILE}"
    
    if ! is_command_available jq; then
        log_error "jq command not available for security policy parsing"
        return 1
    fi
    
    # Validate JSON format
    if ! jq empty "${SECURITY_POLICY_FILE}" 2>/dev/null; then
        log_error "Invalid JSON format in security policy file"
        return 1
    fi
    
    # Load security level
    local security_level
    security_level=$(jq -r '.security_level // "high"' "${SECURITY_POLICY_FILE}")
    
    case "${security_level}" in
        "low") CURRENT_SECURITY_LEVEL=${SECURITY_LEVEL_LOW} ;;
        "medium") CURRENT_SECURITY_LEVEL=${SECURITY_LEVEL_MEDIUM} ;;
        "high") CURRENT_SECURITY_LEVEL=${SECURITY_LEVEL_HIGH} ;;
        "critical") CURRENT_SECURITY_LEVEL=${SECURITY_LEVEL_CRITICAL} ;;
        *) 
            log_warn "Unknown security level: ${security_level}, using high"
            CURRENT_SECURITY_LEVEL=${SECURITY_LEVEL_HIGH}
            ;;
    esac
    
    # Load allowed operations
    mapfile -t ALLOWED_OPERATIONS < <(jq -r '.allowed_operations[]?' "${SECURITY_POLICY_FILE}")
    
    # Load restricted paths
    mapfile -t RESTRICTED_PATHS < <(jq -r '.restricted_paths[]?' "${SECURITY_POLICY_FILE}")
    
    audit_log "SECURITY_POLICY" "Security policy loaded: level=${CURRENT_SECURITY_LEVEL}, operations=${#ALLOWED_OPERATIONS[@]}, restricted=${#RESTRICTED_PATHS[@]}"
    log_success "Security policy loaded successfully"
}

# Set default security policy
set_default_security_policy() {
    log_info "Setting default security policy..."
    
    CURRENT_SECURITY_LEVEL=${SECURITY_LEVEL_HIGH}
    ALLOWED_OPERATIONS=("database_clean" "telemetry_modify" "backup_create" "backup_restore")
    RESTRICTED_PATHS=("/etc" "/usr" "/bin" "/sbin" "/boot" "/sys" "/proc")
    
    audit_log "SECURITY_DEFAULT" "Default security policy applied"
    log_success "Default security policy set"
}

# Input validation functions
validate_path() {
    local path="$1"
    local operation="${2:-read}"
    
    # Check path length
    if [[ ${#path} -gt ${MAX_PATH_LENGTH} ]]; then
        log_error "Path too long (${#path} > ${MAX_PATH_LENGTH}): ${path}"
        return 1
    fi
    
    # Check for null bytes
    if [[ "${path}" == *$'\0'* ]]; then
        log_error "Path contains null bytes: ${path}"
        return 1
    fi
    
    # Check for dangerous characters
    if [[ "${path}" =~ [[:cntrl:]] ]]; then
        log_error "Path contains control characters: ${path}"
        return 1
    fi
    
    # Resolve path to prevent directory traversal
    local resolved_path
    if ! resolved_path=$(realpath -m "${path}" 2>/dev/null); then
        log_error "Cannot resolve path: ${path}"
        return 1
    fi
    
    # Check against restricted paths
    for restricted in "${RESTRICTED_PATHS[@]}"; do
        if [[ "${resolved_path}" == "${restricted}"* ]]; then
            log_error "Access denied to restricted path: ${resolved_path}"
            audit_log "SECURITY_VIOLATION" "Attempted access to restricted path: ${resolved_path}"
            return 1
        fi
    done
    
    # Additional checks for write operations
    if [[ "${operation}" == "write" || "${operation}" == "modify" ]]; then
        # Check if path is writable
        local parent_dir
        parent_dir=$(dirname "${resolved_path}")
        
        if [[ ! -w "${parent_dir}" ]]; then
            log_error "No write permission for directory: ${parent_dir}"
            return 1
        fi
    fi
    
    audit_log "PATH_VALIDATE" "Path validated: ${resolved_path} (operation: ${operation})"
    return 0
}

validate_filename() {
    local filename="$1"
    
    # Check filename length
    if [[ ${#filename} -gt ${MAX_FILENAME_LENGTH} ]]; then
        log_error "Filename too long (${#filename} > ${MAX_FILENAME_LENGTH}): ${filename}"
        return 1
    fi
    
    # Check for dangerous characters
    if [[ "${filename}" =~ [[:cntrl:]/\\] ]]; then
        log_error "Filename contains dangerous characters: ${filename}"
        return 1
    fi
    
    # Check for reserved names (Windows compatibility)
    local reserved_names=("CON" "PRN" "AUX" "NUL" "COM1" "COM2" "COM3" "COM4" "COM5" "COM6" "COM7" "COM8" "COM9" "LPT1" "LPT2" "LPT3" "LPT4" "LPT5" "LPT6" "LPT7" "LPT8" "LPT9")
    local basename="${filename%%.*}"
    
    for reserved in "${reserved_names[@]}"; do
        if [[ "${basename^^}" == "${reserved}" ]]; then
            log_error "Filename uses reserved name: ${filename}"
            return 1
        fi
    done
    
    return 0
}

validate_file_extension() {
    local filename="$1"
    local extension="${filename##*.}"
    
    # Check if extension is allowed
    for allowed_ext in "${ALLOWED_FILE_EXTENSIONS[@]}"; do
        if [[ "${extension}" == "${allowed_ext}" ]]; then
            return 0
        fi
    done
    
    log_error "File extension not allowed: ${extension}"
    return 1
}

# Operation authorization
authorize_operation() {
    local operation="$1"
    local resource="${2:-}"
    
    # Check if operation is allowed
    local operation_allowed=false
    for allowed_op in "${ALLOWED_OPERATIONS[@]}"; do
        if [[ "${operation}" == "${allowed_op}" ]]; then
            operation_allowed=true
            break
        fi
    done
    
    if [[ "${operation_allowed}" != "true" ]]; then
        log_error "Operation not authorized: ${operation}"
        audit_log "SECURITY_VIOLATION" "Unauthorized operation attempted: ${operation}"
        return 1
    fi
    
    # Additional security checks based on security level
    case "${CURRENT_SECURITY_LEVEL}" in
        "${SECURITY_LEVEL_CRITICAL}")
            # Require explicit confirmation for critical operations
            if [[ "${operation}" =~ ^(database_clean|telemetry_modify)$ ]]; then
                if ! confirm_critical_operation "${operation}" "${resource}"; then
                    log_error "Critical operation not confirmed: ${operation}"
                    return 1
                fi
            fi
            ;;
        "${SECURITY_LEVEL_HIGH}")
            # Additional validation for high-risk operations
            if [[ "${operation}" == "database_clean" && -n "${resource}" ]]; then
                if ! validate_database_file "${resource}"; then
                    log_error "Database file validation failed: ${resource}"
                    return 1
                fi
            fi
            ;;
    esac
    
    audit_log "OPERATION_AUTH" "Operation authorized: ${operation} on ${resource}"
    return 0
}

# Critical operation confirmation
confirm_critical_operation() {
    local operation="$1"
    local resource="$2"
    
    log_warn "CRITICAL OPERATION: ${operation} on ${resource}"
    log_warn "This operation will modify system files and cannot be undone easily."
    
    # In production, this might integrate with enterprise approval systems
    # For now, we'll use a simple confirmation
    read -p "Type 'CONFIRM' to proceed: " confirmation
    
    if [[ "${confirmation}" == "CONFIRM" ]]; then
        audit_log "CRITICAL_CONFIRM" "Critical operation confirmed: ${operation}"
        return 0
    else
        audit_log "CRITICAL_DENY" "Critical operation denied: ${operation}"
        return 1
    fi
}

# File integrity validation
validate_database_file() {
    local db_file="$1"
    
    # Check if file exists and is readable
    if [[ ! -r "${db_file}" ]]; then
        log_error "Database file not readable: ${db_file}"
        return 1
    fi
    
    # Check file size (basic sanity check)
    local file_size
    file_size=$(stat -f%z "${db_file}" 2>/dev/null || stat -c%s "${db_file}" 2>/dev/null)
    
    if [[ ${file_size} -eq 0 ]]; then
        log_error "Database file is empty: ${db_file}"
        return 1
    fi
    
    if [[ ${file_size} -gt 1073741824 ]]; then  # 1GB limit
        log_error "Database file too large (${file_size} bytes): ${db_file}"
        return 1
    fi
    
    # Validate SQLite file format
    if is_command_available sqlite3; then
        if ! sqlite3 "${db_file}" "PRAGMA integrity_check;" >/dev/null 2>&1; then
            log_error "Database integrity check failed: ${db_file}"
            return 1
        fi
    fi
    
    return 0
}

# Security audit functions
perform_security_audit() {
    log_info "Performing security audit..."
    
    local audit_results=()
    
    # Check file permissions
    audit_results+=("file_permissions:$(check_file_permissions)")
    
    # Check for sensitive data exposure
    audit_results+=("data_exposure:$(check_data_exposure)")
    
    # Check system integrity
    audit_results+=("system_integrity:$(check_system_integrity)")
    
    # Log audit results
    for result in "${audit_results[@]}"; do
        audit_log "SECURITY_AUDIT" "${result}"
    done
    
    log_success "Security audit completed"
    return 0
}

check_file_permissions() {
    # Check permissions on sensitive files
    local sensitive_files=("${LOG_FILE}" "${AUDIT_LOG_FILE}")
    
    for file in "${sensitive_files[@]}"; do
        if [[ -f "${file}" ]]; then
            local perms
            perms=$(stat -f%Mp%Lp "${file}" 2>/dev/null || stat -c%a "${file}" 2>/dev/null)
            if [[ "${perms}" != "600" && "${perms}" != "644" ]]; then
                log_warn "Insecure file permissions: ${file} (${perms})"
                return 1
            fi
        fi
    done
    
    return 0
}

check_data_exposure() {
    # Check for potential data exposure in logs
    if [[ -f "${LOG_FILE}" ]]; then
        if grep -q -E "(password|secret|key|token)" "${LOG_FILE}"; then
            log_warn "Potential sensitive data in logs"
            return 1
        fi
    fi
    
    return 0
}

check_system_integrity() {
    # Basic system integrity checks
    local required_commands=("sqlite3" "jq" "curl")
    
    for cmd in "${required_commands[@]}"; do
        if ! is_command_available "${cmd}"; then
            log_warn "Required command not available: ${cmd}"
            return 1
        fi
    done
    
    return 0
}

# Export security functions
export -f init_security validate_path validate_filename validate_file_extension
export -f authorize_operation perform_security_audit
export CURRENT_SECURITY_LEVEL ALLOWED_OPERATIONS RESTRICTED_PATHS

log_debug "Security module loaded"
