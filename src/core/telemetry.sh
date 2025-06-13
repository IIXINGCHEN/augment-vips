#!/bin/bash
# telemetry.sh
#
# Auto-fixed for readonly variable conflicts

# Prevent multiple loading
if [[ "${TELEMETRY_SH_LOADED:-}" == "true" ]]; then
    return 0
fi
if [[ -z "${TELEMETRY_SH_LOADED:-}" ]]; then
    readonly TELEMETRY_SH_LOADED="true"
fi

# core/telemetry.sh
#
# Enterprise-grade telemetry ID processing module
# Production-ready with comprehensive validation and security
# Zero-redundancy telemetry modification with audit trails

set -euo pipefail

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/security.sh"
source "$(dirname "${BASH_SOURCE[0]}")/validation.sh"
source "$(dirname "${BASH_SOURCE[0]}")/backup.sh"

# Telemetry constants
if [[ -z "${TELEMETRY_FIELDS:-}" ]]; then
    readonly TELEMETRY_FIELDS=(
        "telemetry.machineId"
        "telemetry.devDeviceId"
        "telemetry.sqmId"
    )
fi

if [[ -z "${MACHINE_ID_LENGTH:-}" ]]; then
    readonly MACHINE_ID_LENGTH=64
fi
if [[ -z "${UUID_PATTERN:-}" ]]; then
    readonly UUID_PATTERN='^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
fi
if [[ -z "${HEX_PATTERN:-}" ]]; then
    readonly HEX_PATTERN='^[0-9a-fA-F]+$'
fi

# Global telemetry statistics
declare -A TELEMETRY_STATS=()

# Initialize telemetry module
init_telemetry() {
    log_info "Initializing telemetry processing module..."
    
    # Check jq availability
    if ! is_command_available jq; then
        log_error "jq is required but not available"
        return 1
    fi
    
    # Verify jq functionality
    if ! verify_jq_functionality; then
        log_error "jq functionality verification failed"
        return 1
    fi
    
    # Initialize statistics
    TELEMETRY_STATS["files_processed"]=0
    TELEMETRY_STATS["ids_modified"]=0
    TELEMETRY_STATS["errors_encountered"]=0
    TELEMETRY_STATS["backups_created"]=0
    
    audit_log "TELEMETRY_INIT" "Telemetry processing module initialized"
    log_success "Telemetry processing module initialized"
}

# Verify jq functionality
verify_jq_functionality() {
    log_debug "Verifying jq functionality..."
    
    # Test basic jq operations
    local test_json='{"test": "value", "number": 42}'
    
    # Test JSON parsing
    if ! echo "${test_json}" | jq '.test' >/dev/null 2>&1; then
        log_error "jq JSON parsing test failed"
        return 1
    fi
    
    # Test JSON modification
    if ! echo "${test_json}" | jq '.test = "modified"' >/dev/null 2>&1; then
        log_error "jq JSON modification test failed"
        return 1
    fi
    
    log_debug "jq functionality verification passed"
    return 0
}

