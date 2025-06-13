#!/bin/bash
# migration.sh
#
# Auto-fixed for readonly variable conflicts

# Prevent multiple loading
if [[ "${MIGRATION_SH_LOADED:-}" == "true" ]]; then
    return 0
fi
if [[ -z "${MIGRATION_SH_LOADED:-}" ]]; then
    readonly MIGRATION_SH_LOADED="true"
fi

# core/migration.sh
#
# Enterprise-grade data migration module for VS Code database operations
# Production-ready with comprehensive safety, validation and audit trails
# Supports selective data backup, transformation, and restoration

set -euo pipefail

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/security.sh"
source "$(dirname "${BASH_SOURCE[0]}")/validation.sh"
source "$(dirname "${BASH_SOURCE[0]}")/backup.sh"
source "$(dirname "${BASH_SOURCE[0]}")/database.sh"
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

# Migration operation constants
if [[ -z "${MIGRATION_TIMEOUT:-}" ]]; then
    readonly MIGRATION_TIMEOUT=300
fi
if [[ -z "${MAX_BATCH_SIZE:-}" ]]; then
    readonly MAX_BATCH_SIZE=1000
fi
if [[ -z "${MIGRATION_BACKUP_SUFFIX:-}" ]]; then
    readonly MIGRATION_BACKUP_SUFFIX=".migration_backup"
fi

# Migration patterns and rules
if [[ -z "${DEFAULT_TRANSFORMATION_RULES:-}" ]]; then
    readonly DEFAULT_TRANSFORMATION_RULES=(
        "machineId"
        "deviceId"
        "sqmId"
        "uuid"
        "session"
    )
fi

# Global migration operation statistics
declare -A MIGRATION_STATS=()

# Initialize migration module
init_migration() {
    log_info "初始化数据迁移模块..."
    
    # Check required dependencies
    if ! is_command_available sqlite3; then
        log_error "SQLite3 is required for migration operations"
        return 1
    fi
    
    if ! is_command_available jq; then
        log_error "jq is required for JSON processing in migrations"
        return 1
    fi
    
    # Verify database module is available
    if ! declare -f clean_vscode_database >/dev/null 2>&1; then
        log_error "Database module not properly loaded"
        return 1
    fi
    
    # Initialize migration statistics
    MIGRATION_STATS["migrations_started"]=0
    MIGRATION_STATS["migrations_completed"]=0
    MIGRATION_STATS["records_extracted"]=0
    MIGRATION_STATS["records_transformed"]=0
    MIGRATION_STATS["records_inserted"]=0
    MIGRATION_STATS["errors_encountered"]=0
    
    audit_log "MIGRATION_INIT" "数据迁移模块已初始化"
    log_success "数据迁移模块初始化完成"
}

# Main migration function
migrate_database_data() {
    local db_file="$1"
    local migration_config="${2:-default}"
    local dry_run="${3:-false}"
    
    log_info "开始数据库迁移: ${db_file}"
    
    # Validate database file
    if ! validate_database_file "${db_file}"; then
        log_error "数据库验证失败: ${db_file}"
        return 1
    fi
    
    # Authorize migration operation
    if ! authorize_operation "migration_extract" "${db_file}"; then
        log_error "数据迁移操作未授权"
        return 1
    fi
    
    # Increment migration counter
    ((MIGRATION_STATS["migrations_started"]++))
    
    # Create migration backup
    local migration_backup=""
    if [[ "${dry_run}" != "true" ]]; then
        migration_backup=$(create_migration_backup "${db_file}")
        if [[ -z "${migration_backup}" ]]; then
            log_error "创建迁移备份失败: ${db_file}"
            return 1
        fi
    fi
    
    # Execute migration phases
    local start_time=$(date +%s.%3N)
    local migration_success=false
    
    if execute_migration_phases "${db_file}" "${migration_config}" "${dry_run}"; then
        migration_success=true
        ((MIGRATION_STATS["migrations_completed"]++))
        log_success "数据迁移完成: ${db_file}"
    else
        log_error "数据迁移失败: ${db_file}"
        ((MIGRATION_STATS["errors_encountered"]++))
        
        # Restore from backup if migration failed
        if [[ -n "${migration_backup}" && -f "${migration_backup}" ]]; then
            log_info "正在从备份恢复数据库..."
            restore_database_backup "${migration_backup}" "${db_file}"
        fi
        return 1
    fi
    
    local end_time=$(date +%s.%3N)
    log_performance "migration_complete" "${start_time}" "${end_time}" "${db_file}"
    
    audit_log "MIGRATION_COMPLETE" "数据迁移完成: ${db_file}, 成功: ${migration_success}"
    return 0
}

