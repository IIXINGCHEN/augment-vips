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
source "$(dirname "${BASH_SOURCE[0]}")/config_loader.sh"

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

    # Load unified configuration
    if ! load_augment_config; then
        log_error "Failed to load unified configuration"
        return 1
    fi

    # Verify telemetry field mappings are loaded
    if [[ -z "${MACHINE_ID_FIELD}" || -z "${DEVICE_ID_FIELD}" || -z "${SQM_ID_FIELD}" ]]; then
        log_error "Telemetry field mappings not properly loaded from configuration"
        return 1
    fi

    log_info "Loaded telemetry field mappings: machine=${MACHINE_ID_FIELD}, device=${DEVICE_ID_FIELD}, sqm=${SQM_ID_FIELD}"

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

    audit_log "TELEMETRY_INIT" "Telemetry processing module initialized with unified configuration"
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

# Verify file permissions and accessibility
verify_file_permissions() {
    local file_path="$1"
    local operation="${2:-write}"  # read, write, execute

    log_debug "Verifying file permissions for: ${file_path}"

    if [[ ! -f "${file_path}" ]]; then
        log_error "File does not exist: ${file_path}"
        return 1
    fi

    case "${operation}" in
        "read")
            if [[ ! -r "${file_path}" ]]; then
                log_error "File is not readable: ${file_path}"
                return 1
            fi
            ;;
        "write")
            if [[ ! -w "${file_path}" ]]; then
                log_error "File is not writable: ${file_path}"
                return 1
            fi
            ;;
        "execute")
            if [[ ! -x "${file_path}" ]]; then
                log_error "File is not executable: ${file_path}"
                return 1
            fi
            ;;
    esac

    # Check if file is locked by another process
    if command -v lsof >/dev/null 2>&1; then
        local lock_info
        lock_info=$(lsof "${file_path}" 2>/dev/null)
        if [[ -n "${lock_info}" ]]; then
            log_warn "File may be locked by another process: ${file_path}"
            log_debug "Lock info: ${lock_info}"
        fi
    fi

    log_debug "File permissions verified successfully"
    return 0
}

# Clear system cache for modified files
clear_system_cache() {
    local file_path="$1"

    log_debug "Clearing system cache for: ${file_path}"

    # Clear filesystem cache if possible
    if command -v sync >/dev/null 2>&1; then
        sync
        log_debug "Filesystem sync completed"
    fi

    # Clear page cache for the specific file (Linux)
    if [[ -f "/proc/sys/vm/drop_caches" ]] && [[ -w "/proc/sys/vm/drop_caches" ]]; then
        echo 1 > /proc/sys/vm/drop_caches 2>/dev/null || log_debug "Could not clear page cache"
    fi

    # Force file metadata refresh
    if command -v stat >/dev/null 2>&1; then
        stat "${file_path}" >/dev/null 2>&1
    fi

    log_debug "System cache clearing completed"
}

