#!/bin/bash
# validation.sh
#
# Auto-fixed for readonly variable conflicts

# Prevent multiple loading
if [[ "${VALIDATION_SH_LOADED:-}" == "true" ]]; then
    return 0
fi
if [[ -z "${VALIDATION_SH_LOADED:-}" ]]; then
    readonly VALIDATION_SH_LOADED="true"
fi

# core/validation.sh
#
# Enterprise-grade input validation and sanitization module
# Production-ready with comprehensive security controls
# Zero-trust input validation for all user inputs

set -euo pipefail

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Validation constants
if [[ -z "${MAX_INPUT_LENGTH:-}" ]]; then
    readonly MAX_INPUT_LENGTH=1024
fi
if [[ -z "${MAX_COMMAND_LENGTH:-}" ]]; then
    readonly MAX_COMMAND_LENGTH=256
fi
if [[ -z "${MAX_ARGUMENT_COUNT:-}" ]]; then
    readonly MAX_ARGUMENT_COUNT=32
fi

# Allowed characters patterns
if [[ -z "${PATTERN_ALPHANUMERIC:-}" ]]; then
    readonly PATTERN_ALPHANUMERIC='^[a-zA-Z0-9]+$'
fi
if [[ -z "${PATTERN_FILENAME:-}" ]]; then
    readonly PATTERN_FILENAME='^[a-zA-Z0-9._-]+$'
fi
if [[ -z "${PATTERN_PATH:-}" ]]; then
    readonly PATTERN_PATH='^[a-zA-Z0-9._/-]+$'
fi
if [[ -z "${PATTERN_VERSION:-}" ]]; then
    readonly PATTERN_VERSION='^[0-9]+\.[0-9]+\.[0-9]+$'
fi
if [[ -z "${PATTERN_UUID:-}" ]]; then
    readonly PATTERN_UUID='^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
fi

# Dangerous patterns to reject
if [[ -z "${DANGEROUS_PATTERNS:-}" ]]; then
    readonly DANGEROUS_PATTERNS=(
        '\.\./\.\.'          # Directory traversal
        '\$\('               # Command substitution
        '`'                  # Command substitution
        '\|\|'               # Command chaining
        '&&'                 # Command chaining
        ';'                  # Command separator
        '\|'                 # Pipe
        '>'                  # Redirection
        '<'                  # Redirection
        '\*'                 # Wildcard (in some contexts)
        '\?'                 # Wildcard (in some contexts)
        '\['                 # Character class
        '\]'                 # Character class
        '\{'                 # Brace expansion
        '\}'                 # Brace expansion
        '\$\{'               # Variable expansion
        '\n'                 # Newline
        '\r'                 # Carriage return
        '\0'                 # Null byte
    )
fi

# Initialize validation module
init_validation() {
    log_info "Initializing input validation module..."
    
    # Set up validation rules
    setup_validation_rules
    
    audit_log "VALIDATION_INIT" "Input validation module initialized"
    log_success "Input validation module initialized"
}

# Setup validation rules
setup_validation_rules() {
    log_debug "Setting up validation rules..."
    
    # Additional validation rules can be loaded from configuration
    local validation_config="config/validation.json"
    
    if [[ -f "${validation_config}" ]]; then
        load_validation_config "${validation_config}"
    fi
    
    log_debug "Validation rules configured"
}

# Load validation configuration
load_validation_config() {
    local config_file="$1"
    
    if ! is_command_available jq; then
        log_warn "jq not available, using default validation rules"
        return 0
    fi
    
    log_debug "Loading validation configuration from: ${config_file}"
    
    # Validate JSON format
    if ! jq empty "${config_file}" 2>/dev/null; then
        log_error "Invalid JSON format in validation config"
        return 1
    fi
    
    # Load custom patterns if defined
    # This could extend the validation rules based on configuration
    
    log_debug "Validation configuration loaded"
}

# Generic input validation
validate_input() {
    local input="$1"
    local input_type="${2:-generic}"
    local max_length="${3:-${MAX_INPUT_LENGTH}}"
    
    # Check input length
    if [[ ${#input} -gt ${max_length} ]]; then
        log_error "Input too long (${#input} > ${max_length}): ${input:0:50}..."
        return 1
    fi
    
    # Check for null bytes
    if [[ "${input}" == *$'\0'* ]]; then
        log_error "Input contains null bytes"
        return 1
    fi
    
    # Check for dangerous patterns
    for pattern in "${DANGEROUS_PATTERNS[@]}"; do
        if [[ "${input}" =~ ${pattern} ]]; then
            log_error "Input contains dangerous pattern: ${pattern}"
            audit_log "VALIDATION_VIOLATION" "Dangerous pattern detected: ${pattern} in input: ${input:0:50}..."
            return 1
        fi
    done
    
    # Type-specific validation
    case "${input_type}" in
        "filename")
            validate_filename_input "${input}"
            ;;
        "path")
            validate_path_input "${input}"
            ;;
        "command")
            validate_command_input "${input}"
            ;;
        "version")
            validate_version_input "${input}"
            ;;
        "uuid")
            validate_uuid_input "${input}"
            ;;
        "alphanumeric")
            validate_alphanumeric_input "${input}"
            ;;
        *)
            # Generic validation passed
            ;;
    esac
    
    audit_log "INPUT_VALIDATED" "Input validated: type=${input_type}, length=${#input}"
    return 0
}

