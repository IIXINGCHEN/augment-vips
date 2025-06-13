#!/bin/bash
# insertion.sh
#
# Auto-fixed for readonly variable conflicts

# Prevent multiple loading
if [[ "${INSERTION_SH_LOADED:-}" == "true" ]]; then
    return 0
fi
if [[ -z "${INSERTION_SH_LOADED:-}" ]]; then
    readonly INSERTION_SH_LOADED="true"
fi

# core/insertion.sh
#
# Enterprise-grade data insertion module for VS Code database operations
# Production-ready with transaction support, conflict detection and rollback
# Supports batch operations and comprehensive validation

set -euo pipefail

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/security.sh"
source "$(dirname "${BASH_SOURCE[0]}")/validation.sh"
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

# Insertion operation constants
if [[ -z "${INSERTION_TIMEOUT:-}" ]]; then
    readonly INSERTION_TIMEOUT=180
fi
if [[ -z "${MAX_BATCH_SIZE:-}" ]]; then
    readonly MAX_BATCH_SIZE=1000
fi
if [[ -z "${CONFLICT_RESOLUTION_STRATEGIES:-}" ]]; then
    readonly CONFLICT_RESOLUTION_STRATEGIES=("ignore" "replace" "update" "fail")
fi

# Global insertion statistics
declare -A INSERTION_STATS=()

# Initialize insertion module
init_insertion() {
    log_info "初始化数据插入模块..."
    
    # Check required dependencies
    if ! is_command_available sqlite3; then
        log_error "SQLite3 is required for insertion operations"
        return 1
    fi
    
    if ! is_command_available jq; then
        log_error "jq is required for JSON processing in insertion"
        return 1
    fi
    
    # Initialize insertion statistics
    INSERTION_STATS["insertions_performed"]=0
    INSERTION_STATS["records_inserted"]=0
    INSERTION_STATS["conflicts_detected"]=0
    INSERTION_STATS["conflicts_resolved"]=0
    INSERTION_STATS["transactions_committed"]=0
    INSERTION_STATS["transactions_rolled_back"]=0
    INSERTION_STATS["errors_encountered"]=0
    
    audit_log "INSERTION_INIT" "数据插入模块已初始化"
    log_success "数据插入模块初始化完成"
}

# Insert transformed data into database
insert_transformed_data() {
    local db_file="$1"
    local transformed_data="$2"
    local conflict_strategy="${3:-ignore}"
    local batch_size="${4:-${MAX_BATCH_SIZE}}"
    
    log_info "插入转换后的数据: ${db_file}"
    
    # Validate database file
    if ! validate_database_file "${db_file}"; then
        log_error "数据库验证失败: ${db_file}"
        return 1
    fi
    
    # Authorize insertion operation
    if ! authorize_operation "migration_insert" "${db_file}"; then
        log_error "数据插入操作未授权"
        return 1
    fi
    
    # Validate conflict strategy
    if ! validate_conflict_strategy "${conflict_strategy}"; then
        log_error "无效的冲突解决策略: ${conflict_strategy}"
        return 1
    fi
    
    # Validate transformed data
    if ! validate_insertion_data "${transformed_data}"; then
        log_error "转换数据验证失败"
        return 1
    fi
    
    # Perform batch insertion
    local start_time=$(date +%s.%3N)
    local insertion_result
    
    insertion_result=$(perform_batch_insertion "${db_file}" "${transformed_data}" "${conflict_strategy}" "${batch_size}")
    if [[ $? -eq 0 ]]; then
        ((INSERTION_STATS["insertions_performed"]++))
        ((INSERTION_STATS["transactions_committed"]++))
        
        local end_time=$(date +%s.%3N)
        log_performance "data_insertion" "${start_time}" "${end_time}" "${db_file}"
        
        audit_log "INSERTION_SUCCESS" "数据插入完成: ${db_file}"
        log_success "数据插入完成: ${insertion_result}"
        return 0
    else
        ((INSERTION_STATS["errors_encountered"]++))
        ((INSERTION_STATS["transactions_rolled_back"]++))
        log_error "数据插入失败: ${db_file}"
        return 1
    fi
}

