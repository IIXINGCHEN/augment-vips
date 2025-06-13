#!/bin/bash
# transformation.sh
#
# Auto-fixed for readonly variable conflicts

# Prevent multiple loading
if [[ "${TRANSFORMATION_SH_LOADED:-}" == "true" ]]; then
    return 0
fi
if [[ -z "${TRANSFORMATION_SH_LOADED:-}" ]]; then
    readonly TRANSFORMATION_SH_LOADED="true"
fi

# core/transformation.sh
#
# Enterprise-grade data transformation module for VS Code database operations
# Production-ready with comprehensive ID generation, pattern matching and validation
# Supports complex transformation rules and secure ID generation

set -euo pipefail

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/security.sh"
source "$(dirname "${BASH_SOURCE[0]}")/validation.sh"
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/telemetry.sh"

# Transformation operation constants
if [[ -z "${TRANSFORMATION_TIMEOUT:-}" ]]; then
    readonly TRANSFORMATION_TIMEOUT=120
fi
if [[ -z "${MAX_TRANSFORMATION_RECORDS:-}" ]]; then
    readonly MAX_TRANSFORMATION_RECORDS=100000
fi
if [[ -z "${ID_CACHE_SIZE:-}" ]]; then
    readonly ID_CACHE_SIZE=1000
fi

# Transformation rule types
if [[ -z "${TRANSFORMATION_RULES:-}" ]]; then
    readonly TRANSFORMATION_RULES=(
        "machineId:hex64"
        "deviceId:uuid4"
        "sqmId:uuid4"
        "uuid:uuid4"
        "session:session_id"
        "installationId:uuid4"
        "userId:uuid4"
    )
fi

# Global transformation statistics
declare -A TRANSFORMATION_STATS=()
declare -A ID_CACHE=()

# Initialize transformation module
init_transformation() {
    log_info "初始化数据转换模块..."
    
    # Check required dependencies
    if ! is_command_available jq; then
        log_error "jq is required for JSON transformation"
        return 1
    fi
    
    # Verify telemetry module is loaded
    if ! declare -f generate_machine_id >/dev/null 2>&1; then
        log_error "Telemetry module not properly loaded"
        return 1
    fi
    
    # Initialize transformation statistics
    TRANSFORMATION_STATS["transformations_performed"]=0
    TRANSFORMATION_STATS["records_transformed"]=0
    TRANSFORMATION_STATS["ids_generated"]=0
    TRANSFORMATION_STATS["cache_hits"]=0
    TRANSFORMATION_STATS["errors_encountered"]=0
    
    audit_log "TRANSFORMATION_INIT" "数据转换模块已初始化"
    log_success "数据转换模块初始化完成"
}

# Transform extracted data using configured rules
transform_extracted_data() {
    local extracted_data="$1"
    local transformation_config="${2:-default}"
    local preserve_original="${3:-false}"
    
    log_info "转换提取的数据"
    
    # Validate input data
    if [[ -z "${extracted_data}" ]]; then
        log_error "没有提供要转换的数据"
        return 1
    fi
    
    # Load transformation configuration
    local transformation_rules
    transformation_rules=$(load_transformation_config "${transformation_config}")
    if [[ $? -ne 0 ]]; then
        log_error "加载转换配置失败"
        return 1
    fi
    
    # Process transformation
    local start_time=$(date +%s.%3N)
    local transformed_data=""
    local record_count=0
    local error_count=0
    
    # Transform each record
    while IFS= read -r record; do
        if [[ -n "${record}" ]]; then
            local transformed_record
            transformed_record=$(transform_single_record "${record}" "${transformation_rules}" "${preserve_original}")
            if [[ $? -eq 0 && -n "${transformed_record}" ]]; then
                transformed_data="${transformed_data}${transformed_record}\n"
                ((record_count++))
            else
                ((error_count++))
                log_warn "记录转换失败，跳过"
            fi
        fi
    done <<< "${extracted_data}"
    
    # Update statistics
    ((TRANSFORMATION_STATS["transformations_performed"]++))
    ((TRANSFORMATION_STATS["records_transformed"] += record_count))
    if [[ ${error_count} -gt 0 ]]; then
        ((TRANSFORMATION_STATS["errors_encountered"] += error_count))
    fi
    
    local end_time=$(date +%s.%3N)
    log_performance "data_transformation" "${start_time}" "${end_time}" "${record_count} records"
    
    audit_log "TRANSFORMATION_SUCCESS" "数据转换完成: ${record_count} 条记录, ${error_count} 个错误"
    log_success "转换了 ${record_count} 条记录，${error_count} 个错误"
    
    echo -e "${transformed_data}"
    return 0
}

