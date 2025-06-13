#!/bin/bash
# backup.sh
#
# Auto-fixed for readonly variable conflicts

# Prevent multiple loading
if [[ "${BACKUP_SH_LOADED:-}" == "true" ]]; then
    return 0
fi
if [[ -z "${BACKUP_SH_LOADED:-}" ]]; then
    readonly BACKUP_SH_LOADED="true"
fi

# core/backup.sh
#
# Enterprise-grade backup and recovery module
# Production-ready with comprehensive backup strategies
# Zero-redundancy backup management with integrity verification

set -euo pipefail

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/security.sh"
source "$(dirname "${BASH_SOURCE[0]}")/validation.sh"

# Backup constants
if [[ -z "${BACKUP_DIR_DEFAULT:-}" ]]; then
    readonly BACKUP_DIR_DEFAULT="backups"
fi
if [[ -z "${BACKUP_RETENTION_DAYS:-}" ]]; then
    readonly BACKUP_RETENTION_DAYS=30
fi
if [[ -z "${MAX_BACKUP_SIZE:-}" ]]; then
    readonly MAX_BACKUP_SIZE=1073741824  # 1GB
fi
if [[ -z "${BACKUP_COMPRESSION:-}" ]]; then
    readonly BACKUP_COMPRESSION=true
fi
if [[ -z "${BACKUP_VERIFICATION:-}" ]]; then
    readonly BACKUP_VERIFICATION=true
fi

# Backup file patterns
if [[ -z "${BACKUP_SUFFIX:-}" ]]; then
    readonly BACKUP_SUFFIX=".backup"
fi
if [[ -z "${BACKUP_TIMESTAMP_FORMAT:-}" ]]; then
    readonly BACKUP_TIMESTAMP_FORMAT="%Y%m%d_%H%M%S"
fi
if [[ -z "${BACKUP_MANIFEST_FILE:-}" ]]; then
    readonly BACKUP_MANIFEST_FILE="backup_manifest.json"
fi

# Global backup variables
BACKUP_BASE_DIR=""
declare -A BACKUP_REGISTRY=()
declare -A BACKUP_STATS=()

# Initialize backup module
init_backup() {
    local backup_dir="${1:-${BACKUP_DIR_DEFAULT}}"
    
    log_info "Initializing backup and recovery module..."
    
    # Set backup directory
    BACKUP_BASE_DIR="$(realpath "${backup_dir}")"
    
    # Create backup directory structure
    if ! create_backup_directory_structure; then
        log_error "Failed to create backup directory structure"
        return 1
    fi
    
    # Initialize backup registry
    load_backup_registry
    
    # Initialize statistics
    BACKUP_STATS["backups_created"]=0
    BACKUP_STATS["backups_restored"]=0
    BACKUP_STATS["backups_verified"]=0
    BACKUP_STATS["backups_cleaned"]=0
    BACKUP_STATS["errors_encountered"]=0
    
    audit_log "BACKUP_INIT" "Backup module initialized: ${BACKUP_BASE_DIR}"
    log_success "Backup module initialized: ${BACKUP_BASE_DIR}"
}

# Create backup directory structure
create_backup_directory_structure() {
    log_debug "Creating backup directory structure..."
    
    # Create main backup directory
    if ! mkdir -p "${BACKUP_BASE_DIR}"; then
        log_error "Failed to create backup directory: ${BACKUP_BASE_DIR}"
        return 1
    fi
    
    # Create subdirectories
    local subdirs=("databases" "storage" "logs" "manifests")
    
    for subdir in "${subdirs[@]}"; do
        local full_path="${BACKUP_BASE_DIR}/${subdir}"
        if ! mkdir -p "${full_path}"; then
            log_error "Failed to create backup subdirectory: ${full_path}"
            return 1
        fi
    done
    
    # Set appropriate permissions
    chmod 750 "${BACKUP_BASE_DIR}"
    
    log_debug "Backup directory structure created successfully"
    return 0
}

