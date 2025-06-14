#!/bin/bash

# config_loader.sh
#
# Unified configuration loader for Augment VIP
# Ensures all modules use identical data patterns and formats
# Production-ready with comprehensive validation and error handling

set -euo pipefail

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Configuration file path
readonly CONFIG_FILE="${PROJECT_ROOT:-$(dirname "$(dirname "${BASH_SOURCE[0]}")")}/src/config/augment_patterns.json"

# Global configuration variables
declare -a AUGMENT_PATTERNS=()
declare -a AUGMENT_CORE_PATTERNS=()
declare -a TELEMETRY_PATTERNS=()
declare -a TRIAL_PATTERNS=()
declare -a ANALYTICS_PATTERNS=()
declare -a AI_PATTERNS=()
declare -a AUTH_PATTERNS=()

# Telemetry field mappings
declare MACHINE_ID_FIELD=""
declare DEVICE_ID_FIELD=""
declare SQM_ID_FIELD=""
declare MACHINE_ID_ALT_FIELD=""
declare DEVICE_ID_ALT_FIELD=""
declare SQM_ID_ALT_FIELD=""

# File path configurations
declare -a STORAGE_FILE_PATHS=()
declare -a TOKEN_PATHS=()
declare -a SESSION_PATHS=()

# SQL generation settings
declare SQL_CASE_SENSITIVE="false"
declare SQL_USE_LOWER_FUNCTION="true"
declare SQL_TRANSACTION_MODE="IMMEDIATE"
declare SQL_VACUUM_AFTER_DELETE="true"

# ID generation settings
declare MACHINE_ID_LENGTH="64"
declare MACHINE_ID_FORMAT="hex"
declare DEVICE_ID_FORMAT="uuid"
declare SQM_ID_FORMAT="uuid"
declare -a ENTROPY_SOURCES=()

# Configuration validation
validate_config_file() {
    local config_file="$1"
    
    log_debug "Validating configuration file: ${config_file}"
    
    # Check file existence
    if [[ ! -f "${config_file}" ]]; then
        log_error "Configuration file not found: ${config_file}"
        return 1
    fi
    
    # Check file readability
    if [[ ! -r "${config_file}" ]]; then
        log_error "Configuration file not readable: ${config_file}"
        return 1
    fi
    
    # Validate JSON format
    if ! jq empty "${config_file}" 2>/dev/null; then
        log_error "Configuration file is not valid JSON: ${config_file}"
        return 1
    fi
    
    # Check required fields
    local required_fields=(
        ".version"
        ".database_patterns"
        ".telemetry_fields"
        ".file_paths"
    )
    
    for field in "${required_fields[@]}"; do
        if ! jq -e "${field}" "${config_file}" >/dev/null 2>&1; then
            log_error "Required field missing in configuration: ${field}"
            return 1
        fi
    done
    
    log_debug "Configuration file validation passed"
    return 0
}

# Load database patterns
load_database_patterns() {
    local config_file="$1"
    
    log_debug "Loading database patterns from configuration"
    
    # Load individual pattern categories
    readarray -t AUGMENT_CORE_PATTERNS < <(jq -r '.database_patterns.augment_core[]?' "${config_file}" 2>/dev/null || true)
    readarray -t TELEMETRY_PATTERNS < <(jq -r '.database_patterns.telemetry[]?' "${config_file}" 2>/dev/null || true)
    readarray -t TRIAL_PATTERNS < <(jq -r '.database_patterns.trial_data[]?' "${config_file}" 2>/dev/null || true)
    readarray -t ANALYTICS_PATTERNS < <(jq -r '.database_patterns.analytics[]?' "${config_file}" 2>/dev/null || true)
    readarray -t AI_PATTERNS < <(jq -r '.database_patterns.ai_services[]?' "${config_file}" 2>/dev/null || true)
    readarray -t AUTH_PATTERNS < <(jq -r '.database_patterns.authentication[]?' "${config_file}" 2>/dev/null || true)
    
    # Combine all patterns into master array
    AUGMENT_PATTERNS=()
    AUGMENT_PATTERNS+=("${AUGMENT_CORE_PATTERNS[@]}")
    AUGMENT_PATTERNS+=("${TELEMETRY_PATTERNS[@]}")
    AUGMENT_PATTERNS+=("${TRIAL_PATTERNS[@]}")
    AUGMENT_PATTERNS+=("${ANALYTICS_PATTERNS[@]}")
    AUGMENT_PATTERNS+=("${AI_PATTERNS[@]}")
    AUGMENT_PATTERNS+=("${AUTH_PATTERNS[@]}")
    
    # Remove empty entries
    local temp_patterns=()
    for pattern in "${AUGMENT_PATTERNS[@]}"; do
        if [[ -n "${pattern}" && "${pattern}" != "null" ]]; then
            temp_patterns+=("${pattern}")
        fi
    done
    AUGMENT_PATTERNS=("${temp_patterns[@]}")
    
    log_debug "Loaded ${#AUGMENT_PATTERNS[@]} database patterns"
    return 0
}

