#!/bin/bash
# consistency.sh
#
# Auto-fixed for readonly variable conflicts

# Prevent multiple loading
if [[ "${CONSISTENCY_SH_LOADED:-}" == "true" ]]; then
    return 0
fi
if [[ -z "${CONSISTENCY_SH_LOADED:-}" ]]; then
    readonly CONSISTENCY_SH_LOADED="true"
fi

# core/consistency.sh
#
# Enterprise-grade data consistency validation module for VS Code database operations
# Production-ready with comprehensive integrity checks and validation reports
# Supports pre/post migration validation and data quality assurance

set -euo pipefail

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/security.sh"
source "$(dirname "${BASH_SOURCE[0]}")/validation.sh"
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

# Consistency check constants
if [[ -z "${CONSISTENCY_TIMEOUT:-}" ]]; then
    readonly CONSISTENCY_TIMEOUT=60
fi
if [[ -z "${MAX_VALIDATION_RECORDS:-}" ]]; then
    readonly MAX_VALIDATION_RECORDS=100000
fi
if [[ -z "${VALIDATION_SAMPLE_SIZE:-}" ]]; then
    readonly VALIDATION_SAMPLE_SIZE=1000
fi

# Validation check types
if [[ -z "${VALIDATION_CHECKS:-}" ]]; then
    readonly VALIDATION_CHECKS=(
        "database_integrity"
        "record_count"
        "data_format"
        "key_uniqueness"
        "value_validity"
        "transformation_accuracy"
    )
fi

# Global consistency statistics
declare -A CONSISTENCY_STATS=()

# Initialize consistency validation module
init_consistency() {
    log_info "初始化数据一致性验证模块..."
    
    # Check required dependencies
    if ! is_command_available sqlite3; then
        log_error "SQLite3 is required for consistency validation"
        return 1
    fi
    
    if ! is_command_available jq; then
        log_error "jq is required for JSON validation"
        return 1
    fi
    
    # Initialize consistency statistics
    CONSISTENCY_STATS["validations_performed"]=0
    CONSISTENCY_STATS["checks_passed"]=0
    CONSISTENCY_STATS["checks_failed"]=0
    CONSISTENCY_STATS["warnings_generated"]=0
    CONSISTENCY_STATS["errors_detected"]=0
    
    audit_log "CONSISTENCY_INIT" "数据一致性验证模块已初始化"
    log_success "数据一致性验证模块初始化完成"
}

# Perform comprehensive migration validation
validate_migration_consistency() {
    local db_file="$1"
    local validation_type="${2:-full}"
    local reference_data="${3:-}"
    
    log_info "执行迁移一致性验证: ${db_file}"
    
    # Validate database file
    if ! validate_database_file "${db_file}"; then
        log_error "数据库验证失败: ${db_file}"
        return 1
    fi
    
    # Authorize validation operation
    if ! authorize_operation "migration_validate" "${db_file}"; then
        log_error "一致性验证操作未授权"
        return 1
    fi
    
    local start_time=$(date +%s.%3N)
    local validation_result=true
    local checks_performed=0
    local checks_passed=0
    
    # Perform validation checks based on type
    case "${validation_type}" in
        "full")
            perform_full_validation "${db_file}" "${reference_data}"
            ;;
        "basic")
            perform_basic_validation "${db_file}"
            ;;
        "integrity")
            perform_integrity_validation "${db_file}"
            ;;
        "transformation")
            perform_transformation_validation "${db_file}" "${reference_data}"
            ;;
        *)
            log_error "未知的验证类型: ${validation_type}"
            return 1
            ;;
    esac
    
    local validation_exit_code=$?
    
    # Update statistics
    ((CONSISTENCY_STATS["validations_performed"]++))
    if [[ ${validation_exit_code} -eq 0 ]]; then
        log_success "一致性验证通过"
    else
        log_error "一致性验证失败"
        ((CONSISTENCY_STATS["errors_detected"]++))
    fi
    
    local end_time=$(date +%s.%3N)
    log_performance "consistency_validation" "${start_time}" "${end_time}" "${db_file}"
    
    audit_log "CONSISTENCY_VALIDATION" "一致性验证完成: ${db_file}, 类型: ${validation_type}, 结果: ${validation_exit_code}"
    
    return ${validation_exit_code}
}