# Load backup registry
load_backup_registry() {
    local registry_file="${BACKUP_BASE_DIR}/manifests/${BACKUP_MANIFEST_FILE}"
    
    log_debug "Loading backup registry from: ${registry_file}"
    
    if [[ -f "${registry_file}" ]]; then
        if is_command_available jq && jq empty "${registry_file}" 2>/dev/null; then
            # Load existing registry
            while IFS= read -r entry; do
                local backup_id
                backup_id=$(echo "${entry}" | jq -r '.backup_id')
                BACKUP_REGISTRY["${backup_id}"]="${entry}"
            done < <(jq -c '.backups[]?' "${registry_file}" 2>/dev/null || echo "")
            
            log_debug "Loaded ${#BACKUP_REGISTRY[@]} backup entries from registry"
        else
            log_warn "Invalid backup registry file, starting fresh"
        fi
    else
        log_debug "No existing backup registry found, starting fresh"
    fi
}

# Save backup registry
save_backup_registry() {
    local registry_file="${BACKUP_BASE_DIR}/manifests/${BACKUP_MANIFEST_FILE}"
    
    log_debug "Saving backup registry to: ${registry_file}"
    
    if ! is_command_available jq; then
        log_warn "jq not available, cannot save backup registry"
        return 0
    fi
    
    # Create registry JSON
    local registry_json='{"version": "1.0", "created": "'$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')'", "backups": []}'
    
    # Add backup entries
    for backup_id in "${!BACKUP_REGISTRY[@]}"; do
        registry_json=$(echo "${registry_json}" | jq --argjson entry "${BACKUP_REGISTRY["${backup_id}"]}" '.backups += [$entry]')
    done
    
    # Write to file atomically
    local temp_file
    temp_file=$(mktemp) || {
        log_error "Failed to create temporary file for registry"
        return 1
    }
    
    if echo "${registry_json}" | jq '.' > "${temp_file}" && mv "${temp_file}" "${registry_file}"; then
        log_debug "Backup registry saved successfully"
        return 0
    else
        log_error "Failed to save backup registry"
        rm -f "${temp_file}"
        return 1
    fi
}

# Create backup
create_backup() {
    local source_file="$1"
    local backup_type="${2:-auto}"
    local description="${3:-Automatic backup}"
    
    log_info "Creating backup for: ${source_file}"
    
    # Validate source file
    if ! validate_file_access "${source_file}" "read"; then
        log_error "Source file validation failed: ${source_file}"
        return 1
    fi
    
    # Authorize backup operation
    if ! authorize_operation "backup_create" "${source_file}"; then
        log_error "Backup creation not authorized"
        return 1
    fi
    
    # Generate backup metadata
    local backup_id
    backup_id=$(generate_backup_id "${source_file}")
    
    local timestamp
    timestamp=$(date +"${BACKUP_TIMESTAMP_FORMAT}")
    
    local backup_filename
    backup_filename="$(basename "${source_file}")${BACKUP_SUFFIX}_${timestamp}"
    
    # Determine backup subdirectory based on file type
    local backup_subdir
    case "${source_file}" in
        *.vscdb)
            backup_subdir="databases"
            ;;
        *.json)
            backup_subdir="storage"
            ;;
        *)
            backup_subdir="logs"
            ;;
    esac
    
    local backup_path="${BACKUP_BASE_DIR}/${backup_subdir}/${backup_filename}"
    
    # Check backup size limits
    local source_size
    source_size=$(stat -f%z "${source_file}" 2>/dev/null || stat -c%s "${source_file}" 2>/dev/null)
    
    if [[ ${source_size} -gt ${MAX_BACKUP_SIZE} ]]; then
        log_error "Source file too large for backup (${source_size} > ${MAX_BACKUP_SIZE}): ${source_file}"
        return 1
    fi
    
    # Perform backup
    local start_time=$(date +%s.%3N)
    
    if perform_file_backup "${source_file}" "${backup_path}"; then
        # Verify backup if enabled
        if [[ "${BACKUP_VERIFICATION}" == "true" ]]; then
            if ! verify_backup_integrity "${source_file}" "${backup_path}"; then
                log_error "Backup verification failed, removing invalid backup"
                rm -f "${backup_path}"
                return 1
            fi
            ((BACKUP_STATS["backups_verified"]++))
        fi
        
        # Register backup
        register_backup "${backup_id}" "${source_file}" "${backup_path}" "${backup_type}" "${description}"
        
        # Update statistics
        ((BACKUP_STATS["backups_created"]++))
        
        local end_time=$(date +%s.%3N)
        log_performance "backup_create" "${start_time}" "${end_time}" "${source_file}"
        
        audit_log "BACKUP_CREATE" "Backup created: ${source_file} -> ${backup_path} (ID: ${backup_id})"
        log_success "Backup created successfully: ${backup_path}"
        
        echo "${backup_path}"
        return 0
    else
        log_error "Backup creation failed: ${source_file}"
        ((BACKUP_STATS["errors_encountered"]++))
        return 1
    fi
}