# Load telemetry field mappings
load_telemetry_fields() {
    local config_file="$1"
    
    log_debug "Loading telemetry field mappings"
    
    MACHINE_ID_FIELD=$(jq -r '.telemetry_fields.machine_id // "telemetry.machineId"' "${config_file}")
    DEVICE_ID_FIELD=$(jq -r '.telemetry_fields.device_id // "telemetry.devDeviceId"' "${config_file}")
    SQM_ID_FIELD=$(jq -r '.telemetry_fields.sqm_id // "telemetry.sqmId"' "${config_file}")
    
    # Load fallback fields
    MACHINE_ID_ALT_FIELD=$(jq -r '.telemetry_fields.fallback_fields.machine_id_alt // "machineId"' "${config_file}")
    DEVICE_ID_ALT_FIELD=$(jq -r '.telemetry_fields.fallback_fields.device_id_alt // "deviceId"' "${config_file}")
    SQM_ID_ALT_FIELD=$(jq -r '.telemetry_fields.fallback_fields.sqm_id_alt // "sqmId"' "${config_file}")
    
    log_debug "Telemetry fields loaded: machine=${MACHINE_ID_FIELD}, device=${DEVICE_ID_FIELD}, sqm=${SQM_ID_FIELD}"
    return 0
}

# Load file path configurations
load_file_paths() {
    local config_file="$1"
    
    log_debug "Loading file path configurations"
    
    readarray -t STORAGE_FILE_PATHS < <(jq -r '.file_paths.storage_files[]?' "${config_file}" 2>/dev/null || true)
    readarray -t TOKEN_PATHS < <(jq -r '.file_paths.token_paths[]?' "${config_file}" 2>/dev/null || true)
    readarray -t SESSION_PATHS < <(jq -r '.file_paths.session_paths[]?' "${config_file}" 2>/dev/null || true)
    
    # Remove empty entries
    local temp_storage=()
    for path in "${STORAGE_FILE_PATHS[@]}"; do
        if [[ -n "${path}" && "${path}" != "null" ]]; then
            temp_storage+=("${path}")
        fi
    done
    STORAGE_FILE_PATHS=("${temp_storage[@]}")
    
    log_debug "File paths loaded: storage=${#STORAGE_FILE_PATHS[@]}, tokens=${#TOKEN_PATHS[@]}, sessions=${#SESSION_PATHS[@]}"
    return 0
}

# Load SQL generation settings
load_sql_settings() {
    local config_file="$1"
    
    log_debug "Loading SQL generation settings"
    
    SQL_CASE_SENSITIVE=$(jq -r '.sql_generation.case_sensitive // false' "${config_file}")
    SQL_USE_LOWER_FUNCTION=$(jq -r '.sql_generation.use_lower_function // true' "${config_file}")
    SQL_TRANSACTION_MODE=$(jq -r '.sql_generation.transaction_mode // "IMMEDIATE"' "${config_file}")
    SQL_VACUUM_AFTER_DELETE=$(jq -r '.sql_generation.vacuum_after_delete // true' "${config_file}")
    
    log_debug "SQL settings loaded: case_sensitive=${SQL_CASE_SENSITIVE}, use_lower=${SQL_USE_LOWER_FUNCTION}"
    return 0
}