# Perform full validation with all checks
perform_full_validation() {
    local db_file="$1"
    local reference_data="$2"
    
    log_info "执行完整一致性验证"
    
    local validation_failed=false
    
    # Run all validation checks
    for check_type in "${VALIDATION_CHECKS[@]}"; do
        log_debug "执行验证检查: ${check_type}"
        
        if perform_validation_check "${db_file}" "${check_type}" "${reference_data}"; then
            ((CONSISTENCY_STATS["checks_passed"]++))
            log_debug "验证检查通过: ${check_type}"
        else
            ((CONSISTENCY_STATS["checks_failed"]++))
            log_warn "验证检查失败: ${check_type}"
            validation_failed=true
        fi
    done
    
    if [[ "${validation_failed}" == "true" ]]; then
        return 1
    else
        return 0
    fi
}

# Perform basic validation checks
perform_basic_validation() {
    local db_file="$1"
    
    log_info "执行基础一致性验证"
    
    # Check database integrity
    if ! perform_validation_check "${db_file}" "database_integrity"; then
        return 1
    fi
    
    # Check record count
    if ! perform_validation_check "${db_file}" "record_count"; then
        return 1
    fi
    
    # Check data format
    if ! perform_validation_check "${db_file}" "data_format"; then
        return 1
    fi
    
    return 0
}

# Perform integrity validation
perform_integrity_validation() {
    local db_file="$1"
    
    log_info "执行完整性验证"
    
    # SQLite integrity check
    if ! sqlite3 "${db_file}" "PRAGMA integrity_check;" >/dev/null 2>&1; then
        log_error "SQLite完整性检查失败"
        return 1
    fi
    
    # Foreign key check
    if ! sqlite3 "${db_file}" "PRAGMA foreign_key_check;" >/dev/null 2>&1; then
        log_error "外键完整性检查失败"
        return 1
    fi
    
    log_success "完整性验证通过"
    return 0
}

# Perform transformation validation
perform_transformation_validation() {
    local db_file="$1"
    local reference_data="$2"
    
    log_info "执行转换验证"
    
    if [[ -z "${reference_data}" ]]; then
        log_warn "没有提供参考数据，跳过转换验证"
        return 0
    fi
    
    # Validate transformation accuracy
    if ! perform_validation_check "${db_file}" "transformation_accuracy" "${reference_data}"; then
        return 1
    fi
    
    return 0
}

# Perform individual validation check
perform_validation_check() {
    local db_file="$1"
    local check_type="$2"
    local reference_data="${3:-}"
    
    case "${check_type}" in
        "database_integrity")
            validate_database_integrity "${db_file}"
            ;;
        "record_count")
            validate_record_count "${db_file}" "${reference_data}"
            ;;
        "data_format")
            validate_data_format "${db_file}"
            ;;
        "key_uniqueness")
            validate_key_uniqueness "${db_file}"
            ;;
        "value_validity")
            validate_value_validity "${db_file}"
            ;;
        "transformation_accuracy")
            validate_transformation_accuracy "${db_file}" "${reference_data}"
            ;;
        *)
            log_error "未知的验证检查类型: ${check_type}"
            return 1
            ;;
    esac
}

# Validate database integrity
validate_database_integrity() {
    local db_file="$1"
    
    log_debug "验证数据库完整性"
    
    # SQLite integrity check
    local integrity_result
    integrity_result=$(sqlite3 "${db_file}" "PRAGMA integrity_check;" 2>/dev/null)
    
    if [[ "${integrity_result}" == "ok" ]]; then
        log_debug "数据库完整性检查通过"
        return 0
    else
        log_error "数据库完整性检查失败: ${integrity_result}"
        return 1
    fi
}