# Modify telemetry IDs in storage file
modify_telemetry_ids() {
    local storage_file="$1"
    local dry_run="${2:-false}"
    
    log_info "Modifying telemetry IDs in: ${storage_file}"
    
    # Validate storage file
    if ! validate_storage_file "${storage_file}"; then
        log_error "Storage file validation failed: ${storage_file}"
        return 1
    fi
    
    # Authorize operation
    if ! authorize_operation "telemetry_modify" "${storage_file}"; then
        log_error "Telemetry modification operation not authorized"
        return 1
    fi
    
    # Create backup
    local backup_file=""
    if [[ "${dry_run}" != "true" ]]; then
        backup_file=$(create_storage_backup "${storage_file}")
        if [[ -z "${backup_file}" ]]; then
            log_error "Failed to create backup for: ${storage_file}"
            return 1
        fi
        ((TELEMETRY_STATS["backups_created"]++))
    fi
    
    # Generate new IDs
    local new_machine_id
    local new_device_id
    local new_sqm_id
    
    new_machine_id=$(generate_machine_id)
    new_device_id=$(generate_uuid_v4)
    new_sqm_id=$(generate_uuid_v4)
    
    log_debug "Generated new IDs:"
    log_debug "  Machine ID: ${new_machine_id}"
    log_debug "  Device ID: ${new_device_id}"
    log_debug "  SQM ID: ${new_sqm_id}"
    
    # Perform modification
    local start_time=$(date +%s.%3N)
    local ids_modified=0
    
    if [[ "${dry_run}" == "true" ]]; then
        ids_modified=$(count_existing_telemetry_fields "${storage_file}")
        log_info "DRY RUN: Would modify ${ids_modified} telemetry fields in ${storage_file}"
    else
        if modify_storage_file "${storage_file}" "${new_machine_id}" "${new_device_id}" "${new_sqm_id}"; then
            ids_modified=${#TELEMETRY_FIELDS[@]}
            log_success "Modified ${ids_modified} telemetry IDs in ${storage_file}"
            ((TELEMETRY_STATS["files_processed"]++))
            ((TELEMETRY_STATS["ids_modified"] += ids_modified))
        else
            log_error "Failed to modify telemetry IDs: ${storage_file}"
            ((TELEMETRY_STATS["errors_encountered"]++))
            
            # Restore from backup if modification failed
            if [[ -n "${backup_file}" && -f "${backup_file}" ]]; then
                restore_storage_backup "${backup_file}" "${storage_file}"
            fi
            return 1
        fi
    fi
    
    local end_time=$(date +%s.%3N)
    log_performance "telemetry_modify" "${start_time}" "${end_time}" "${storage_file}"
    
    audit_log "TELEMETRY_MODIFY" "Telemetry IDs modified: ${storage_file}, ids_modified=${ids_modified}, backup=${backup_file}"
    
    return 0
}

# Validate storage file
validate_storage_file() {
    local storage_file="$1"
    
    log_debug "Validating storage file: ${storage_file}"
    
    # Check file existence and readability
    if [[ ! -f "${storage_file}" ]]; then
        log_error "Storage file does not exist: ${storage_file}"
        return 1
    fi
    
    if [[ ! -r "${storage_file}" ]]; then
        log_error "Storage file not readable: ${storage_file}"
        return 1
    fi
    
    # Check file size (reasonable limits)
    local file_size
    file_size=$(stat -f%z "${storage_file}" 2>/dev/null || stat -c%s "${storage_file}" 2>/dev/null)
    
    if [[ ${file_size} -eq 0 ]]; then
        log_error "Storage file is empty: ${storage_file}"
        return 1
    fi
    
    if [[ ${file_size} -gt 10485760 ]]; then  # 10MB limit
        log_error "Storage file too large (${file_size} > 10485760): ${storage_file}"
        return 1
    fi
    
    # Validate JSON format
    if ! jq empty "${storage_file}" 2>/dev/null; then
        log_error "Storage file is not valid JSON: ${storage_file}"
        return 1
    fi
    
    # Check if file appears to be VS Code storage
    if ! check_vscode_storage_structure "${storage_file}"; then
        log_warn "File does not appear to be VS Code storage: ${storage_file}"
        # Don't fail here, just warn
    fi
    
    log_debug "Storage file validation passed: ${storage_file}"
    return 0
}

# Check VS Code storage structure
check_vscode_storage_structure() {
    local storage_file="$1"
    
    # Check for common VS Code storage fields
    local expected_fields=("telemetry" "workbench")
    
    for field in "${expected_fields[@]}"; do
        if ! jq -e ".${field}" "${storage_file}" >/dev/null 2>&1; then
            log_debug "Expected field not found: ${field}"
            return 1
        fi
    done
    
    return 0
}

# Count existing telemetry fields
count_existing_telemetry_fields() {
    local storage_file="$1"
    local count=0
    
    for field in "${TELEMETRY_FIELDS[@]}"; do
        if jq -e ".\"${field}\"" "${storage_file}" >/dev/null 2>&1; then
            ((count++))
        fi
    done
    
    echo "${count}"
}

# Modify storage file with new IDs
modify_storage_file() {
    local storage_file="$1"
    local machine_id="$2"
    local device_id="$3"
    local sqm_id="$4"
    
    log_debug "Modifying storage file with new IDs"
    
    # Create temporary file for atomic operation
    local temp_file
    temp_file=$(mktemp) || {
        log_error "Failed to create temporary file"
        return 1
    }
    
    # Ensure cleanup of temp file
    trap "rm -f '${temp_file}'" EXIT
    
    # Modify JSON with new telemetry IDs
    if jq \
        --arg machine_id "${machine_id}" \
        --arg device_id "${device_id}" \
        --arg sqm_id "${sqm_id}" \
        '.
        | .["telemetry.machineId"] = $machine_id
        | .["telemetry.devDeviceId"] = $device_id
        | .["telemetry.sqmId"] = $sqm_id
        ' \
        "${storage_file}" > "${temp_file}"; then
        
        # Validate the modified JSON
        if jq empty "${temp_file}" 2>/dev/null; then
            # Atomically replace original file
            if mv "${temp_file}" "${storage_file}"; then
                log_debug "Storage file successfully modified"
                return 0
            else
                log_error "Failed to replace storage file"
                return 1
            fi
        else
            log_error "Modified JSON is invalid"
            return 1
        fi
    else
        log_error "Failed to modify JSON content"
        return 1
    fi
}

# Generate machine ID (64-character hex string)
generate_machine_id() {
    local machine_id=""
    
    # Try different methods to generate random hex
    if is_command_available openssl; then
        machine_id=$(openssl rand -hex 32 2>/dev/null || echo "")
    elif is_command_available xxd; then
        machine_id=$(head -c 32 /dev/urandom 2>/dev/null | xxd -p -c 32 | tr -d '\n' || echo "")
    elif [[ -r /dev/urandom ]]; then
        machine_id=$(head -c 32 /dev/urandom 2>/dev/null | od -An -tx1 | tr -d ' \n' || echo "")
    fi
    
    # Fallback method using RANDOM
    if [[ -z "${machine_id}" || ${#machine_id} -ne ${MACHINE_ID_LENGTH} ]]; then
        machine_id=""
        for ((i=0; i<${MACHINE_ID_LENGTH}; i++)); do
            machine_id="${machine_id}$(printf '%x' $((RANDOM % 16)))"
        done
    fi
    
    # Validate generated ID
    if [[ ${#machine_id} -eq ${MACHINE_ID_LENGTH} && "${machine_id}" =~ ${HEX_PATTERN} ]]; then
        echo "${machine_id}"
    else
        log_error "Failed to generate valid machine ID"
        return 1
    fi
}

# Generate UUID v4
generate_uuid_v4() {
    local uuid=""
    
    # Try different methods to generate UUID
    if is_command_available uuidgen; then
        uuid=$(uuidgen 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "")
    elif is_command_available python3; then
        uuid=$(python3 -c "import uuid; print(str(uuid.uuid4()))" 2>/dev/null || echo "")
    elif is_command_available python; then
        uuid=$(python -c "import uuid; print(str(uuid.uuid4()))" 2>/dev/null || echo "")
    fi
    
    # Fallback method using random data
    if [[ -z "${uuid}" || ! "${uuid}" =~ ${UUID_PATTERN} ]]; then
        # Generate UUID v4 manually
        local hex_chars="0123456789abcdef"
        uuid=""
        
        for i in {1..8}; do
            uuid="${uuid}${hex_chars:$((RANDOM % 16)):1}"
        done
        uuid="${uuid}-"
        
        for i in {1..4}; do
            uuid="${uuid}${hex_chars:$((RANDOM % 16)):1}"
        done
        uuid="${uuid}-4"  # Version 4
        
        for i in {1..3}; do
            uuid="${uuid}${hex_chars:$((RANDOM % 16)):1}"
        done
        uuid="${uuid}-"
        
        # Variant bits (10xx)
        uuid="${uuid}${hex_chars:$((8 + RANDOM % 4)):1}"
        for i in {1..3}; do
            uuid="${uuid}${hex_chars:$((RANDOM % 16)):1}"
        done
        uuid="${uuid}-"
        
        for i in {1..12}; do
            uuid="${uuid}${hex_chars:$((RANDOM % 16)):1}"
        done
    fi
    
    # Validate generated UUID
    if [[ "${uuid}" =~ ${UUID_PATTERN} ]]; then
        echo "${uuid}"
    else
        log_error "Failed to generate valid UUID"
        return 1
    fi
}

# Create storage backup
create_storage_backup() {
    local storage_file="$1"
    local timestamp=$(get_timestamp)
    local backup_file="${storage_file}.backup_${timestamp}"
    
    log_debug "Creating storage backup: ${storage_file} -> ${backup_file}"
    
    if cp "${storage_file}" "${backup_file}"; then
        log_success "Storage backup created: ${backup_file}"
        audit_log "STORAGE_BACKUP" "Backup created: ${storage_file} -> ${backup_file}"
        echo "${backup_file}"
        return 0
    else
        log_error "Failed to create storage backup: ${storage_file}"
        return 1
    fi
}

# Restore storage backup
restore_storage_backup() {
    local backup_file="$1"
    local target_file="$2"
    
    log_info "Restoring storage from backup: ${backup_file} -> ${target_file}"
    
    if [[ ! -f "${backup_file}" ]]; then
        log_error "Backup file does not exist: ${backup_file}"
        return 1
    fi
    
    # Validate backup file
    if ! validate_storage_file "${backup_file}"; then
        log_error "Backup file validation failed: ${backup_file}"
        return 1
    fi
    
    # Restore from backup
    if cp "${backup_file}" "${target_file}"; then
        log_success "Storage restored from backup: ${target_file}"
        audit_log "STORAGE_RESTORE" "Storage restored: ${backup_file} -> ${target_file}"
        return 0
    else
        log_error "Failed to restore storage from backup"
        return 1
    fi
}

# Analyze telemetry data
analyze_telemetry_data() {
    local storage_file="$1"
    
    log_info "Analyzing telemetry data in: ${storage_file}"
    
    if ! validate_storage_file "${storage_file}"; then
        log_error "Storage file validation failed for analysis: ${storage_file}"
        return 1
    fi
    
    # Analyze each telemetry field
    for field in "${TELEMETRY_FIELDS[@]}"; do
        local value
        value=$(jq -r ".\"${field}\" // \"not_found\"" "${storage_file}" 2>/dev/null)
        
        if [[ "${value}" != "not_found" && "${value}" != "null" ]]; then
            log_info "  ${field}: ${value}"
            
            # Validate field format
            case "${field}" in
                "telemetry.machineId")
                    if [[ ${#value} -eq ${MACHINE_ID_LENGTH} && "${value}" =~ ${HEX_PATTERN} ]]; then
                        log_debug "    Format: Valid machine ID"
                    else
                        log_warn "    Format: Invalid machine ID format"
                    fi
                    ;;
                "telemetry.devDeviceId"|"telemetry.sqmId")
                    if [[ "${value}" =~ ${UUID_PATTERN} ]]; then
                        log_debug "    Format: Valid UUID"
                    else
                        log_warn "    Format: Invalid UUID format"
                    fi
                    ;;
            esac
        else
            log_info "  ${field}: not present"
        fi
    done
}

# Generate telemetry report
generate_telemetry_report() {
    local report_file="${1:-logs/telemetry_report.txt}"
    
    log_info "Generating telemetry operations report: ${report_file}"
    
    {
        echo "=== Telemetry Operations Report ==="
        echo "Generated: $(date)"
        echo ""
        
        echo "Operation Statistics:"
        echo "  Files processed: ${TELEMETRY_STATS["files_processed"]}"
        echo "  IDs modified: ${TELEMETRY_STATS["ids_modified"]}"
        echo "  Backups created: ${TELEMETRY_STATS["backups_created"]}"
        echo "  Errors encountered: ${TELEMETRY_STATS["errors_encountered"]}"
        echo ""
        
        echo "Telemetry Fields:"
        for field in "${TELEMETRY_FIELDS[@]}"; do
            echo "  - ${field}"
        done
        echo ""
        
        echo "ID Formats:"
        echo "  Machine ID: ${MACHINE_ID_LENGTH}-character hexadecimal"
        echo "  Device ID: UUID v4 format"
        echo "  SQM ID: UUID v4 format"
        
    } > "${report_file}"
    
    log_success "Telemetry operations report generated: ${report_file}"
}

# Export telemetry functions
export -f init_telemetry modify_telemetry_ids validate_storage_file
export -f generate_machine_id generate_uuid_v4 analyze_telemetry_data
export -f generate_telemetry_report create_storage_backup restore_storage_backup
export TELEMETRY_FIELDS TELEMETRY_STATS

log_debug "Telemetry processing module loaded"
