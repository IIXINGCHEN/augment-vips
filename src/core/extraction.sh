#!/bin/bash
# extraction.sh
#
# Auto-fixed for readonly variable conflicts

# Prevent multiple loading
if [[ "${EXTRACTION_SH_LOADED:-}" == "true" ]]; then
    return 0
fi
if [[ -z "${EXTRACTION_SH_LOADED:-}" ]]; then
    readonly EXTRACTION_SH_LOADED="true"
fi

# core/extraction.sh
#
# Enterprise-grade data extraction module for VS Code database operations
# Production-ready with comprehensive safety, validation and audit trails
# Supports complex SQL queries, pattern matching, and data preview

set -euo pipefail

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/security.sh"
source "$(dirname "${BASH_SOURCE[0]}")/validation.sh"
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

# Extraction operation constants
if [[ -z "${EXTRACTION_TIMEOUT:-}" ]]; then
    readonly EXTRACTION_TIMEOUT=60
fi
if [[ -z "${MAX_EXTRACTION_RECORDS:-}" ]]; then
    readonly MAX_EXTRACTION_RECORDS=50000
fi
if [[ -z "${PREVIEW_LIMIT:-}" ]]; then
    readonly PREVIEW_LIMIT=10
fi

# Extraction patterns for different data types
if [[ -z "${EXTRACTION_PATTERNS:-}" ]]; then
    readonly EXTRACTION_PATTERNS=(
        "augment"
        "telemetry"
        "machineId"
        "deviceId"
        "sqmId"
        "uuid"
        "session"
    )
fi

# Global extraction statistics
declare -A EXTRACTION_STATS=()

# Initialize extraction module
init_extraction() {
    log_info "初始化数据提取模块..."
    
    # Check required dependencies
    if ! is_command_available sqlite3; then
        log_error "SQLite3 is required for extraction operations"
        return 1
    fi
    
    if ! is_command_available jq; then
        log_error "jq is required for JSON processing in extraction"
        return 1
    fi
    
    # Initialize extraction statistics
    EXTRACTION_STATS["extractions_performed"]=0
    EXTRACTION_STATS["records_extracted"]=0
    EXTRACTION_STATS["queries_executed"]=0
    EXTRACTION_STATS["errors_encountered"]=0
    
    audit_log "EXTRACTION_INIT" "数据提取模块已初始化"
    log_success "数据提取模块初始化完成"
}

# Extract data based on patterns
extract_by_patterns() {
    local db_file="$1"
    local patterns="${2:-default}"
    local output_format="${3:-json}"
    local preview_only="${4:-false}"
    
    log_info "基于模式提取数据: ${db_file}"
    
    # Validate database file
    if ! validate_database_file "${db_file}"; then
        log_error "数据库验证失败: ${db_file}"
        return 1
    fi
    
    # Authorize extraction operation
    if ! authorize_operation "migration_extract" "${db_file}"; then
        log_error "数据提取操作未授权"
        return 1
    fi
    
    # Build extraction query
    local extraction_query
    extraction_query=$(build_pattern_query "${patterns}" "${preview_only}")
    if [[ -z "${extraction_query}" ]]; then
        log_error "构建提取查询失败"
        return 1
    fi
    
    # Execute extraction
    local start_time=$(date +%s.%3N)
    local extracted_data
    
    extracted_data=$(execute_extraction_query "${db_file}" "${extraction_query}" "${output_format}")
    if [[ $? -eq 0 ]]; then
        ((EXTRACTION_STATS["extractions_performed"]++))
        ((EXTRACTION_STATS["queries_executed"]++))
        
        local end_time=$(date +%s.%3N)
        log_performance "extraction_by_patterns" "${start_time}" "${end_time}" "${db_file}"
        
        audit_log "EXTRACTION_SUCCESS" "模式提取完成: ${db_file}, 模式: ${patterns}"
        echo "${extracted_data}"
        return 0
    else
        ((EXTRACTION_STATS["errors_encountered"]++))
        log_error "数据提取失败: ${db_file}"
        return 1
    fi
}