# Transform a single record
transform_single_record() {
    local record="$1"
    local transformation_rules="$2"
    local preserve_original="$3"
    
    log_debug "转换单条记录"
    
    # Parse JSON record
    local key value
    key=$(echo "${record}" | jq -r '.key' 2>/dev/null)
    value=$(echo "${record}" | jq -r '.value' 2>/dev/null)
    
    if [[ -z "${key}" || "${key}" == "null" ]]; then
        log_warn "无效的记录格式，跳过转换"
        return 1
    fi
    
    # Store original values if needed
    local original_key="${key}"
    local original_value="${value}"
    
    # Transform key field
    local new_key
    new_key=$(transform_key_field "${key}" "${transformation_rules}")
    
    # Transform value field
    local new_value
    new_value=$(transform_value_field "${value}" "${transformation_rules}")
    
    # Create transformed record
    local transformed_record
    if [[ "${preserve_original}" == "true" ]]; then
        transformed_record=$(jq -n \
            --arg original_key "${original_key}" \
            --arg original_value "${original_value}" \
            --arg new_key "${new_key}" \
            --arg new_value "${new_value}" \
            '{
                original: {key: $original_key, value: $original_value},
                transformed: {key: $new_key, value: $new_value}
            }')
    else
        transformed_record=$(jq -n \
            --arg key "${new_key}" \
            --arg value "${new_value}" \
            '{key: $key, value: $value}')
    fi
    
    echo "${transformed_record}"
    return 0
}

# Transform key field using transformation rules
transform_key_field() {
    local key="$1"
    local transformation_rules="$2"
    
    log_debug "转换key字段: ${key}"
    
    local new_key="${key}"
    
    # Apply transformation rules to key
    while IFS=':' read -r pattern rule_type; do
        if [[ "${key}" == *"${pattern}"* ]]; then
            local new_id
            new_id=$(generate_id_by_type "${rule_type}" "${pattern}")
            if [[ $? -eq 0 && -n "${new_id}" ]]; then
                # Replace pattern in key with new ID
                new_key=$(echo "${new_key}" | sed "s/${pattern}[^[:space:][:punct:]]*/${new_id}/g")
                log_debug "应用转换规则 ${pattern}:${rule_type} -> ${new_id}"
            fi
        fi
    done <<< "${transformation_rules}"
    
    echo "${new_key}"
}

# Transform value field (JSON processing)
transform_value_field() {
    local value="$1"
    local transformation_rules="$2"
    
    log_debug "转换value字段"
    
    # Check if value is valid JSON
    if [[ "${value}" == "null" || ! "${value}" =~ ^\{.*\}$ ]]; then
        echo "${value}"
        return 0
    fi
    
    local new_value="${value}"
    
    # Apply transformation rules to JSON fields
    while IFS=':' read -r pattern rule_type; do
        # Check if JSON contains the pattern as a field
        if echo "${value}" | jq -e ".\"${pattern}\"" >/dev/null 2>&1; then
            local new_id
            new_id=$(generate_id_by_type "${rule_type}" "${pattern}")
            if [[ $? -eq 0 && -n "${new_id}" ]]; then
                new_value=$(echo "${new_value}" | jq --arg new_id "${new_id}" ".\"${pattern}\" = \$new_id" 2>/dev/null)
                log_debug "转换JSON字段 ${pattern} -> ${new_id}"
            fi
        fi
        
        # Also check for nested patterns
        if echo "${value}" | jq -r 'paths(scalars) as $p | $p | join(".")' 2>/dev/null | grep -q "${pattern}"; then
            local new_id
            new_id=$(generate_id_by_type "${rule_type}" "${pattern}")
            if [[ $? -eq 0 && -n "${new_id}" ]]; then
                # Handle nested field transformation
                new_value=$(transform_nested_json_field "${new_value}" "${pattern}" "${new_id}")
            fi
        fi
    done <<< "${transformation_rules}"
    
    echo "${new_value}"
}