# Perform file backup
perform_file_backup() {
    local source_file="$1"
    local backup_path="$2"
    
    log_debug "Performing file backup: ${source_file} -> ${backup_path}"
    
    # Create backup directory if needed
    local backup_dir
    backup_dir=$(dirname "${backup_path}")
    mkdir -p "${backup_dir}"
    
    # Copy file with preservation of metadata
    if cp -p "${source_file}" "${backup_path}"; then
        # Compress backup if enabled
        if [[ "${BACKUP_COMPRESSION}" == "true" ]] && is_command_available gzip; then
            if gzip "${backup_path}"; then
                backup_path="${backup_path}.gz"
                log_debug "Backup compressed: ${backup_path}"
            else
                log_warn "Backup compression failed, keeping uncompressed"
            fi
        fi
        
        # Set secure permissions
        chmod 640 "${backup_path}"
        
        return 0
    else
        log_error "File copy failed during backup"
        return 1
    fi
}

# Generate backup ID
generate_backup_id() {
    local source_file="$1"
    local timestamp=$(date +%s)
    local file_hash
    
    # Generate hash of source file path and timestamp
    if is_command_available sha256sum; then
        file_hash=$(echo "${source_file}_${timestamp}" | sha256sum | cut -d' ' -f1)
    elif is_command_available shasum; then
        file_hash=$(echo "${source_file}_${timestamp}" | shasum -a 256 | cut -d' ' -f1)
    else
        # Fallback to simple hash
        file_hash=$(echo "${source_file}_${timestamp}" | od -An -tx1 | tr -d ' \n')
    fi
    
    echo "${file_hash:0:16}"  # Use first 16 characters
}

# Register backup in registry
register_backup() {
    local backup_id="$1"
    local source_file="$2"
    local backup_path="$3"
    local backup_type="$4"
    local description="$5"
    
    log_debug "Registering backup: ${backup_id}"
    
    # Create backup entry
    local backup_entry
    backup_entry=$(jq -n \
        --arg backup_id "${backup_id}" \
        --arg source_file "${source_file}" \
        --arg backup_path "${backup_path}" \
        --arg backup_type "${backup_type}" \
        --arg description "${description}" \
        --arg created "$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')" \
        --arg size "$(stat -f%z "${backup_path}" 2>/dev/null || stat -c%s "${backup_path}" 2>/dev/null)" \
        '{
            backup_id: $backup_id,
            source_file: $source_file,
            backup_path: $backup_path,
            backup_type: $backup_type,
            description: $description,
            created: $created,
            size: ($size | tonumber)
        }')
    
    # Add to registry
    BACKUP_REGISTRY["${backup_id}"]="${backup_entry}"
    
    # Save registry
    save_backup_registry
    
    log_debug "Backup registered successfully: ${backup_id}"
}