# Extract data with custom SQL query
extract_by_query() {
    local db_file="$1"
    local custom_query="$2"
    local output_format="${3:-json}"
    local validate_query="${4:-true}"
    
    log_info "使用自定义查询提取数据: ${db_file}"
    
    # Validate database file
    if ! validate_database_file "${db_file}"; then
        log_error "数据库验证失败: ${db_file}"
        return 1
    fi
    
    # Validate custom query if requested
    if [[ "${validate_query}" == "true" ]]; then
        if ! validate_extraction_query "${custom_query}"; then
            log_error "自定义查询验证失败"
            return 1
        fi
    fi
    
    # Authorize extraction operation
    if ! authorize_operation "migration_extract" "${db_file}"; then
        log_error "数据提取操作未授权"
        return 1
    fi
    
    # Execute extraction
    local start_time=$(date +%s.%3N)
    local extracted_data
    
    extracted_data=$(execute_extraction_query "${db_file}" "${custom_query}" "${output_format}")
    if [[ $? -eq 0 ]]; then
        ((EXTRACTION_STATS["extractions_performed"]++))
        ((EXTRACTION_STATS["queries_executed"]++))
        
        local end_time=$(date +%s.%3N)
        log_performance "extraction_by_query" "${start_time}" "${end_time}" "${db_file}"
        
        audit_log "EXTRACTION_SUCCESS" "自定义查询提取完成: ${db_file}"
        echo "${extracted_data}"
        return 0
    else
        ((EXTRACTION_STATS["errors_encountered"]++))
        log_error "自定义查询提取失败: ${db_file}"
        return 1
    fi
}

# Build pattern-based extraction query
build_pattern_query() {
    local patterns="$1"
    local preview_only="$2"
    
    log_debug "构建模式查询: ${patterns}"
    
    local where_conditions=""
    local pattern_list
    
    # Handle different pattern inputs
    if [[ "${patterns}" == "default" ]]; then
        pattern_list=("${EXTRACTION_PATTERNS[@]}")
    else
        IFS=',' read -ra pattern_list <<< "${patterns}"
    fi
    
    # Build WHERE conditions
    for pattern in "${pattern_list[@]}"; do
        pattern=$(echo "${pattern}" | xargs)  # Trim whitespace
        if [[ -n "${pattern}" ]]; then
            if [[ -n "${where_conditions}" ]]; then
                where_conditions="${where_conditions} OR "
            fi
            where_conditions="${where_conditions}key LIKE '%${pattern}%'"
        fi
    done
    
    if [[ -z "${where_conditions}" ]]; then
        log_error "没有有效的提取模式"
        return 1
    fi
    
    # Build complete query
    local query="SELECT json_object('key', key, 'value', value) FROM ItemTable WHERE ${where_conditions}"
    
    # Add limit for preview
    if [[ "${preview_only}" == "true" ]]; then
        query="${query} LIMIT ${PREVIEW_LIMIT}"
    fi
    
    query="${query};"
    
    log_debug "构建的查询: ${query}"
    echo "${query}"
}

# Execute extraction query
execute_extraction_query() {
    local db_file="$1"
    local query="$2"
    local output_format="$3"
    
    log_debug "执行提取查询"
    
    # Execute query with timeout
    local query_result
    query_result=$(timeout "${EXTRACTION_TIMEOUT}" sqlite3 "${db_file}" "${query}" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        log_error "查询执行失败或超时"
        return 1
    fi
    
    # Count extracted records
    local record_count=0
    if [[ -n "${query_result}" ]]; then
        record_count=$(echo "${query_result}" | wc -l)
    fi
    
    ((EXTRACTION_STATS["records_extracted"] += record_count))
    log_debug "提取了 ${record_count} 条记录"
    
    # Check record limit
    if [[ ${record_count} -gt ${MAX_EXTRACTION_RECORDS} ]]; then
        log_warn "提取记录数 (${record_count}) 超过限制 (${MAX_EXTRACTION_RECORDS})"
    fi
    
    # Format output
    case "${output_format}" in
        "json")
            echo "${query_result}"
            ;;
        "csv")
            format_as_csv "${query_result}"
            ;;
        "raw")
            echo "${query_result}"
            ;;
        *)
            log_error "不支持的输出格式: ${output_format}"
            return 1
            ;;
    esac
    
    return 0
}