# Enhanced modify storage file with atomic operations and verification
modify_storage_file() {
    local storage_file="$1"
    local machine_id="$2"
    local device_id="$3"
    local sqm_id="$4"

    log_debug "Modifying storage file with new IDs: ${storage_file}"

    # Verify file permissions before modification
    if ! verify_file_permissions "${storage_file}" "write"; then
        log_error "Permission verification failed for: ${storage_file}"
        return 1
    fi

    # Create secure temporary file in same directory for atomic operation
    local storage_dir
    storage_dir=$(dirname "${storage_file}")
    local temp_file
    temp_file=$(mktemp "${storage_dir}/.tmp_telemetry_XXXXXX") || {
        log_error "Failed to create temporary file in: ${storage_dir}"
        return 1
    }

    # Ensure cleanup of temp file
    trap "rm -f '${temp_file}'" EXIT

    # Create backup before modification
    local backup_file
    backup_file=$(create_storage_backup "${storage_file}")
    if [[ $? -ne 0 ]]; then
        log_warn "Failed to create backup, proceeding with caution"
    fi

    # Modify JSON with new telemetry IDs using configuration-driven field mapping
    log_debug "Applying ID modifications using configured field mappings..."
    if jq \
        --arg machine_id "${machine_id}" \
        --arg device_id "${device_id}" \
        --arg sqm_id "${sqm_id}" \
        --arg machine_field "${MACHINE_ID_FIELD}" \
        --arg device_field "${DEVICE_ID_FIELD}" \
        --arg sqm_field "${SQM_ID_FIELD}" \
        --arg machine_alt_field "${MACHINE_ID_ALT_FIELD}" \
        --arg device_alt_field "${DEVICE_ID_ALT_FIELD}" \
        --arg sqm_alt_field "${SQM_ID_ALT_FIELD}" \
        '.
        | .[$machine_field] = $machine_id
        | .[$device_field] = $device_id
        | .[$sqm_field] = $sqm_id
        | .[$machine_alt_field] = $machine_id
        | .[$device_alt_field] = $device_id
        | .[$sqm_alt_field] = $sqm_id
        ' \
        "${storage_file}" > "${temp_file}"; then

        # Validate the modified JSON structure and content
        if jq empty "${temp_file}" 2>/dev/null; then
            # Verify the IDs were actually set correctly using configured field mappings
            local verify_machine_id verify_device_id verify_sqm_id
            verify_machine_id=$(jq -r --arg field "${MACHINE_ID_FIELD}" '.[$field] // "null"' "${temp_file}")
            verify_device_id=$(jq -r --arg field "${DEVICE_ID_FIELD}" '.[$field] // "null"' "${temp_file}")
            verify_sqm_id=$(jq -r --arg field "${SQM_ID_FIELD}" '.[$field] // "null"' "${temp_file}")

            if [[ "${verify_machine_id}" == "${machine_id}" ]] && \
               [[ "${verify_device_id}" == "${device_id}" ]] && \
               [[ "${verify_sqm_id}" == "${sqm_id}" ]]; then

                # Atomically replace original file using rename (atomic on most filesystems)
                if mv "${temp_file}" "${storage_file}"; then
                    log_success "Storage file successfully modified with new IDs"

                    # Clear system cache to ensure changes take effect
                    clear_system_cache "${storage_file}"

                    # Verify modification persistence
                    sleep 0.1  # Brief pause to ensure filesystem consistency
                    local final_machine_id
                    final_machine_id=$(jq -r '.["telemetry.machineId"] // .["machineId"] // "null"' "${storage_file}" 2>/dev/null)

                    if [[ "${final_machine_id}" == "${machine_id}" ]]; then
                        log_debug "ID modification verified successfully"
                        audit_log "TELEMETRY_MODIFY" "IDs modified in ${storage_file}: machine=${machine_id}, device=${device_id}, sqm=${sqm_id}"
                        return 0
                    else
                        log_error "ID modification verification failed"
                        # Restore from backup if verification fails
                        if [[ -n "${backup_file}" && -f "${backup_file}" ]]; then
                            restore_storage_backup "${backup_file}" "${storage_file}"
                        fi
                        return 1
                    fi
                else
                    log_error "Failed to replace storage file atomically"
                    return 1
                fi
            else
                log_error "ID verification failed after modification"
                log_debug "Expected: machine=${machine_id}, device=${device_id}, sqm=${sqm_id}"
                log_debug "Got: machine=${verify_machine_id}, device=${verify_device_id}, sqm=${verify_sqm_id}"
                return 1
            fi
        else
            log_error "Modified JSON is invalid or corrupted"
            return 1
        fi
    else
        log_error "Failed to modify JSON content with jq"
        return 1
    fi
}