# Generate ID by type with caching
generate_id_by_type() {
    local rule_type="$1"
    local pattern="$2"
    
    # Check cache first
    local cache_key="${rule_type}:${pattern}"
    if [[ -n "${ID_CACHE["${cache_key}"]:-}" ]]; then
        ((TRANSFORMATION_STATS["cache_hits"]++))
        echo "${ID_CACHE["${cache_key}"]}"
        return 0
    fi
    
    local new_id=""
    
    case "${rule_type}" in
        "hex64")
            new_id=$(generate_machine_id 2>/dev/null || generate_fallback_hex64)
            ;;
        "uuid4")
            new_id=$(generate_uuid_v4 2>/dev/null || generate_fallback_uuid)
            ;;
        "session_id")
            new_id="session_$(date +%s)_$(generate_random_hex 8)"
            ;;
        "timestamp_id")
            new_id="id_$(date +%s%3N)"
            ;;
        "custom")
            new_id=$(generate_custom_id "${pattern}")
            ;;
        *)
            log_warn "未知的ID类型: ${rule_type}，使用UUID4"
            new_id=$(generate_uuid_v4 2>/dev/null || generate_fallback_uuid)
            ;;
    esac
    
    if [[ -n "${new_id}" ]]; then
        # Cache the generated ID
        if [[ ${#ID_CACHE[@]} -lt ${ID_CACHE_SIZE} ]]; then
            ID_CACHE["${cache_key}"]="${new_id}"
        fi
        
        ((TRANSFORMATION_STATS["ids_generated"]++))
        echo "${new_id}"
        return 0
    else
        log_error "ID生成失败: ${rule_type}"
        return 1
    fi
}

# Generate fallback hex64 ID
generate_fallback_hex64() {
    local hex_chars="0123456789abcdef"
    local result=""
    
    for ((i=0; i<64; i++)); do
        result="${result}${hex_chars:$((RANDOM % 16)):1}"
    done
    
    echo "${result}"
}

# Generate fallback UUID
generate_fallback_uuid() {
    local hex_chars="0123456789abcdef"
    local uuid=""
    
    # Generate UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
    for i in {1..8}; do
        uuid="${uuid}${hex_chars:$((RANDOM % 16)):1}"
    done
    uuid="${uuid}-"
    
    for i in {1..4}; do
        uuid="${uuid}${hex_chars:$((RANDOM % 16)):1}"
    done
    uuid="${uuid}-4"
    
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
    
    echo "${uuid}"
}

# Generate random hex string
generate_random_hex() {
    local length="$1"
    local hex_chars="0123456789abcdef"
    local result=""
    
    for ((i=0; i<length; i++)); do
        result="${result}${hex_chars:$((RANDOM % 16)):1}"
    done
    
    echo "${result}"
}

# Load transformation configuration
load_transformation_config() {
    local config_name="$1"
    
    if [[ "${config_name}" == "default" ]]; then
        # Use default transformation rules
        printf '%s\n' "${TRANSFORMATION_RULES[@]}"
    else
        # Load from configuration file or custom rules
        log_warn "自定义转换配置暂未实现，使用默认规则"
        printf '%s\n' "${TRANSFORMATION_RULES[@]}"
    fi
}

# Transform nested JSON field
transform_nested_json_field() {
    local json_value="$1"
    local pattern="$2"
    local new_id="$3"

    log_debug "转换嵌套JSON字段: ${pattern}"

    # Use jq to recursively find and replace pattern in nested objects
    echo "${json_value}" | jq --arg pattern "${pattern}" --arg new_id "${new_id}" '
        def transform_recursive:
            if type == "object" then
                with_entries(
                    if .key | contains($pattern) then
                        .value = $new_id
                    else
                        .value |= transform_recursive
                    end
                )
            elif type == "array" then
                map(transform_recursive)
            else
                .
            end;
        transform_recursive
    ' 2>/dev/null || echo "${json_value}"
}

# Generate custom ID based on pattern
generate_custom_id() {
    local pattern="$1"

    case "${pattern}" in
        *"machine"*|*"Machine"*)
            generate_machine_id 2>/dev/null || generate_fallback_hex64
            ;;
        *"device"*|*"Device"*)
            generate_uuid_v4 2>/dev/null || generate_fallback_uuid
            ;;
        *"session"*|*"Session"*)
            echo "session_$(date +%s)_$(generate_random_hex 8)"
            ;;
        *"install"*|*"Install"*)
            generate_uuid_v4 2>/dev/null || generate_fallback_uuid
            ;;
        *)
            echo "custom_${pattern}_$(date +%s)"
            ;;
    esac
}