# Execute migration phases
execute_migration_phases() {
    local db_file="$1"
    local migration_config="$2"
    local dry_run="$3"
    
    log_info "执行迁移阶段..."
    
    # Phase 1: Extract data
    local extracted_data
    extracted_data=$(extract_migration_data "${db_file}" "${migration_config}")
    if [[ $? -ne 0 || -z "${extracted_data}" ]]; then
        log_error "数据提取阶段失败"
        return 1
    fi
    
    # Phase 2: Transform data
    local transformed_data
    transformed_data=$(transform_migration_data "${extracted_data}" "${migration_config}")
    if [[ $? -ne 0 || -z "${transformed_data}" ]]; then
        log_error "数据转换阶段失败"
        return 1
    fi
    
    if [[ "${dry_run}" == "true" ]]; then
        log_info "DRY RUN: 迁移预览完成，未执行实际数据修改"
        return 0
    fi
    
    # Phase 3: Delete original data
    if ! delete_original_data "${db_file}" "${migration_config}"; then
        log_error "原始数据删除阶段失败"
        return 1
    fi
    
    # Phase 4: Insert transformed data
    if ! insert_transformed_data "${db_file}" "${transformed_data}"; then
        log_error "转换数据插入阶段失败"
        return 1
    fi
    
    # Phase 5: Validate migration
    if ! validate_migration_result "${db_file}" "${migration_config}"; then
        log_error "迁移结果验证失败"
        return 1
    fi
    
    log_success "所有迁移阶段执行完成"
    return 0
}

# Create migration-specific backup
create_migration_backup() {
    local db_file="$1"
    local timestamp=$(get_timestamp)
    local backup_file="${db_file}${MIGRATION_BACKUP_SUFFIX}_${timestamp}"
    
    log_debug "创建迁移备份: ${db_file} -> ${backup_file}"
    
    # Use SQLite backup command for consistency
    if sqlite3 "${db_file}" ".backup '${backup_file}'" 2>/dev/null; then
        log_success "迁移备份创建成功: ${backup_file}"
        audit_log "MIGRATION_BACKUP" "迁移备份已创建: ${db_file} -> ${backup_file}"
        echo "${backup_file}"
        return 0
    else
        log_error "迁移备份创建失败: ${db_file}"
        return 1
    fi
}

# Get migration statistics
get_migration_stats() {
    log_info "数据迁移统计信息:"
    for stat_name in "${!MIGRATION_STATS[@]}"; do
        log_info "  ${stat_name}: ${MIGRATION_STATS["${stat_name}"]}"
    done
}

# Generate migration report
generate_migration_report() {
    local report_file="${1:-migration_report_$(get_timestamp).txt}"
    
    log_info "生成迁移报告: ${report_file}"
    
    {
        echo "数据迁移操作报告"
        echo "生成时间: $(date)"
        echo "=========================="
        echo ""
        echo "统计信息:"
        for stat_name in "${!MIGRATION_STATS[@]}"; do
            echo "  ${stat_name}: ${MIGRATION_STATS["${stat_name}"]}"
        done
        echo ""
        echo "配置信息:"
        echo "  迁移超时: ${MIGRATION_TIMEOUT} 秒"
        echo "  最大批处理大小: ${MAX_BATCH_SIZE}"
        echo "  备份后缀: ${MIGRATION_BACKUP_SUFFIX}"
        
    } > "${report_file}"
    
    log_success "迁移报告已生成: ${report_file}"
}