# Verify backup integrity
verify_backup_integrity() {
    local source_file="$1"
    local backup_path="$2"
    
    log_debug "Verifying backup integrity: ${backup_path}"
    
    # Handle compressed backups
    local actual_backup_path="${backup_path}"
    if [[ "${backup_path}" == *.gz ]]; then
        actual_backup_path="${backup_path}"
    elif [[ -f "${backup_path}.gz" ]]; then
        actual_backup_path="${backup_path}.gz"
    fi
    
    # Check if backup file exists
    if [[ ! -f "${actual_backup_path}" ]]; then
        log_error "Backup file does not exist: ${actual_backup_path}"
        return 1
    fi
    
    # Compare file sizes (for compressed files, this is approximate)
    local source_size
    source_size=$(stat -f%z "${source_file}" 2>/dev/null || stat -c%s "${source_file}" 2>/dev/null)
    
    local backup_size
    backup_size=$(stat -f%z "${actual_backup_path}" 2>/dev/null || stat -c%s "${actual_backup_path}" 2>/dev/null)
    
    # For compressed files, backup should be smaller
    if [[ "${actual_backup_path}" == *.gz ]]; then
        if [[ ${backup_size} -ge ${source_size} ]]; then
            log_warn "Compressed backup is not smaller than source (possible compression issue)"
        fi
    else
        # For uncompressed files, sizes should match
        if [[ ${backup_size} -ne ${source_size} ]]; then
            log_error "Backup size mismatch: source=${source_size}, backup=${backup_size}"
            return 1
        fi
    fi
    
    # Additional integrity checks based on file type
    case "${source_file}" in
        *.vscdb)
            verify_database_backup_integrity "${source_file}" "${actual_backup_path}"
            ;;
        *.json)
            verify_json_backup_integrity "${source_file}" "${actual_backup_path}"
            ;;
        *)
            # Generic file verification passed
            ;;
    esac
    
    log_debug "Backup integrity verification passed"
    return 0
}

# Verify database backup integrity
verify_database_backup_integrity() {
    local source_file="$1"
    local backup_path="$2"
    
    # For compressed backups, we can't easily verify SQLite integrity
    if [[ "${backup_path}" == *.gz ]]; then
        log_debug "Skipping SQLite integrity check for compressed backup"
        return 0
    fi
    
    # Check SQLite integrity
    if is_command_available sqlite3; then
        if ! sqlite3 "${backup_path}" "PRAGMA integrity_check;" >/dev/null 2>&1; then
            log_error "SQLite integrity check failed for backup: ${backup_path}"
            return 1
        fi
    fi
    
    return 0
}

# Verify JSON backup integrity
verify_json_backup_integrity() {
    local source_file="$1"
    local backup_path="$2"
    
    # For compressed backups, decompress temporarily for verification
    local temp_file=""
    local file_to_check="${backup_path}"
    
    if [[ "${backup_path}" == *.gz ]]; then
        temp_file=$(mktemp)
        if ! gunzip -c "${backup_path}" > "${temp_file}"; then
            log_error "Failed to decompress backup for verification"
            rm -f "${temp_file}"
            return 1
        fi
        file_to_check="${temp_file}"
    fi
    
    # Verify JSON format
    local verification_result=0
    if is_command_available jq; then
        if ! jq empty "${file_to_check}" 2>/dev/null; then
            log_error "JSON format verification failed for backup"
            verification_result=1
        fi
    fi
    
    # Cleanup temporary file
    if [[ -n "${temp_file}" ]]; then
        rm -f "${temp_file}"
    fi
    
    return ${verification_result}
}