# Validate record count
validate_record_count() {
    local db_file="$1"
    local reference_data="$2"
    
    log_debug "验证记录数量"
    
    # Get current record count
    local current_count
    current_count=$(sqlite3 "${db_file}" "SELECT COUNT(*) FROM ItemTable;" 2>/dev/null || echo "0")
    
    if [[ -n "${reference_data}" ]]; then
        # Compare with reference count
        local reference_count
        reference_count=$(echo "${reference_data}" | wc -l 2>/dev/null || echo "0")
        
        if [[ ${current_count} -ne ${reference_count} ]]; then
            log_warn "记录数量不匹配: 当前 ${current_count}, 参考 ${reference_count}"
            ((CONSISTENCY_STATS["warnings_generated"]++))
        fi
    fi
    
    # Check for reasonable record count
    if [[ ${current_count} -eq 0 ]]; then
        log_warn "数据库中没有记录"
        ((CONSISTENCY_STATS["warnings_generated"]++))
    elif [[ ${current_count} -gt ${MAX_VALIDATION_RECORDS} ]]; then
        log_warn "记录数量过多: ${current_count}"
        ((CONSISTENCY_STATS["warnings_generated"]++))
    fi
    
    log_debug "记录数量验证完成: ${current_count} 条记录"
    return 0
}