# Extract migration data
extract_migration_data() {
    local db_file="$1"
    local migration_config="$2"

    log_debug "提取迁移数据: ${db_file}"

    # Build extraction query based on transformation rules
    local where_conditions=""
    for rule in "${DEFAULT_TRANSFORMATION_RULES[@]}"; do
        if [[ -n "${where_conditions}" ]]; then
            where_conditions="${where_conditions} OR "
        fi
        where_conditions="${where_conditions}key LIKE '%${rule}%'"
    done

    # Extract data as JSON
    local extraction_query="SELECT json_object('key', key, 'value', value) FROM ItemTable WHERE ${where_conditions};"
    local extracted_data

    extracted_data=$(sqlite3 "${db_file}" "${extraction_query}" 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        local record_count=$(echo "${extracted_data}" | wc -l)
        ((MIGRATION_STATS["records_extracted"] += record_count))
        log_debug "提取了 ${record_count} 条记录"
        echo "${extracted_data}"
        return 0
    else
        log_error "数据提取失败"
        return 1
    fi
}

# Transform migration data
transform_migration_data() {
    local extracted_data="$1"
    local migration_config="$2"

    log_debug "转换迁移数据"

    # Source telemetry module for ID generation
    if [[ -f "$(dirname "${BASH_SOURCE[0]}")/telemetry.sh" ]]; then
        source "$(dirname "${BASH_SOURCE[0]}")/telemetry.sh"
    fi

    local transformed_data=""
    local record_count=0

    # Process each extracted record
    while IFS= read -r record; do
        if [[ -n "${record}" ]]; then
            local transformed_record
            transformed_record=$(transform_single_record "${record}")
            if [[ $? -eq 0 && -n "${transformed_record}" ]]; then
                transformed_data="${transformed_data}${transformed_record}\n"
                ((record_count++))
            fi
        fi
    done <<< "${extracted_data}"

    ((MIGRATION_STATS["records_transformed"] += record_count))
    log_debug "转换了 ${record_count} 条记录"
    echo -e "${transformed_data}"
    return 0
}

# Transform single record
transform_single_record() {
    local record="$1"

    # Parse JSON record
    local key value
    key=$(echo "${record}" | jq -r '.key' 2>/dev/null)
    value=$(echo "${record}" | jq -r '.value' 2>/dev/null)

    if [[ -z "${key}" || "${key}" == "null" ]]; then
        log_warn "无效的记录格式，跳过"
        return 1
    fi

    # Transform key field
    local new_key="${key}"
    for rule in "${DEFAULT_TRANSFORMATION_RULES[@]}"; do
        if [[ "${key}" == *"${rule}"* ]]; then
            # Generate new ID based on rule type
            local new_id
            case "${rule}" in
                "machineId")
                    new_id=$(generate_machine_id 2>/dev/null || echo "$(openssl rand -hex 32 2>/dev/null || echo "fallback_machine_id_$(date +%s)")")
                    ;;
                "deviceId"|"sqmId"|"uuid")
                    new_id=$(generate_uuid_v4 2>/dev/null || echo "$(uuidgen 2>/dev/null || echo "fallback_uuid_$(date +%s)")")
                    ;;
                "session")
                    new_id="session_$(date +%s)_$(openssl rand -hex 8 2>/dev/null || echo "$(date +%N)")"
                    ;;
                *)
                    new_id="transformed_${rule}_$(date +%s)"
                    ;;
            esac

            # Replace in key
            new_key=$(echo "${new_key}" | sed "s/${rule}[^[:space:]]*/${new_id}/g")
            log_debug "转换规则 ${rule}: 生成新ID ${new_id}"
        fi
    done

    # Transform value field if it contains JSON
    local new_value="${value}"
    if [[ "${value}" != "null" && "${value}" =~ ^\{.*\}$ ]]; then
        # Process JSON value
        for rule in "${DEFAULT_TRANSFORMATION_RULES[@]}"; do
            if echo "${value}" | jq -e ".\"${rule}\"" >/dev/null 2>&1; then
                local new_id
                case "${rule}" in
                    "machineId")
                        new_id=$(generate_machine_id 2>/dev/null || echo "fallback_machine_id_$(date +%s)")
                        ;;
                    *)
                        new_id=$(generate_uuid_v4 2>/dev/null || echo "fallback_uuid_$(date +%s)")
                        ;;
                esac
                new_value=$(echo "${new_value}" | jq --arg new_id "${new_id}" ".\"${rule}\" = \$new_id" 2>/dev/null)
            fi
        done
    fi

    # Return transformed record as JSON
    jq -n --arg key "${new_key}" --arg value "${new_value}" '{key: $key, value: $value}'
}