# Perform batch insertion with transaction support
perform_batch_insertion() {
    local db_file="$1"
    local transformed_data="$2"
    local conflict_strategy="$3"
    local batch_size="$4"
    
    log_debug "执行批量插入操作"
    
    local total_records=0
    local inserted_records=0
    local conflict_count=0
    local current_batch=0
    local batch_records=()
    
    # Count total records
    if [[ -n "${transformed_data}" ]]; then
        total_records=$(echo "${transformed_data}" | wc -l)
    fi
    
    log_debug "准备插入 ${total_records} 条记录，批大小: ${batch_size}"
    
    # Process records in batches
    while IFS= read -r record; do
        if [[ -n "${record}" ]]; then
            batch_records+=("${record}")
            
            # Process batch when full or at end
            if [[ ${#batch_records[@]} -ge ${batch_size} ]]; then
                local batch_result
                batch_result=$(insert_record_batch "${db_file}" "${batch_records[@]}" "${conflict_strategy}")
                if [[ $? -eq 0 ]]; then
                    local batch_stats
                    batch_stats=$(echo "${batch_result}" | jq -r '.inserted, .conflicts' 2>/dev/null)
                    read -r batch_inserted batch_conflicts <<< "${batch_stats}"
                    
                    ((inserted_records += batch_inserted))
                    ((conflict_count += batch_conflicts))
                    ((current_batch++))
                    
                    log_debug "批次 ${current_batch} 完成: 插入 ${batch_inserted} 条，冲突 ${batch_conflicts} 条"
                else
                    log_error "批次 ${current_batch} 插入失败"
                    return 1
                fi
                
                # Reset batch
                batch_records=()
            fi
        fi
    done <<< "${transformed_data}"
    
    # Process remaining records
    if [[ ${#batch_records[@]} -gt 0 ]]; then
        local batch_result
        batch_result=$(insert_record_batch "${db_file}" "${batch_records[@]}" "${conflict_strategy}")
        if [[ $? -eq 0 ]]; then
            local batch_stats
            batch_stats=$(echo "${batch_result}" | jq -r '.inserted, .conflicts' 2>/dev/null)
            read -r batch_inserted batch_conflicts <<< "${batch_stats}"
            
            ((inserted_records += batch_inserted))
            ((conflict_count += batch_conflicts))
            ((current_batch++))
            
            log_debug "最后批次完成: 插入 ${batch_inserted} 条，冲突 ${batch_conflicts} 条"
        else
            log_error "最后批次插入失败"
            return 1
        fi
    fi
    
    # Update statistics
    ((INSERTION_STATS["records_inserted"] += inserted_records))
    ((INSERTION_STATS["conflicts_detected"] += conflict_count))
    ((INSERTION_STATS["conflicts_resolved"] += conflict_count))
    
    # Return summary
    jq -n \
        --arg total "${total_records}" \
        --arg inserted "${inserted_records}" \
        --arg conflicts "${conflict_count}" \
        --arg batches "${current_batch}" \
        '{
            total_records: ($total | tonumber),
            inserted_records: ($inserted | tonumber),
            conflicts_detected: ($conflicts | tonumber),
            batches_processed: ($batches | tonumber)
        }'
}

# Insert a batch of records
insert_record_batch() {
    local db_file="$1"
    shift
    local records=("$@")
    local conflict_strategy="${records[-1]}"
    unset 'records[-1]'  # Remove strategy from records array
    
    log_debug "插入记录批次: ${#records[@]} 条记录"
    
    # Build SQL commands for batch
    local sql_commands="BEGIN TRANSACTION;"
    local inserted_count=0
    local conflict_count=0
    
    for record in "${records[@]}"; do
        if [[ -n "${record}" ]]; then
            # Parse record
            local key value
            key=$(echo "${record}" | jq -r '.key' 2>/dev/null)
            value=$(echo "${record}" | jq -r '.value' 2>/dev/null)
            
            if [[ -n "${key}" && "${key}" != "null" ]]; then
                # Escape single quotes for SQL
                key=$(echo "${key}" | sed "s/'/''/g")
                value=$(echo "${value}" | sed "s/'/''/g")
                
                # Check for conflicts
                local existing_record
                existing_record=$(sqlite3 "${db_file}" "SELECT COUNT(*) FROM ItemTable WHERE key = '${key}';" 2>/dev/null)
                
                if [[ ${existing_record} -gt 0 ]]; then
                    ((conflict_count++))
                    # Handle conflict based on strategy
                    case "${conflict_strategy}" in
                        "ignore")
                            continue
                            ;;
                        "replace")
                            sql_commands="${sql_commands} INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('${key}', '${value}');"
                            ;;
                        "update")
                            sql_commands="${sql_commands} UPDATE ItemTable SET value = '${value}' WHERE key = '${key}';"
                            ;;
                        "fail")
                            log_error "检测到冲突，插入失败: ${key}"
                            return 1
                            ;;
                    esac
                else
                    sql_commands="${sql_commands} INSERT INTO ItemTable (key, value) VALUES ('${key}', '${value}');"
                fi
                
                ((inserted_count++))
            fi
        fi
    done
    
    sql_commands="${sql_commands} COMMIT;"
    
    # Execute batch insertion
    if timeout "${INSERTION_TIMEOUT}" sqlite3 "${db_file}" "${sql_commands}" 2>/dev/null; then
        log_debug "批次插入成功: ${inserted_count} 条记录，${conflict_count} 个冲突"
        
        # Return batch statistics
        jq -n \
            --arg inserted "${inserted_count}" \
            --arg conflicts "${conflict_count}" \
            '{
                inserted: ($inserted | tonumber),
                conflicts: ($conflicts | tonumber)
            }'
        return 0
    else
        log_error "批次插入失败"
        return 1
    fi
}