# Load ID generation settings
load_id_settings() {
    local config_file="$1"
    
    log_debug "Loading ID generation settings"
    
    MACHINE_ID_LENGTH=$(jq -r '.id_generation.machine_id_length // 64' "${config_file}")
    MACHINE_ID_FORMAT=$(jq -r '.id_generation.machine_id_format // "hex"' "${config_file}")
    DEVICE_ID_FORMAT=$(jq -r '.id_generation.device_id_format // "uuid"' "${config_file}")
    SQM_ID_FORMAT=$(jq -r '.id_generation.sqm_id_format // "uuid"' "${config_file}")
    
    readarray -t ENTROPY_SOURCES < <(jq -r '.id_generation.entropy_sources[]?' "${config_file}" 2>/dev/null || true)
    
    log_debug "ID settings loaded: machine_length=${MACHINE_ID_LENGTH}, entropy_sources=${#ENTROPY_SOURCES[@]}"
    return 0
}

# Main configuration loading function
load_augment_config() {
    local config_file="${1:-${CONFIG_FILE}}"
    
    log_info "Loading unified Augment configuration from: ${config_file}"
    
    # Validate configuration file
    if ! validate_config_file "${config_file}"; then
        log_error "Configuration validation failed"
        return 1
    fi
    
    # Load all configuration sections
    if ! load_database_patterns "${config_file}"; then
        log_error "Failed to load database patterns"
        return 1
    fi
    
    if ! load_telemetry_fields "${config_file}"; then
        log_error "Failed to load telemetry fields"
        return 1
    fi
    
    if ! load_file_paths "${config_file}"; then
        log_error "Failed to load file paths"
        return 1
    fi
    
    if ! load_sql_settings "${config_file}"; then
        log_error "Failed to load SQL settings"
        return 1
    fi
    
    if ! load_id_settings "${config_file}"; then
        log_error "Failed to load ID settings"
        return 1
    fi
    
    # Log configuration summary
    local config_version
    config_version=$(jq -r '.version // "unknown"' "${config_file}")
    
    log_success "Configuration loaded successfully"
    log_info "  Version: ${config_version}"
    log_info "  Total patterns: ${#AUGMENT_PATTERNS[@]}"
    log_info "  Storage paths: ${#STORAGE_FILE_PATHS[@]}"
    log_info "  Token paths: ${#TOKEN_PATHS[@]}"
    log_info "  Session paths: ${#SESSION_PATHS[@]}"
    
    audit_log "CONFIG_LOAD" "Configuration loaded: version=${config_version}, patterns=${#AUGMENT_PATTERNS[@]}"
    
    return 0
}

# Export configuration variables and functions
export -f load_augment_config validate_config_file
export -f load_database_patterns load_telemetry_fields load_file_paths
export -f load_sql_settings load_id_settings

# Export configuration arrays and variables
export AUGMENT_PATTERNS AUGMENT_CORE_PATTERNS TELEMETRY_PATTERNS
export TRIAL_PATTERNS ANALYTICS_PATTERNS AI_PATTERNS AUTH_PATTERNS
export MACHINE_ID_FIELD DEVICE_ID_FIELD SQM_ID_FIELD
export MACHINE_ID_ALT_FIELD DEVICE_ID_ALT_FIELD SQM_ID_ALT_FIELD
export STORAGE_FILE_PATHS TOKEN_PATHS SESSION_PATHS
export SQL_CASE_SENSITIVE SQL_USE_LOWER_FUNCTION SQL_TRANSACTION_MODE SQL_VACUUM_AFTER_DELETE
export MACHINE_ID_LENGTH MACHINE_ID_FORMAT DEVICE_ID_FORMAT SQM_ID_FORMAT ENTROPY_SOURCES

log_debug "Configuration loader module initialized"