# Restore backup
restore_backup() {
    local backup_id="$1"
    local target_file="${2:-}"
    
    log_info "Restoring backup: ${backup_id}"
    
    # Find backup in registry
    if [[ -z "${BACKUP_REGISTRY["${backup_id}"]:-}" ]]; then
        log_error "Backup not found in registry: ${backup_id}"
        return 1
    fi
    
    # Extract backup information
    local backup_info="${BACKUP_REGISTRY["${backup_id}"]}"
    local backup_path
    local source_file
    
    backup_path=$(echo "${backup_info}" | jq -r '.backup_path')
    source_file=$(echo "${backup_info}" | jq -r '.source_file')
    
    # Use original source file as target if not specified
    if [[ -z "${target_file}" ]]; then
        target_file="${source_file}"
    fi
    
    # Authorize restore operation
    if ! authorize_operation "backup_restore" "${target_file}"; then
        log_error "Backup restore not authorized"
        return 1
    fi
    
    # Perform restore
    local start_time=$(date +%s.%3N)
    
    if perform_file_restore "${backup_path}" "${target_file}"; then
        ((BACKUP_STATS["backups_restored"]++))
        
        local end_time=$(date +%s.%3N)
        log_performance "backup_restore" "${start_time}" "${end_time}" "${target_file}"
        
        audit_log "BACKUP_RESTORE" "Backup restored: ${backup_id} -> ${target_file}"
        log_success "Backup restored successfully: ${target_file}"
        return 0
    else
        log_error "Backup restore failed: ${backup_id}"
        ((BACKUP_STATS["errors_encountered"]++))
        return 1
    fi
}

# Perform file restore
perform_file_restore() {
    local backup_path="$1"
    local target_file="$2"
    
    log_debug "Performing file restore: ${backup_path} -> ${target_file}"
    
    # Check if backup exists
    local actual_backup_path="${backup_path}"
    if [[ ! -f "${backup_path}" && -f "${backup_path}.gz" ]]; then
        actual_backup_path="${backup_path}.gz"
    fi
    
    if [[ ! -f "${actual_backup_path}" ]]; then
        log_error "Backup file does not exist: ${actual_backup_path}"
        return 1
    fi
    
    # Create target directory if needed
    local target_dir
    target_dir=$(dirname "${target_file}")
    mkdir -p "${target_dir}"
    
    # Restore file
    if [[ "${actual_backup_path}" == *.gz ]]; then
        # Decompress and restore
        if gunzip -c "${actual_backup_path}" > "${target_file}"; then
            log_debug "Compressed backup restored successfully"
            return 0
        else
            log_error "Failed to restore compressed backup"
            return 1
        fi
    else
        # Direct copy
        if cp "${actual_backup_path}" "${target_file}"; then
            log_debug "Backup restored successfully"
            return 0
        else
            log_error "Failed to restore backup"
            return 1
        fi
    fi
}