# Validate conflict resolution strategy
validate_conflict_strategy() {
    local strategy="$1"
    
    for valid_strategy in "${CONFLICT_RESOLUTION_STRATEGIES[@]}"; do
        if [[ "${strategy}" == "${valid_strategy}" ]]; then
            return 0
        fi
    done
    
    return 1
}

# Validate insertion data format
validate_insertion_data() {
    local data="$1"
    
    if [[ -z "${data}" ]]; then
        log_error "插入数据为空"
        return 1
    fi
    
    local record_count=0
    local invalid_count=0
    
    # Validate each record
    while IFS= read -r record; do
        if [[ -n "${record}" ]]; then
            ((record_count++))
            
            # Check JSON format
            if ! echo "${record}" | jq '.' >/dev/null 2>&1; then
                ((invalid_count++))
                continue
            fi
            
            # Check required fields
            local key value
            key=$(echo "${record}" | jq -r '.key' 2>/dev/null)
            value=$(echo "${record}" | jq -r '.value' 2>/dev/null)
            
            if [[ -z "${key}" || "${key}" == "null" ]]; then
                ((invalid_count++))
            fi
        fi
    done <<< "${data}"
    
    if [[ ${invalid_count} -gt 0 ]]; then
        log_error "发现 ${invalid_count}/${record_count} 条无效记录"
        return 1
    fi
    
    log_debug "数据验证通过: ${record_count} 条记录"
    return 0
}

# Verify insertion integrity
verify_insertion_integrity() {
    local db_file="$1"
    local expected_records="$2"

    log_debug "验证插入完整性"

    # Check database integrity
    if ! sqlite3 "${db_file}" "PRAGMA integrity_check;" >/dev/null 2>&1; then
        log_error "数据库完整性检查失败"
        return 1
    fi

    # Count inserted records
    local actual_count
    actual_count=$(sqlite3 "${db_file}" "SELECT COUNT(*) FROM ItemTable;" 2>/dev/null || echo "0")

    log_debug "预期记录数: ${expected_records}, 实际记录数: ${actual_count}"

    # Verify record count (allowing for conflicts)
    if [[ ${actual_count} -lt ${expected_records} ]]; then
        log_warn "插入的记录数少于预期"
    fi

    return 0
}

# Rollback insertion transaction
rollback_insertion() {
    local db_file="$1"
    local backup_file="$2"

    log_info "回滚插入操作: ${db_file}"

    if [[ -n "${backup_file}" && -f "${backup_file}" ]]; then
        # Restore from backup
        if cp "${backup_file}" "${db_file}"; then
            log_success "插入操作已回滚"
            audit_log "INSERTION_ROLLBACK" "插入操作已回滚: ${db_file}"
            return 0
        else
            log_error "回滚失败：无法恢复备份"
            return 1
        fi
    else
        log_error "回滚失败：备份文件不存在"
        return 1
    fi
}