# Validate extraction query for safety
validate_extraction_query() {
    local query="$1"
    
    log_debug "验证提取查询安全性"
    
    # Convert to lowercase for checking
    local lower_query=$(echo "${query}" | tr '[:upper:]' '[:lower:]')
    
    # Check for dangerous operations
    if [[ "${lower_query}" =~ (drop|delete|update|insert|alter|create|truncate|pragma) ]]; then
        log_error "查询包含危险操作: ${query}"
        return 1
    fi
    
    # Must be a SELECT query
    if [[ ! "${lower_query}" =~ ^[[:space:]]*select ]]; then
        log_error "只允许SELECT查询: ${query}"
        return 1
    fi
    
    # Check for suspicious patterns
    if [[ "${lower_query}" =~ (;[[:space:]]*[^[:space:]]) ]]; then
        log_error "查询可能包含多个语句: ${query}"
        return 1
    fi
    
    return 0
}

# Preview extraction results
preview_extraction() {
    local db_file="$1"
    local patterns="${2:-default}"
    
    log_info "预览提取结果: ${db_file}"
    
    local preview_data
    preview_data=$(extract_by_patterns "${db_file}" "${patterns}" "json" "true")
    if [[ $? -eq 0 && -n "${preview_data}" ]]; then
        log_info "提取预览 (前 ${PREVIEW_LIMIT} 条记录):"
        echo "${preview_data}" | head -n "${PREVIEW_LIMIT}" | while IFS= read -r line; do
            if [[ -n "${line}" ]]; then
                local key
                key=$(echo "${line}" | jq -r '.key' 2>/dev/null)
                log_info "  Key: ${key}"
            fi
        done
        return 0
    else
        log_info "没有找到匹配的记录"
        return 1
    fi
}

# Format output as CSV
format_as_csv() {
    local json_data="$1"

    log_debug "格式化为CSV输出"

    # Print CSV header
    echo "key,value"

    # Process each JSON line
    while IFS= read -r line; do
        if [[ -n "${line}" ]]; then
            local key value
            key=$(echo "${line}" | jq -r '.key' 2>/dev/null)
            value=$(echo "${line}" | jq -r '.value' 2>/dev/null)

            # Escape CSV special characters
            key=$(echo "${key}" | sed 's/"/""/g')
            value=$(echo "${value}" | sed 's/"/""/g')

            echo "\"${key}\",\"${value}\""
        fi
    done <<< "${json_data}"
}

# Get extraction statistics
get_extraction_stats() {
    log_info "数据提取统计信息:"
    for stat_name in "${!EXTRACTION_STATS[@]}"; do
        log_info "  ${stat_name}: ${EXTRACTION_STATS["${stat_name}"]}"
    done
}

# Generate extraction report
generate_extraction_report() {
    local report_file="${1:-extraction_report_$(get_timestamp).txt}"

    log_info "生成提取报告: ${report_file}"

    {
        echo "数据提取操作报告"
        echo "生成时间: $(date)"
        echo "=========================="
        echo ""
        echo "统计信息:"
        for stat_name in "${!EXTRACTION_STATS[@]}"; do
            echo "  ${stat_name}: ${EXTRACTION_STATS["${stat_name}"]}"
        done
        echo ""
        echo "配置信息:"
        echo "  提取超时: ${EXTRACTION_TIMEOUT} 秒"
        echo "  最大提取记录数: ${MAX_EXTRACTION_RECORDS}"
        echo "  预览限制: ${PREVIEW_LIMIT} 条记录"
        echo ""
        echo "支持的提取模式:"
        for pattern in "${EXTRACTION_PATTERNS[@]}"; do
            echo "  - ${pattern}"
        done

    } > "${report_file}"

    log_success "提取报告已生成: ${report_file}"
}

# Export extraction functions
export -f init_extraction extract_by_patterns extract_by_query
export -f build_pattern_query execute_extraction_query validate_extraction_query
export -f preview_extraction format_as_csv get_extraction_stats generate_extraction_report
export EXTRACTION_STATS EXTRACTION_PATTERNS

log_debug "数据提取模块已加载"