# Validate data format
validate_data_format() {
    local db_file="$1"
    
    log_debug "验证数据格式"
    
    # Sample records for validation
    local sample_records
    sample_records=$(sqlite3 "${db_file}" "SELECT key, value FROM ItemTable LIMIT ${VALIDATION_SAMPLE_SIZE};" 2>/dev/null)
    
    local invalid_count=0
    local total_count=0
    
    # Validate each sample record
    while IFS='|' read -r key value; do
        if [[ -n "${key}" ]]; then
            ((total_count++))
            
            # Validate key format
            if [[ -z "${key}" || ${#key} -gt 1000 ]]; then
                ((invalid_count++))
                continue
            fi
            
            # Validate value format if it's JSON
            if [[ "${value}" =~ ^\{.*\}$ ]]; then
                if ! echo "${value}" | jq '.' >/dev/null 2>&1; then
                    ((invalid_count++))
                fi
            fi
        fi
    done <<< "${sample_records}"
    
    if [[ ${invalid_count} -gt 0 ]]; then
        local error_rate=$((invalid_count * 100 / total_count))
        if [[ ${error_rate} -gt 5 ]]; then  # More than 5% error rate
            log_error "数据格式错误率过高: ${error_rate}% (${invalid_count}/${total_count})"
            return 1
        else
            log_warn "发现数据格式错误: ${error_rate}% (${invalid_count}/${total_count})"
            ((CONSISTENCY_STATS["warnings_generated"]++))
        fi
    fi
    
    log_debug "数据格式验证完成: ${total_count} 条记录，${invalid_count} 个错误"
    return 0
}

# Validate key uniqueness
validate_key_uniqueness() {
    local db_file="$1"
    
    log_debug "验证键唯一性"
    
    # Check for duplicate keys
    local duplicate_count
    duplicate_count=$(sqlite3 "${db_file}" "SELECT COUNT(*) - COUNT(DISTINCT key) FROM ItemTable;" 2>/dev/null || echo "0")
    
    if [[ ${duplicate_count} -gt 0 ]]; then
        log_error "发现重复键: ${duplicate_count} 个"
        return 1
    fi
    
    log_debug "键唯一性验证通过"
    return 0
}

# Validate value validity
validate_value_validity() {
    local db_file="$1"

    log_debug "验证值有效性"

    # Sample records for validation
    local sample_records
    sample_records=$(sqlite3 "${db_file}" "SELECT value FROM ItemTable WHERE value IS NOT NULL LIMIT ${VALIDATION_SAMPLE_SIZE};" 2>/dev/null)

    local invalid_count=0
    local total_count=0

    # Validate each value
    while IFS= read -r value; do
        if [[ -n "${value}" ]]; then
            ((total_count++))

            # Check for suspicious patterns
            if [[ "${value}" =~ (null|undefined|NaN|<script|javascript:) ]]; then
                ((invalid_count++))
                continue
            fi

            # Validate JSON values
            if [[ "${value}" =~ ^\{.*\}$ ]]; then
                if ! echo "${value}" | jq '.' >/dev/null 2>&1; then
                    ((invalid_count++))
                fi
            fi
        fi
    done <<< "${sample_records}"

    if [[ ${invalid_count} -gt 0 ]]; then
        local error_rate=$((invalid_count * 100 / total_count))
        if [[ ${error_rate} -gt 10 ]]; then
            log_error "值有效性错误率过高: ${error_rate}% (${invalid_count}/${total_count})"
            return 1
        else
            log_warn "发现无效值: ${error_rate}% (${invalid_count}/${total_count})"
            ((CONSISTENCY_STATS["warnings_generated"]++))
        fi
    fi

    log_debug "值有效性验证完成: ${total_count} 条记录，${invalid_count} 个错误"
    return 0
}

# Validate transformation accuracy
validate_transformation_accuracy() {
    local db_file="$1"
    local reference_data="$2"

    log_debug "验证转换准确性"

    if [[ -z "${reference_data}" ]]; then
        log_warn "没有参考数据，跳过转换准确性验证"
        return 0
    fi

    # Check if transformation patterns are properly applied
    local transformation_patterns=("machineId" "deviceId" "sqmId" "uuid" "session")
    local pattern_errors=0

    for pattern in "${transformation_patterns[@]}"; do
        # Check if old patterns still exist
        local old_pattern_count
        old_pattern_count=$(sqlite3 "${db_file}" "SELECT COUNT(*) FROM ItemTable WHERE key LIKE '%${pattern}%' OR value LIKE '%old_${pattern}%';" 2>/dev/null || echo "0")

        if [[ ${old_pattern_count} -gt 0 ]]; then
            log_warn "发现未转换的 ${pattern} 模式: ${old_pattern_count} 条记录"
            ((pattern_errors++))
        fi
    done

    if [[ ${pattern_errors} -gt 0 ]]; then
        log_error "转换准确性验证失败: ${pattern_errors} 个模式错误"
        return 1
    fi

    log_debug "转换准确性验证通过"
    return 0
}

# Generate consistency validation report
generate_consistency_report() {
    local db_file="$1"
    local report_file="${2:-consistency_report_$(get_timestamp).txt}"

    log_info "生成一致性验证报告: ${report_file}"

    # Perform quick validation for report
    local record_count
    record_count=$(sqlite3 "${db_file}" "SELECT COUNT(*) FROM ItemTable;" 2>/dev/null || echo "0")

    local table_count
    table_count=$(sqlite3 "${db_file}" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" 2>/dev/null || echo "0")

    local db_size
    db_size=$(stat -f%z "${db_file}" 2>/dev/null || stat -c%s "${db_file}" 2>/dev/null || echo "0")

    {
        echo "数据一致性验证报告"
        echo "生成时间: $(date)"
        echo "数据库文件: ${db_file}"
        echo "=========================="
        echo ""
        echo "基本信息:"
        echo "  记录数量: ${record_count}"
        echo "  表数量: ${table_count}"
        echo "  文件大小: ${db_size} 字节"
        echo ""
        echo "验证统计:"
        for stat_name in "${!CONSISTENCY_STATS[@]}"; do
            echo "  ${stat_name}: ${CONSISTENCY_STATS["${stat_name}"]}"
        done
        echo ""
        echo "支持的验证检查:"
        for check in "${VALIDATION_CHECKS[@]}"; do
            echo "  - ${check}"
        done
        echo ""
        echo "配置信息:"
        echo "  验证超时: ${CONSISTENCY_TIMEOUT} 秒"
        echo "  最大验证记录数: ${MAX_VALIDATION_RECORDS}"
        echo "  验证样本大小: ${VALIDATION_SAMPLE_SIZE}"

    } > "${report_file}"

    log_success "一致性验证报告已生成: ${report_file}"
}

# Compare database states (before/after migration)
compare_database_states() {
    local before_db="$1"
    local after_db="$2"
    local comparison_report="${3:-comparison_$(get_timestamp).txt}"

    log_info "比较数据库状态: ${before_db} vs ${after_db}"

    # Get statistics from both databases
    local before_count after_count
    before_count=$(sqlite3 "${before_db}" "SELECT COUNT(*) FROM ItemTable;" 2>/dev/null || echo "0")
    after_count=$(sqlite3 "${after_db}" "SELECT COUNT(*) FROM ItemTable;" 2>/dev/null || echo "0")

    local before_size after_size
    before_size=$(stat -f%z "${before_db}" 2>/dev/null || stat -c%s "${before_db}" 2>/dev/null || echo "0")
    after_size=$(stat -f%z "${after_db}" 2>/dev/null || stat -c%s "${after_db}" 2>/dev/null || echo "0")

    # Generate comparison report
    {
        echo "数据库状态比较报告"
        echo "生成时间: $(date)"
        echo "=========================="
        echo ""
        echo "迁移前数据库: ${before_db}"
        echo "  记录数量: ${before_count}"
        echo "  文件大小: ${before_size} 字节"
        echo ""
        echo "迁移后数据库: ${after_db}"
        echo "  记录数量: ${after_count}"
        echo "  文件大小: ${after_size} 字节"
        echo ""
        echo "变化统计:"
        echo "  记录数量变化: $((after_count - before_count))"
        echo "  文件大小变化: $((after_size - before_size)) 字节"

        if [[ ${after_count} -eq ${before_count} ]]; then
            echo "  状态: 记录数量保持一致"
        elif [[ ${after_count} -gt ${before_count} ]]; then
            echo "  状态: 记录数量增加"
        else
            echo "  状态: 记录数量减少"
        fi

    } > "${comparison_report}"

    log_success "数据库状态比较报告已生成: ${comparison_report}"
}

# Get consistency statistics
get_consistency_stats() {
    log_info "数据一致性验证统计信息:"
    for stat_name in "${!CONSISTENCY_STATS[@]}"; do
        log_info "  ${stat_name}: ${CONSISTENCY_STATS["${stat_name}"]}"
    done
}

# Test consistency validation
test_consistency_validation() {
    local test_db="${1:-test_consistency.db}"

    log_info "测试一致性验证功能: ${test_db}"

    # Create test database
    sqlite3 "${test_db}" "CREATE TABLE IF NOT EXISTS ItemTable (key TEXT PRIMARY KEY, value TEXT);" 2>/dev/null
    sqlite3 "${test_db}" "INSERT INTO ItemTable VALUES ('test.key.1', 'test_value_1');" 2>/dev/null
    sqlite3 "${test_db}" "INSERT INTO ItemTable VALUES ('test.key.2', '{\"test\": \"json_value\"}');" 2>/dev/null

    # Test validation
    if validate_migration_consistency "${test_db}" "basic"; then
        log_success "一致性验证功能测试通过"
        # Cleanup
        rm -f "${test_db}"
        return 0
    else
        log_error "一致性验证功能测试失败"
        rm -f "${test_db}"
        return 1
    fi
}

# Export consistency functions
export -f init_consistency validate_migration_consistency perform_full_validation
export -f perform_basic_validation perform_integrity_validation perform_transformation_validation
export -f perform_validation_check validate_database_integrity validate_record_count
export -f validate_data_format validate_key_uniqueness validate_value_validity
export -f validate_transformation_accuracy generate_consistency_report compare_database_states
export -f get_consistency_stats test_consistency_validation
export CONSISTENCY_STATS VALIDATION_CHECKS

log_debug "数据一致性验证模块已加载"