# Get insertion statistics
get_insertion_stats() {
    log_info "数据插入统计信息:"
    for stat_name in "${!INSERTION_STATS[@]}"; do
        log_info "  ${stat_name}: ${INSERTION_STATS["${stat_name}"]}"
    done
}

# Generate insertion report
generate_insertion_report() {
    local report_file="${1:-insertion_report_$(get_timestamp).txt}"

    log_info "生成插入报告: ${report_file}"

    {
        echo "数据插入操作报告"
        echo "生成时间: $(date)"
        echo "=========================="
        echo ""
        echo "统计信息:"
        for stat_name in "${!INSERTION_STATS[@]}"; do
            echo "  ${stat_name}: ${INSERTION_STATS["${stat_name}"]}"
        done
        echo ""
        echo "配置信息:"
        echo "  插入超时: ${INSERTION_TIMEOUT} 秒"
        echo "  最大批大小: ${MAX_BATCH_SIZE}"
        echo ""
        echo "支持的冲突解决策略:"
        for strategy in "${CONFLICT_RESOLUTION_STRATEGIES[@]}"; do
            echo "  - ${strategy}"
        done

    } > "${report_file}"

    log_success "插入报告已生成: ${report_file}"
}

# Test insertion functionality
test_insertion() {
    local test_db="${1:-test_insertion.db}"

    log_info "测试插入功能: ${test_db}"

    # Create test database
    sqlite3 "${test_db}" "CREATE TABLE IF NOT EXISTS ItemTable (key TEXT PRIMARY KEY, value TEXT);" 2>/dev/null

    # Create test data
    local test_data='{"key":"test.key.1","value":"test_value_1"}
{"key":"test.key.2","value":"test_value_2"}'

    # Test insertion
    if insert_transformed_data "${test_db}" "${test_data}" "ignore" 10; then
        log_success "插入功能测试通过"

        # Verify results
        local record_count
        record_count=$(sqlite3 "${test_db}" "SELECT COUNT(*) FROM ItemTable WHERE key LIKE 'test.key.%';" 2>/dev/null)
        log_info "插入了 ${record_count} 条测试记录"

        # Cleanup
        rm -f "${test_db}"
        return 0
    else
        log_error "插入功能测试失败"
        rm -f "${test_db}"
        return 1
    fi
}

# Monitor insertion progress
monitor_insertion_progress() {
    local total_records="$1"
    local current_records="$2"

    if [[ ${total_records} -gt 0 ]]; then
        local progress=$((current_records * 100 / total_records))
        log_info "插入进度: ${current_records}/${total_records} (${progress}%)"
    fi
}

# Optimize insertion performance
optimize_insertion_performance() {
    local db_file="$1"

    log_debug "优化插入性能"

    # Set SQLite pragmas for better insertion performance
    sqlite3 "${db_file}" "
        PRAGMA synchronous = OFF;
        PRAGMA journal_mode = MEMORY;
        PRAGMA cache_size = 10000;
        PRAGMA temp_store = MEMORY;
    " 2>/dev/null

    log_debug "插入性能优化完成"
}

# Restore insertion performance settings
restore_insertion_performance() {
    local db_file="$1"

    log_debug "恢复插入性能设置"

    # Restore default SQLite pragmas
    sqlite3 "${db_file}" "
        PRAGMA synchronous = FULL;
        PRAGMA journal_mode = DELETE;
        PRAGMA cache_size = 2000;
        PRAGMA temp_store = DEFAULT;
    " 2>/dev/null

    log_debug "插入性能设置已恢复"
}

# Export insertion functions
export -f init_insertion insert_transformed_data perform_batch_insertion
export -f insert_record_batch validate_conflict_strategy validate_insertion_data
export -f verify_insertion_integrity rollback_insertion get_insertion_stats
export -f generate_insertion_report test_insertion monitor_insertion_progress
export -f optimize_insertion_performance restore_insertion_performance
export INSERTION_STATS CONFLICT_RESOLUTION_STRATEGIES

log_debug "数据插入模块已加载"