# Enhanced machine ID generation with multiple entropy sources
generate_machine_id() {
    local machine_id=""
    local entropy_sources=0

    log_debug "Generating machine ID with enhanced entropy"

    # Method 1: OpenSSL (preferred for cryptographic strength)
    if is_command_available openssl; then
        machine_id=$(openssl rand -hex 32 2>/dev/null || echo "")
        if [[ ${#machine_id} -eq ${MACHINE_ID_LENGTH} ]]; then
            entropy_sources=$((entropy_sources + 1))
            log_debug "Machine ID generated using OpenSSL"
        else
            machine_id=""
        fi
    fi

    # Method 2: /dev/urandom with xxd
    if [[ -z "${machine_id}" ]] && is_command_available xxd && [[ -r /dev/urandom ]]; then
        machine_id=$(head -c 32 /dev/urandom 2>/dev/null | xxd -p -c 32 | tr -d '\n' || echo "")
        if [[ ${#machine_id} -eq ${MACHINE_ID_LENGTH} ]]; then
            entropy_sources=$((entropy_sources + 1))
            log_debug "Machine ID generated using /dev/urandom + xxd"
        else
            machine_id=""
        fi
    fi

    # Method 3: /dev/urandom with od
    if [[ -z "${machine_id}" ]] && [[ -r /dev/urandom ]]; then
        machine_id=$(head -c 32 /dev/urandom 2>/dev/null | od -An -tx1 | tr -d ' \n' || echo "")
        if [[ ${#machine_id} -eq ${MACHINE_ID_LENGTH} ]]; then
            entropy_sources=$((entropy_sources + 1))
            log_debug "Machine ID generated using /dev/urandom + od"
        else
            machine_id=""
        fi
    fi

    # Enhanced fallback method with multiple entropy sources
    if [[ -z "${machine_id}" || ${#machine_id} -ne ${MACHINE_ID_LENGTH} ]]; then
        log_debug "Using enhanced fallback method for machine ID generation"
        machine_id=""

        # Seed RANDOM with multiple sources for better entropy
        local seed_value=0
        seed_value=$((seed_value + $(date +%s%N 2>/dev/null || date +%s)))  # Nanosecond timestamp
        seed_value=$((seed_value + $$))  # Process ID
        seed_value=$((seed_value + $PPID))  # Parent process ID
        seed_value=$((seed_value + $(id -u 2>/dev/null || echo 1000)))  # User ID

        # Add system-specific entropy if available
        if [[ -r /proc/uptime ]]; then
            local uptime_entropy
            uptime_entropy=$(awk '{print int($1*1000000)}' /proc/uptime 2>/dev/null || echo 0)
            seed_value=$((seed_value + uptime_entropy))
        fi

        if [[ -r /proc/loadavg ]]; then
            local load_entropy
            load_entropy=$(awk '{print int($1*1000)}' /proc/loadavg 2>/dev/null || echo 0)
            seed_value=$((seed_value + load_entropy))
        fi

        # Set enhanced seed
        RANDOM=${seed_value}

        # Generate ID with additional mixing
        for ((i=0; i<${MACHINE_ID_LENGTH}; i++)); do
            # Mix multiple random sources
            local rand1=$((RANDOM % 16))
            local rand2=$((RANDOM % 16))
            local rand3=$((($(date +%N 2>/dev/null || echo 0) + i) % 16))
            local final_rand=$(((rand1 + rand2 + rand3) % 16))
            machine_id="${machine_id}$(printf '%x' ${final_rand})"
        done

        entropy_sources=$((entropy_sources + 1))
        log_debug "Machine ID generated using enhanced fallback method"
    fi

    # Validate generated ID
    if [[ ${#machine_id} -eq ${MACHINE_ID_LENGTH} && "${machine_id}" =~ ${HEX_PATTERN} ]]; then
        # Additional uniqueness check - ensure it's not all zeros or all same character
        if [[ "${machine_id}" =~ ^0+$ ]] || [[ "${machine_id}" =~ ^(.)\1*$ ]]; then
            log_warn "Generated machine ID has low entropy, regenerating..."
            # Recursive call with different seed (limited to prevent infinite recursion)
            if [[ "${FUNCNAME[1]}" != "${FUNCNAME[0]}" ]]; then
                sleep 0.001  # Brief delay to change timestamp
                generate_machine_id
                return $?
            fi
        fi

        log_debug "Machine ID generated successfully with ${entropy_sources} entropy source(s)"
        echo "${machine_id}"
        return 0
    else
        log_error "Failed to generate valid machine ID (length: ${#machine_id}, pattern match: $(echo "${machine_id}" | grep -E "${HEX_PATTERN}" >/dev/null && echo "yes" || echo "no"))"
        return 1
    fi
}

# Enhanced UUID v4 generation with improved entropy and validation
generate_uuid_v4() {
    local uuid=""
    local generation_method=""

    log_debug "Generating UUID v4 with enhanced entropy"

    # Method 1: System uuidgen (preferred)
    if is_command_available uuidgen; then
        uuid=$(uuidgen 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "")
        if [[ "${uuid}" =~ ${UUID_PATTERN} ]]; then
            generation_method="uuidgen"
            log_debug "UUID generated using system uuidgen"
        else
            uuid=""
        fi
    fi

    # Method 2: Python3 uuid module
    if [[ -z "${uuid}" ]] && is_command_available python3; then
        uuid=$(python3 -c "import uuid; print(str(uuid.uuid4()))" 2>/dev/null || echo "")
        if [[ "${uuid}" =~ ${UUID_PATTERN} ]]; then
            generation_method="python3"
            log_debug "UUID generated using Python3"
        else
            uuid=""
        fi
    fi

    # Method 3: Python2 uuid module
    if [[ -z "${uuid}" ]] && is_command_available python; then
        uuid=$(python -c "import uuid; print(str(uuid.uuid4()))" 2>/dev/null || echo "")
        if [[ "${uuid}" =~ ${UUID_PATTERN} ]]; then
            generation_method="python2"
            log_debug "UUID generated using Python2"
        else
            uuid=""
        fi
    fi

    # Enhanced fallback method with proper UUID v4 structure
    if [[ -z "${uuid}" || ! "${uuid}" =~ ${UUID_PATTERN} ]]; then
        log_debug "Using enhanced fallback method for UUID generation"
        generation_method="fallback"

        # Enhanced entropy seeding
        local seed_base=$(($(date +%s%N 2>/dev/null || date +%s) + $$ + $PPID))
        RANDOM=${seed_base}

        # Generate UUID v4 with proper structure: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
        local hex_chars="0123456789abcdef"
        uuid=""

        # First group: 8 hex digits
        for i in {1..8}; do
            local rand_val=$((RANDOM % 16))
            uuid="${uuid}${hex_chars:${rand_val}:1}"
        done
        uuid="${uuid}-"

        # Second group: 4 hex digits
        for i in {1..4}; do
            local rand_val=$((RANDOM % 16))
            uuid="${uuid}${hex_chars:${rand_val}:1}"
        done
        uuid="${uuid}-"

        # Third group: 4xxx (version 4)
        uuid="${uuid}4"  # Version 4 identifier
        for i in {1..3}; do
            local rand_val=$((RANDOM % 16))
            uuid="${uuid}${hex_chars:${rand_val}:1}"
        done
        uuid="${uuid}-"

        # Fourth group: yxxx (variant bits)
        # First digit must be 8, 9, a, or b (binary 10xx)
        local variant_chars="89ab"
        local variant_idx=$((RANDOM % 4))
        uuid="${uuid}${variant_chars:${variant_idx}:1}"
        for i in {1..3}; do
            local rand_val=$((RANDOM % 16))
            uuid="${uuid}${hex_chars:${rand_val}:1}"
        done
        uuid="${uuid}-"

        # Fifth group: 12 hex digits
        for i in {1..12}; do
            local rand_val=$((RANDOM % 16))
            uuid="${uuid}${hex_chars:${rand_val}:1}"
        done
    fi

    # Validate generated UUID structure and format
    if [[ "${uuid}" =~ ${UUID_PATTERN} ]]; then
        # Additional validation for UUID v4 specific requirements
        local version_char="${uuid:14:1}"
        local variant_char="${uuid:19:1}"

        if [[ "${version_char}" == "4" ]] && [[ "${variant_char}" =~ [89ab] ]]; then
            # Check for low-entropy patterns
            if [[ "${uuid}" == "00000000-0000-4000-8000-000000000000" ]] || \
               [[ "${uuid}" =~ ^(.)\1*-\1*-4\1*-[89ab]\1*-\1*$ ]]; then
                log_warn "Generated UUID has low entropy, regenerating..."
                # Recursive call with different seed (limited to prevent infinite recursion)
                if [[ "${FUNCNAME[1]}" != "${FUNCNAME[0]}" ]]; then
                    sleep 0.001  # Brief delay to change timestamp
                    generate_uuid_v4
                    return $?
                fi
            fi

            log_debug "UUID v4 generated successfully using ${generation_method}"
            echo "${uuid}"
            return 0
        else
            log_error "Generated UUID does not meet v4 requirements (version: ${version_char}, variant: ${variant_char})"
            return 1
        fi
    else
        log_error "Failed to generate valid UUID format"
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