# Filename validation
validate_filename_input() {
    local filename="$1"
    
    # Check filename pattern
    if [[ ! "${filename}" =~ ${PATTERN_FILENAME} ]]; then
        log_error "Invalid filename format: ${filename}"
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
    
    # Check filename length
    if [[ ${#filename} -gt 255 ]]; then
        log_error "Filename too long: ${filename}"
        return 1
    fi
    
    return 0
}

# Path validation
validate_path_input() {
    local path="$1"
    
    # Check path pattern
    if [[ ! "${path}" =~ ${PATTERN_PATH} ]]; then
        log_error "Invalid path format: ${path}"
        return 1
    fi
    
    # Check for directory traversal
    if [[ "${path}" == *".."* ]]; then
        log_error "Path contains directory traversal: ${path}"
        return 1
    fi
    
    # Check path length
    if [[ ${#path} -gt 4096 ]]; then
        log_error "Path too long: ${path}"
        return 1
    fi
    
    return 0
}

# Command validation
validate_command_input() {
    local command="$1"
    
    # Check command length
    if [[ ${#command} -gt ${MAX_COMMAND_LENGTH} ]]; then
        log_error "Command too long: ${command}"
        return 1
    fi
    
    # Check for command injection patterns
    local injection_patterns=('\$\(' '`' '\|\|' '&&' ';' '\|' '>' '<')
    
    for pattern in "${injection_patterns[@]}"; do
        if [[ "${command}" =~ ${pattern} ]]; then
            log_error "Command contains injection pattern: ${pattern}"
            return 1
        fi
    done
    
    # Check if command is in allowed list (if defined)
    # This could be extended to check against a whitelist
    
    return 0
}

# Version validation
validate_version_input() {
    local version="$1"
    
    if [[ ! "${version}" =~ ${PATTERN_VERSION} ]]; then
        log_error "Invalid version format: ${version}"
        return 1
    fi
    
    return 0
}

# UUID validation
validate_uuid_input() {
    local uuid="$1"
    
    if [[ ! "${uuid}" =~ ${PATTERN_UUID} ]]; then
        log_error "Invalid UUID format: ${uuid}"
        return 1
    fi
    
    return 0
}

# Alphanumeric validation
validate_alphanumeric_input() {
    local input="$1"
    
    if [[ ! "${input}" =~ ${PATTERN_ALPHANUMERIC} ]]; then
        log_error "Input contains non-alphanumeric characters: ${input}"
        return 1
    fi
    
    return 0
}

# Sanitize input by removing dangerous characters
sanitize_input() {
    local input="$1"
    local sanitization_level="${2:-basic}"
    
    local sanitized="${input}"
    
    case "${sanitization_level}" in
        "basic")
            # Remove null bytes and control characters
            sanitized=$(echo "${sanitized}" | tr -d '\0\r\n' | tr -d '[:cntrl:]')
            ;;
        "strict")
            # Keep only alphanumeric, spaces, and basic punctuation
            sanitized=$(echo "${sanitized}" | tr -cd '[:alnum:][:space:]._-')
            ;;
        "filename")
            # Keep only characters safe for filenames
            sanitized=$(echo "${sanitized}" | tr -cd '[:alnum:]._-')
            ;;
        "path")
            # Keep only characters safe for paths
            sanitized=$(echo "${sanitized}" | tr -cd '[:alnum:]._/-')
            ;;
        *)
            log_error "Unknown sanitization level: ${sanitization_level}"
            return 1
            ;;
    esac
    
    # Log if sanitization changed the input
    if [[ "${input}" != "${sanitized}" ]]; then
        log_warn "Input sanitized: '${input}' -> '${sanitized}'"
        audit_log "INPUT_SANITIZED" "Input sanitized with level: ${sanitization_level}"
    fi
    
    echo "${sanitized}"
}

# Validate command line arguments
validate_arguments() {
    local args=("$@")
    
    # Check argument count
    if [[ ${#args[@]} -gt ${MAX_ARGUMENT_COUNT} ]]; then
        log_error "Too many arguments (${#args[@]} > ${MAX_ARGUMENT_COUNT})"
        return 1
    fi
    
    # Validate each argument
    for arg in "${args[@]}"; do
        if ! validate_input "${arg}" "generic"; then
            log_error "Invalid argument: ${arg}"
            return 1
        fi
    done
    
    audit_log "ARGS_VALIDATED" "Command line arguments validated: count=${#args[@]}"
    return 0
}

# Validate JSON input
validate_json_input() {
    local json_input="$1"
    local max_size="${2:-1048576}"  # 1MB default
    
    # Check size
    if [[ ${#json_input} -gt ${max_size} ]]; then
        log_error "JSON input too large (${#json_input} > ${max_size})"
        return 1
    fi
    
    # Validate JSON format
    if ! echo "${json_input}" | jq empty 2>/dev/null; then
        log_error "Invalid JSON format"
        return 1
    fi
    
    # Check for dangerous content in JSON
    if echo "${json_input}" | jq -r 'paths(scalars) as $p | getpath($p)' | grep -qE '\$\(|`|\|\||&&|;'; then
        log_error "JSON contains dangerous content"
        return 1
    fi
    
    return 0
}

# Validate file content
validate_file_content() {
    local file_path="$1"
    local content_type="${2:-text}"
    local max_size="${3:-10485760}"  # 10MB default
    
    # Check if file exists
    if [[ ! -f "${file_path}" ]]; then
        log_error "File does not exist: ${file_path}"
        return 1
    fi
    
    # Check file size
    local file_size
    file_size=$(stat -f%z "${file_path}" 2>/dev/null || stat -c%s "${file_path}" 2>/dev/null)
    
    if [[ ${file_size} -gt ${max_size} ]]; then
        log_error "File too large (${file_size} > ${max_size}): ${file_path}"
        return 1
    fi
    
    # Content-type specific validation
    case "${content_type}" in
        "json")
            if ! jq empty "${file_path}" 2>/dev/null; then
                log_error "Invalid JSON file: ${file_path}"
                return 1
            fi
            ;;
        "sqlite")
            if is_command_available sqlite3; then
                if ! sqlite3 "${file_path}" "PRAGMA integrity_check;" >/dev/null 2>&1; then
                    log_error "Invalid SQLite file: ${file_path}"
                    return 1
                fi
            fi
            ;;
        "text")
            # Check for binary content
            if file "${file_path}" | grep -q "binary"; then
                log_error "File contains binary content: ${file_path}"
                return 1
            fi
            ;;
    esac
    
    audit_log "FILE_VALIDATED" "File content validated: ${file_path} (type: ${content_type})"
    return 0
}

# Validate environment variables
validate_environment() {
    local required_vars=("$@")
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Required environment variable not set: ${var}"
            return 1
        fi
        
        # Validate environment variable content
        if ! validate_input "${!var}" "generic"; then
            log_error "Invalid content in environment variable: ${var}"
            return 1
        fi
    done
    
    audit_log "ENV_VALIDATED" "Environment variables validated: ${required_vars[*]}"
    return 0
}

# Create validation report
create_validation_report() {
    local report_file="${1:-logs/validation_report.txt}"
    
    log_info "Creating validation report: ${report_file}"
    
    {
        echo "=== Input Validation Report ==="
        echo "Generated: $(date)"
        echo "Script: ${SCRIPT_NAME} v${SCRIPT_VERSION}"
        echo ""
        
        echo "Validation Rules:"
        echo "- Max input length: ${MAX_INPUT_LENGTH}"
        echo "- Max command length: ${MAX_COMMAND_LENGTH}"
        echo "- Max argument count: ${MAX_ARGUMENT_COUNT}"
        echo ""
        
        echo "Dangerous Patterns Checked:"
        for pattern in "${DANGEROUS_PATTERNS[@]}"; do
            echo "  - ${pattern}"
        done
        echo ""
        
        echo "Validation Patterns:"
        echo "  - Alphanumeric: ${PATTERN_ALPHANUMERIC}"
        echo "  - Filename: ${PATTERN_FILENAME}"
        echo "  - Path: ${PATTERN_PATH}"
        echo "  - Version: ${PATTERN_VERSION}"
        echo "  - UUID: ${PATTERN_UUID}"
        
    } > "${report_file}"
    
    log_success "Validation report created: ${report_file}"
}

# Export validation functions
export -f init_validation validate_input sanitize_input validate_arguments
export -f validate_json_input validate_file_content validate_environment
export -f create_validation_report

log_debug "Input validation module loaded"