# Delete original data
delete_original_data() {
    local db_file="$1"
    local migration_config="$2"

    log_debug "删除原始数据: ${db_file}"

    # Build deletion query
    local where_conditions=""
    for rule in "${DEFAULT_TRANSFORMATION_RULES[@]}"; do
        if [[ -n "${where_conditions}" ]]; then
            where_conditions="${where_conditions} OR "
        fi
        where_conditions="${where_conditions}key LIKE '%${rule}%'"
    done

    local deletion_query="DELETE FROM ItemTable WHERE ${where_conditions};"

    # Execute deletion in transaction
    if sqlite3 "${db_file}" "BEGIN TRANSACTION; ${deletion_query} COMMIT;" 2>/dev/null; then
        log_debug "原始数据删除成功"
        return 0
    else
        log_error "原始数据删除失败"
        return 1
    fi
}

# Insert transformed data
insert_transformed_data() {
    local db_file="$1"
    local transformed_data="$2"

    log_debug "插入转换后的数据: ${db_file}"

    local insert_count=0
    local sql_commands="BEGIN TRANSACTION;"

    # Process each transformed record
    while IFS= read -r record; do
        if [[ -n "${record}" ]]; then
            local key value
            key=$(echo "${record}" | jq -r '.key' 2>/dev/null)
            value=$(echo "${record}" | jq -r '.value' 2>/dev/null)

            if [[ -n "${key}" && "${key}" != "null" ]]; then
                # Escape single quotes for SQL
                key=$(echo "${key}" | sed "s/'/''/g")
                value=$(echo "${value}" | sed "s/'/''/g")

                sql_commands="${sql_commands} INSERT INTO ItemTable (key, value) VALUES ('${key}', '${value}');"
                ((insert_count++))
            fi
        fi
    done <<< "${transformed_data}"

    sql_commands="${sql_commands} COMMIT;"

    # Execute insertion
    if sqlite3 "${db_file}" "${sql_commands}" 2>/dev/null; then
        ((MIGRATION_STATS["records_inserted"] += insert_count))
        log_debug "插入了 ${insert_count} 条转换后的记录"
        return 0
    else
        log_error "转换数据插入失败"
        return 1
    fi
}

# Validate migration result
validate_migration_result() {
    local db_file="$1"
    local migration_config="$2"

    log_debug "验证迁移结果: ${db_file}"

    # Check database integrity
    if ! sqlite3 "${db_file}" "PRAGMA integrity_check;" >/dev/null 2>&1; then
        log_error "数据库完整性检查失败"
        return 1
    fi

    # Verify no old patterns remain
    for rule in "${DEFAULT_TRANSFORMATION_RULES[@]}"; do
        local remaining_count
        remaining_count=$(sqlite3 "${db_file}" "SELECT COUNT(*) FROM ItemTable WHERE key LIKE '%${rule}%';" 2>/dev/null || echo "0")
        if [[ ${remaining_count} -gt 0 ]]; then
            log_warn "发现 ${remaining_count} 条未转换的 ${rule} 记录"
        fi
    done

    log_debug "迁移结果验证完成"
    return 0
}

# Export migration functions
export -f init_migration migrate_database_data execute_migration_phases
export -f extract_migration_data transform_migration_data transform_single_record
export -f delete_original_data insert_transformed_data validate_migration_result
export -f create_migration_backup get_migration_stats generate_migration_report
export MIGRATION_STATS DEFAULT_TRANSFORMATION_RULES

log_debug "数据迁移模块已加载"