# List backups
list_backups() {
    local filter_type="${1:-all}"
    
    log_info "Listing backups (filter: ${filter_type})"
    
    if [[ ${#BACKUP_REGISTRY[@]} -eq 0 ]]; then
        log_info "No backups found in registry"
        return 0
    fi
    
    # Display header
    printf "%-16s %-12s %-20s %-50s\n" "Backup ID" "Type" "Created" "Source File"
    printf "%-16s %-12s %-20s %-50s\n" "--------" "----" "-------" "-----------"
    
    # List backups
    for backup_id in "${!BACKUP_REGISTRY[@]}"; do
        local backup_info="${BACKUP_REGISTRY["${backup_id}"]}"
        local backup_type
        local created
        local source_file
        
        backup_type=$(echo "${backup_info}" | jq -r '.backup_type')
        created=$(echo "${backup_info}" | jq -r '.created')
        source_file=$(echo "${backup_info}" | jq -r '.source_file')
        
        # Apply filter
        if [[ "${filter_type}" != "all" && "${backup_type}" != "${filter_type}" ]]; then
            continue
        fi
        
        printf "%-16s %-12s %-20s %-50s\n" "${backup_id}" "${backup_type}" "${created}" "${source_file}"
    done
}

# Clean old backups
cleanup_old_backups() {
    local retention_days="${1:-${BACKUP_RETENTION_DAYS}}"
    
    log_info "Cleaning up backups older than ${retention_days} days"
    
    local cutoff_date
    cutoff_date=$(date -d "${retention_days} days ago" '+%Y-%m-%d' 2>/dev/null || date -v-"${retention_days}d" '+%Y-%m-%d' 2>/dev/null)
    
    local cleaned_count=0
    
    for backup_id in "${!BACKUP_REGISTRY[@]}"; do
        local backup_info="${BACKUP_REGISTRY["${backup_id}"]}"
        local created
        local backup_path
        
        created=$(echo "${backup_info}" | jq -r '.created' | cut -d'T' -f1)
        backup_path=$(echo "${backup_info}" | jq -r '.backup_path')
        
        if [[ "${created}" < "${cutoff_date}" ]]; then
            # Remove backup file
            if [[ -f "${backup_path}" ]]; then
                rm -f "${backup_path}"
            fi
            if [[ -f "${backup_path}.gz" ]]; then
                rm -f "${backup_path}.gz"
            fi
            
            # Remove from registry
            unset BACKUP_REGISTRY["${backup_id}"]
            ((cleaned_count++))
            
            log_debug "Removed old backup: ${backup_id}"
        fi
    done
    
    # Save updated registry
    save_backup_registry
    
    ((BACKUP_STATS["backups_cleaned"] += cleaned_count))
    
    audit_log "BACKUP_CLEANUP" "Cleaned up ${cleaned_count} old backups"
    log_success "Cleaned up ${cleaned_count} old backups"
}

# Generate backup report
generate_backup_report() {
    local report_file="${1:-logs/backup_report.txt}"
    
    log_info "Generating backup report: ${report_file}"
    
    {
        echo "=== Backup Operations Report ==="
        echo "Generated: $(date)"
        echo "Backup Directory: ${BACKUP_BASE_DIR}"
        echo ""
        
        echo "Operation Statistics:"
        echo "  Backups created: ${BACKUP_STATS["backups_created"]}"
        echo "  Backups restored: ${BACKUP_STATS["backups_restored"]}"
        echo "  Backups verified: ${BACKUP_STATS["backups_verified"]}"
        echo "  Backups cleaned: ${BACKUP_STATS["backups_cleaned"]}"
        echo "  Errors encountered: ${BACKUP_STATS["errors_encountered"]}"
        echo ""
        
        echo "Current Backups: ${#BACKUP_REGISTRY[@]}"
        if [[ ${#BACKUP_REGISTRY[@]} -gt 0 ]]; then
            echo ""
            list_backups
        fi
        echo ""
        
        echo "Configuration:"
        echo "  Retention period: ${BACKUP_RETENTION_DAYS} days"
        echo "  Maximum backup size: ${MAX_BACKUP_SIZE} bytes"
        echo "  Compression enabled: ${BACKUP_COMPRESSION}"
        echo "  Verification enabled: ${BACKUP_VERIFICATION}"
        
    } > "${report_file}"
    
    log_success "Backup report generated: ${report_file}"
}

# Create selective database backup based on SQL query
create_selective_backup() {
    local db_file="$1"
    local sql_query="$2"
    local backup_type="${3:-selective}"
    local description="${4:-Selective data backup}"

    log_info "创建选择性备份: ${db_file}"

    # Validate database file
    if ! validate_file_access "${db_file}" "read"; then
        log_error "数据库文件验证失败: ${db_file}"
        return 1
    fi

    # Authorize backup operation
    if ! authorize_operation "backup_create" "${db_file}"; then
        log_error "选择性备份操作未授权"
        return 1
    fi

    # Generate backup ID and paths
    local backup_id
    backup_id=$(generate_backup_id "${db_file}")
    local timestamp=$(get_timestamp)
    local backup_filename="selective_backup_${backup_id}_${timestamp}.json"
    local backup_path="${BACKUP_BASE_DIR}/selective/${backup_filename}"

    # Create backup directory
    mkdir -p "$(dirname "${backup_path}")"

    # Execute selective backup
    local start_time=$(date +%s.%3N)

    if perform_selective_backup "${db_file}" "${sql_query}" "${backup_path}"; then
        # Register backup
        register_selective_backup "${backup_id}" "${db_file}" "${backup_path}" "${backup_type}" "${description}"

        local end_time=$(date +%s.%3N)
        log_performance "selective_backup" "${start_time}" "${end_time}" "${db_file}"

        ((BACKUP_STATS["backups_created"]++))
        audit_log "SELECTIVE_BACKUP" "选择性备份已创建: ${db_file} -> ${backup_path}"
        log_success "选择性备份创建成功: ${backup_path}"
        echo "${backup_path}"
        return 0
    else
        log_error "选择性备份创建失败: ${db_file}"
        ((BACKUP_STATS["errors_encountered"]++))
        return 1
    fi
}

# Perform selective backup operation
perform_selective_backup() {
    local db_file="$1"
    local sql_query="$2"
    local backup_path="$3"

    log_debug "执行选择性备份操作"

    # Validate SQL query for safety
    if ! validate_sql_query "${sql_query}"; then
        log_error "SQL查询验证失败"
        return 1
    fi

    # Execute query and export as JSON
    local backup_data
    backup_data=$(sqlite3 "${db_file}" "${sql_query}" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        log_error "SQL查询执行失败"
        return 1
    fi

    # Create backup metadata
    local backup_metadata
    backup_metadata=$(jq -n \
        --arg timestamp "$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')" \
        --arg source_file "${db_file}" \
        --arg sql_query "${sql_query}" \
        --arg record_count "$(echo "${backup_data}" | wc -l)" \
        '{
            metadata: {
                timestamp: $timestamp,
                source_file: $source_file,
                sql_query: $sql_query,
                record_count: ($record_count | tonumber),
                backup_type: "selective"
            },
            data: []
        }')

    # Process backup data into JSON array
    local json_data="[]"
    if [[ -n "${backup_data}" ]]; then
        while IFS= read -r line; do
            if [[ -n "${line}" ]]; then
                # Assume line is already JSON or convert it
                json_data=$(echo "${json_data}" | jq --argjson item "${line}" '. += [$item]')
            fi
        done <<< "${backup_data}"
    fi

    # Combine metadata and data
    local final_backup
    final_backup=$(echo "${backup_metadata}" | jq --argjson data "${json_data}" '.data = $data')

    # Write to backup file
    if echo "${final_backup}" | jq '.' > "${backup_path}"; then
        log_debug "选择性备份数据写入成功"
        return 0
    else
        log_error "选择性备份数据写入失败"
        return 1
    fi
}

# Validate SQL query for safety
validate_sql_query() {
    local sql_query="$1"

    # Convert to lowercase for checking
    local lower_query=$(echo "${sql_query}" | tr '[:upper:]' '[:lower:]')

    # Check for dangerous operations
    if [[ "${lower_query}" =~ (drop|delete|update|insert|alter|create|truncate) ]]; then
        log_error "SQL查询包含危险操作: ${sql_query}"
        return 1
    fi

    # Must be a SELECT query
    if [[ ! "${lower_query}" =~ ^[[:space:]]*select ]]; then
        log_error "只允许SELECT查询: ${sql_query}"
        return 1
    fi

    return 0
}

# Register selective backup
register_selective_backup() {
    local backup_id="$1"
    local source_file="$2"
    local backup_path="$3"
    local backup_type="$4"
    local description="$5"

    # Create backup entry
    local backup_entry
    backup_entry=$(jq -n \
        --arg backup_id "${backup_id}" \
        --arg source_file "${source_file}" \
        --arg backup_path "${backup_path}" \
        --arg backup_type "${backup_type}" \
        --arg description "${description}" \
        --arg created "$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')" \
        --arg size "$(stat -f%z "${backup_path}" 2>/dev/null || stat -c%s "${backup_path}" 2>/dev/null)" \
        '{
            backup_id: $backup_id,
            source_file: $source_file,
            backup_path: $backup_path,
            backup_type: $backup_type,
            description: $description,
            created: $created,
            size: ($size | tonumber),
            selective: true
        }')

    # Add to registry
    BACKUP_REGISTRY["${backup_id}"]="${backup_entry}"

    # Save registry
    save_backup_registry

    log_debug "选择性备份已注册: ${backup_id}"
}

# Restore selective backup
restore_selective_backup() {
    local backup_path="$1"
    local target_db="$2"
    local restore_mode="${3:-insert}"  # insert, replace, or merge

    log_info "恢复选择性备份: ${backup_path} -> ${target_db}"

    # Validate backup file
    if [[ ! -f "${backup_path}" ]]; then
        log_error "备份文件不存在: ${backup_path}"
        return 1
    fi

    # Authorize restore operation
    if ! authorize_operation "backup_restore" "${target_db}"; then
        log_error "选择性恢复操作未授权"
        return 1
    fi

    # Parse backup file
    local backup_data
    backup_data=$(jq '.data[]' "${backup_path}" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        log_error "备份文件格式无效: ${backup_path}"
        return 1
    fi

    # Restore data based on mode
    case "${restore_mode}" in
        "insert")
            restore_selective_insert "${target_db}" "${backup_data}"
            ;;
        "replace")
            restore_selective_replace "${target_db}" "${backup_data}"
            ;;
        "merge")
            restore_selective_merge "${target_db}" "${backup_data}"
            ;;
        *)
            log_error "未知的恢复模式: ${restore_mode}"
            return 1
            ;;
    esac
}

# Restore selective backup with insert mode
restore_selective_insert() {
    local target_db="$1"
    local backup_data="$2"

    log_debug "使用插入模式恢复选择性备份"

    local sql_commands="BEGIN TRANSACTION;"
    local insert_count=0

    # Process each record
    while IFS= read -r record; do
        if [[ -n "${record}" ]]; then
            local key value
            key=$(echo "${record}" | jq -r '.key' 2>/dev/null)
            value=$(echo "${record}" | jq -r '.value' 2>/dev/null)

            if [[ -n "${key}" && "${key}" != "null" ]]; then
                # Escape single quotes for SQL
                key=$(echo "${key}" | sed "s/'/''/g")
                value=$(echo "${value}" | sed "s/'/''/g")

                sql_commands="${sql_commands} INSERT OR IGNORE INTO ItemTable (key, value) VALUES ('${key}', '${value}');"
                ((insert_count++))
            fi
        fi
    done <<< "${backup_data}"

    sql_commands="${sql_commands} COMMIT;"

    # Execute restoration
    if sqlite3 "${target_db}" "${sql_commands}" 2>/dev/null; then
        log_success "选择性备份恢复成功，插入了 ${insert_count} 条记录"
        return 0
    else
        log_error "选择性备份恢复失败"
        return 1
    fi
}

# Export backup functions including selective backup
export -f init_backup create_backup restore_backup list_backups
export -f cleanup_old_backups generate_backup_report verify_backup_integrity
export -f create_selective_backup perform_selective_backup validate_sql_query
export -f register_selective_backup restore_selective_backup restore_selective_insert
export BACKUP_BASE_DIR BACKUP_REGISTRY BACKUP_STATS

log_debug "Backup and recovery module loaded with selective backup support"