# Validate transformation result
validate_transformation_result() {
    local original_data="$1"
    local transformed_data="$2"

    log_debug "验证转换结果"

    # Count original and transformed records
    local original_count=0
    local transformed_count=0

    if [[ -n "${original_data}" ]]; then
        original_count=$(echo "${original_data}" | wc -l)
    fi

    if [[ -n "${transformed_data}" ]]; then
        transformed_count=$(echo "${transformed_data}" | wc -l)
    fi

    # Check record count consistency
    if [[ ${original_count} -ne ${transformed_count} ]]; then
        log_warn "记录数量不一致: 原始 ${original_count}, 转换后 ${transformed_count}"
    fi

    # Validate JSON format of transformed data
    local json_errors=0
    while IFS= read -r record; do
        if [[ -n "${record}" ]]; then
            if ! echo "${record}" | jq '.' >/dev/null 2>&1; then
                ((json_errors++))
            fi
        fi
    done <<< "${transformed_data}"

    if [[ ${json_errors} -gt 0 ]]; then
        log_error "发现 ${json_errors} 个JSON格式错误"
        return 1
    fi

    log_debug "转换结果验证通过"
    return 0
}

# Clear transformation cache
clear_transformation_cache() {
    log_debug "清理转换缓存"

    local cache_size=${#ID_CACHE[@]}
    ID_CACHE=()

    log_debug "已清理 ${cache_size} 个缓存项"
}

# Get transformation statistics
get_transformation_stats() {
    log_info "数据转换统计信息:"
    for stat_name in "${!TRANSFORMATION_STATS[@]}"; do
        log_info "  ${stat_name}: ${TRANSFORMATION_STATS["${stat_name}"]}"
    done

    log_info "缓存统计:"
    log_info "  缓存项数量: ${#ID_CACHE[@]}"
    log_info "  缓存大小限制: ${ID_CACHE_SIZE}"
}

# Generate transformation report
generate_transformation_report() {
    local report_file="${1:-transformation_report_$(get_timestamp).txt}"

    log_info "生成转换报告: ${report_file}"

    {
        echo "数据转换操作报告"
        echo "生成时间: $(date)"
        echo "=========================="
        echo ""
        echo "统计信息:"
        for stat_name in "${!TRANSFORMATION_STATS[@]}"; do
            echo "  ${stat_name}: ${TRANSFORMATION_STATS["${stat_name}"]}"
        done
        echo ""
        echo "缓存信息:"
        echo "  缓存项数量: ${#ID_CACHE[@]}"
        echo "  缓存大小限制: ${ID_CACHE_SIZE}"
        echo ""
        echo "配置信息:"
        echo "  转换超时: ${TRANSFORMATION_TIMEOUT} 秒"
        echo "  最大转换记录数: ${MAX_TRANSFORMATION_RECORDS}"
        echo ""
        echo "支持的转换规则:"
        for rule in "${TRANSFORMATION_RULES[@]}"; do
            echo "  - ${rule}"
        done

    } > "${report_file}"

    log_success "转换报告已生成: ${report_file}"
}

# Preview transformation rules
preview_transformation_rules() {
    local sample_data="$1"

    log_info "预览转换规则效果"

    if [[ -z "${sample_data}" ]]; then
        # Create sample data for preview
        sample_data='{"key":"test.machineId.12345","value":"{\"machineId\":\"old_machine_id\",\"deviceId\":\"old_device_id\"}"}'
    fi

    log_info "样本数据:"
    echo "${sample_data}" | jq '.' 2>/dev/null || echo "${sample_data}"

    log_info "转换规则预览:"
    for rule in "${TRANSFORMATION_RULES[@]}"; do
        IFS=':' read -r pattern rule_type <<< "${rule}"
        local sample_id
        sample_id=$(generate_id_by_type "${rule_type}" "${pattern}")
        log_info "  ${pattern} (${rule_type}) -> ${sample_id}"
    done

    # Show actual transformation
    local transformed_sample
    transformed_sample=$(transform_single_record "${sample_data}" "$(printf '%s\n' "${TRANSFORMATION_RULES[@]}")" "false")

    log_info "转换结果:"
    echo "${transformed_sample}" | jq '.' 2>/dev/null || echo "${transformed_sample}"
}

# Export transformation functions
export -f init_transformation transform_extracted_data transform_single_record
export -f transform_key_field transform_value_field generate_id_by_type
export -f transform_nested_json_field generate_custom_id validate_transformation_result
export -f clear_transformation_cache get_transformation_stats generate_transformation_report
export -f preview_transformation_rules generate_fallback_hex64 generate_fallback_uuid
export -f generate_random_hex load_transformation_config
export TRANSFORMATION_STATS ID_CACHE TRANSFORMATION_RULES

log_debug "数据转换模块已加载"
