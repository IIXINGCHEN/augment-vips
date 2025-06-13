#!/bin/bash
# transformation_rules.sh
#
# Auto-fixed for readonly variable conflicts

# Prevent multiple loading
if [[ "${TRANSFORMATION_RULES_SH_LOADED:-}" == "true" ]]; then
    return 0
fi
if [[ -z "${TRANSFORMATION_RULES_SH_LOADED:-}" ]]; then
    readonly TRANSFORMATION_RULES_SH_LOADED="true"
fi

# core/transformation_rules.sh
#
# Enterprise-grade transformation rules engine for VS Code database operations
# Production-ready with regex support, conditional logic and rule validation
# Supports complex pattern matching and transformation previews

set -euo pipefail

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/security.sh"
source "$(dirname "${BASH_SOURCE[0]}")/validation.sh"
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

# Rule engine constants
if [[ -z "${RULES_CONFIG_FILE:-}" ]]; then
    readonly RULES_CONFIG_FILE="config/transformation_rules.json"
fi
if [[ -z "${MAX_RULES_PER_SET:-}" ]]; then
    readonly MAX_RULES_PER_SET=100
fi
if [[ -z "${RULE_VALIDATION_TIMEOUT:-}" ]]; then
    readonly RULE_VALIDATION_TIMEOUT=10
fi

# Rule types and their patterns
declare -A RULE_PATTERNS=(
    ["exact_match"]="^exact:"
    ["regex_match"]="^regex:"
    ["contains_match"]="^contains:"
    ["starts_with"]="^starts:"
    ["ends_with"]="^ends:"
    ["json_path"]="^json:"
)

# Global rule engine statistics
declare -A RULE_STATS=()

# Initialize transformation rules engine
init_transformation_rules() {
    log_info "初始化转换规则引擎..."
    
    # Check required dependencies
    if ! is_command_available jq; then
        log_error "jq is required for rule processing"
        return 1
    fi
    
    # Initialize rule statistics
    RULE_STATS["rules_loaded"]=0
    RULE_STATS["rules_applied"]=0
    RULE_STATS["rules_matched"]=0
    RULE_STATS["rules_failed"]=0
    
    # Create default rules configuration if not exists
    if [[ ! -f "${RULES_CONFIG_FILE}" ]]; then
        create_default_rules_config
    fi
    
    audit_log "RULES_INIT" "转换规则引擎已初始化"
    log_success "转换规则引擎初始化完成"
}

# Create default transformation rules configuration
create_default_rules_config() {
    log_info "创建默认转换规则配置"
    
    # Create config directory if not exists
    mkdir -p "$(dirname "${RULES_CONFIG_FILE}")"
    
    # Generate default rules configuration
    cat > "${RULES_CONFIG_FILE}" << 'EOF'
{
  "version": "1.0",
  "description": "Default transformation rules for VS Code data migration",
  "rule_sets": {
    "default": {
      "description": "Default ID transformation rules",
      "enabled": true,
      "rules": [
        {
          "name": "machine_id_transformation",
          "pattern": "contains:machineId",
          "action": "replace_id",
          "id_type": "hex64",
          "target": "both",
          "enabled": true
        },
        {
          "name": "device_id_transformation", 
          "pattern": "contains:deviceId",
          "action": "replace_id",
          "id_type": "uuid4",
          "target": "both",
          "enabled": true
        },
        {
          "name": "sqm_id_transformation",
          "pattern": "contains:sqmId",
          "action": "replace_id", 
          "id_type": "uuid4",
          "target": "both",
          "enabled": true
        },
        {
          "name": "uuid_transformation",
          "pattern": "regex:.*[Uu]uid.*",
          "action": "replace_id",
          "id_type": "uuid4", 
          "target": "both",
          "enabled": true
        },
        {
          "name": "session_transformation",
          "pattern": "contains:session",
          "action": "replace_id",
          "id_type": "session_id",
          "target": "both",
          "enabled": true
        }
      ]
    },
    "telemetry": {
      "description": "Telemetry-specific transformation rules",
      "enabled": true,
      "rules": [
        {
          "name": "telemetry_machine_id",
          "pattern": "json:telemetry.machineId",
          "action": "replace_id",
          "id_type": "hex64",
          "target": "value",
          "enabled": true
        },
        {
          "name": "telemetry_device_id",
          "pattern": "json:telemetry.devDeviceId",
          "action": "replace_id",
          "id_type": "uuid4",
          "target": "value",
          "enabled": true
        }
      ]
    }
  }
}
EOF
    
    log_success "默认转换规则配置已创建: ${RULES_CONFIG_FILE}"
}

# Load transformation rules from configuration
load_transformation_rules() {
    local rule_set_name="${1:-default}"
    
    log_debug "加载转换规则集: ${rule_set_name}"
    
    # Validate configuration file
    if [[ ! -f "${RULES_CONFIG_FILE}" ]]; then
        log_error "转换规则配置文件不存在: ${RULES_CONFIG_FILE}"
        return 1
    fi
    
    # Validate JSON format
    if ! jq '.' "${RULES_CONFIG_FILE}" >/dev/null 2>&1; then
        log_error "转换规则配置文件格式无效"
        return 1
    fi
    
    # Extract rule set
    local rule_set
    rule_set=$(jq -r ".rule_sets.\"${rule_set_name}\"" "${RULES_CONFIG_FILE}" 2>/dev/null)
    if [[ "${rule_set}" == "null" ]]; then
        log_error "规则集不存在: ${rule_set_name}"
        return 1
    fi
    
    # Check if rule set is enabled
    local enabled
    enabled=$(echo "${rule_set}" | jq -r '.enabled' 2>/dev/null)
    if [[ "${enabled}" != "true" ]]; then
        log_warn "规则集已禁用: ${rule_set_name}"
        return 1
    fi
    
    # Extract and validate rules
    local rules
    rules=$(echo "${rule_set}" | jq -r '.rules[]' 2>/dev/null)
    if [[ -z "${rules}" ]]; then
        log_warn "规则集为空: ${rule_set_name}"
        return 1
    fi
    
    local rule_count=0
    while IFS= read -r rule; do
        if [[ -n "${rule}" ]]; then
            if validate_transformation_rule "${rule}"; then
                ((rule_count++))
            fi
        fi
    done <<< "${rules}"
    
    ((RULE_STATS["rules_loaded"] += rule_count))
    log_debug "加载了 ${rule_count} 条转换规则"
    
    echo "${rules}"
    return 0
}

# Validate a single transformation rule
validate_transformation_rule() {
    local rule="$1"
    
    # Check required fields
    local name pattern action enabled
    name=$(echo "${rule}" | jq -r '.name' 2>/dev/null)
    pattern=$(echo "${rule}" | jq -r '.pattern' 2>/dev/null)
    action=$(echo "${rule}" | jq -r '.action' 2>/dev/null)
    enabled=$(echo "${rule}" | jq -r '.enabled' 2>/dev/null)
    
    if [[ "${name}" == "null" || "${pattern}" == "null" || "${action}" == "null" ]]; then
        log_warn "规则缺少必需字段: ${rule}"
        return 1
    fi
    
    # Check if rule is enabled
    if [[ "${enabled}" != "true" ]]; then
        log_debug "规则已禁用: ${name}"
        return 1
    fi
    
    # Validate pattern format
    if ! validate_rule_pattern "${pattern}"; then
        log_warn "规则模式无效: ${pattern}"
        return 1
    fi
    
    # Validate action
    if ! validate_rule_action "${action}"; then
        log_warn "规则动作无效: ${action}"
        return 1
    fi
    
    return 0
}

# Validate rule pattern
validate_rule_pattern() {
    local pattern="$1"
    
    # Check if pattern matches known types
    for pattern_type in "${!RULE_PATTERNS[@]}"; do
        if [[ "${pattern}" =~ ${RULE_PATTERNS["${pattern_type}"]} ]]; then
            return 0
        fi
    done
    
    log_warn "未知的模式类型: ${pattern}"
    return 1
}

# Validate rule action
validate_rule_action() {
    local action="$1"
    
    case "${action}" in
        "replace_id"|"transform_value"|"remove_field"|"add_field"|"modify_key")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Apply transformation rules to a record
apply_transformation_rules() {
    local record="$1"
    local rule_set_name="${2:-default}"
    
    log_debug "应用转换规则到记录"
    
    # Load transformation rules
    local rules
    rules=$(load_transformation_rules "${rule_set_name}")
    if [[ $? -ne 0 || -z "${rules}" ]]; then
        log_error "加载转换规则失败"
        return 1
    fi
    
    local transformed_record="${record}"
    local rules_applied=0
    
    # Apply each rule
    while IFS= read -r rule; do
        if [[ -n "${rule}" ]]; then
            local rule_result
            rule_result=$(apply_single_rule "${transformed_record}" "${rule}")
            if [[ $? -eq 0 ]]; then
                transformed_record="${rule_result}"
                ((rules_applied++))
                ((RULE_STATS["rules_applied"]++))
            fi
        fi
    done <<< "${rules}"
    
    log_debug "应用了 ${rules_applied} 条规则"
    echo "${transformed_record}"
    return 0
}

# Apply a single transformation rule
apply_single_rule() {
    local record="$1"
    local rule="$2"
    
    # Extract rule components
    local name pattern action id_type target
    name=$(echo "${rule}" | jq -r '.name' 2>/dev/null)
    pattern=$(echo "${rule}" | jq -r '.pattern' 2>/dev/null)
    action=$(echo "${rule}" | jq -r '.action' 2>/dev/null)
    id_type=$(echo "${rule}" | jq -r '.id_type // "uuid4"' 2>/dev/null)
    target=$(echo "${rule}" | jq -r '.target // "both"' 2>/dev/null)
    
    log_debug "应用规则: ${name}"
    
    # Check if pattern matches
    if ! check_pattern_match "${record}" "${pattern}"; then
        return 1
    fi
    
    ((RULE_STATS["rules_matched"]++))
    
    # Apply action based on type
    case "${action}" in
        "replace_id")
            apply_replace_id_action "${record}" "${pattern}" "${id_type}" "${target}"
            ;;
        "transform_value")
            apply_transform_value_action "${record}" "${pattern}" "${rule}"
            ;;
        *)
            log_warn "不支持的规则动作: ${action}"
            return 1
            ;;
    esac
}

# Check if pattern matches record
check_pattern_match() {
    local record="$1"
    local pattern="$2"
    
    # Extract pattern type and value
    local pattern_type pattern_value
    IFS=':' read -r pattern_type pattern_value <<< "${pattern}"
    
    # Get record key and value
    local key value
    key=$(echo "${record}" | jq -r '.key' 2>/dev/null)
    value=$(echo "${record}" | jq -r '.value' 2>/dev/null)
    
    case "${pattern_type}" in
        "exact")
            [[ "${key}" == "${pattern_value}" ]]
            ;;
        "contains")
            [[ "${key}" == *"${pattern_value}"* ]] || [[ "${value}" == *"${pattern_value}"* ]]
            ;;
        "starts")
            [[ "${key}" == "${pattern_value}"* ]]
            ;;
        "ends")
            [[ "${key}" == *"${pattern_value}" ]]
            ;;
        "regex")
            [[ "${key}" =~ ${pattern_value} ]] || [[ "${value}" =~ ${pattern_value} ]]
            ;;
        "json")
            # Check if JSON path exists in value
            if [[ "${value}" != "null" && "${value}" =~ ^\{.*\}$ ]]; then
                echo "${value}" | jq -e ".\"${pattern_value}\"" >/dev/null 2>&1
            else
                return 1
            fi
            ;;
        *)
            return 1
            ;;
    esac
}

# Apply replace ID action
apply_replace_id_action() {
    local record="$1"
    local pattern="$2"
    local id_type="$3"
    local target="$4"
    
    # Source transformation module for ID generation
    if [[ -f "$(dirname "${BASH_SOURCE[0]}")/transformation.sh" ]]; then
        source "$(dirname "${BASH_SOURCE[0]}")/transformation.sh"
    fi
    
    # Generate new ID
    local new_id
    new_id=$(generate_id_by_type "${id_type}" "rule_based" 2>/dev/null)
    if [[ $? -ne 0 || -z "${new_id}" ]]; then
        log_error "ID生成失败: ${id_type}"
        return 1
    fi
    
    # Apply replacement based on target
    case "${target}" in
        "key")
            apply_key_replacement "${record}" "${pattern}" "${new_id}"
            ;;
        "value")
            apply_value_replacement "${record}" "${pattern}" "${new_id}"
            ;;
        "both")
            local temp_record
            temp_record=$(apply_key_replacement "${record}" "${pattern}" "${new_id}")
            apply_value_replacement "${temp_record}" "${pattern}" "${new_id}"
            ;;
        *)
            log_error "未知的目标类型: ${target}"
            return 1
            ;;
    esac
}

# Apply key replacement
apply_key_replacement() {
    local record="$1"
    local pattern="$2"
    local new_id="$3"

    local key value
    key=$(echo "${record}" | jq -r '.key' 2>/dev/null)
    value=$(echo "${record}" | jq -r '.value' 2>/dev/null)

    # Extract pattern value for replacement
    local pattern_value
    IFS=':' read -r _ pattern_value <<< "${pattern}"

    # Replace pattern in key
    local new_key
    new_key=$(echo "${key}" | sed "s/${pattern_value}[^[:space:][:punct:]]*/${new_id}/g")

    # Return updated record
    jq -n --arg key "${new_key}" --arg value "${value}" '{key: $key, value: $value}'
}

# Apply value replacement
apply_value_replacement() {
    local record="$1"
    local pattern="$2"
    local new_id="$3"

    local key value
    key=$(echo "${record}" | jq -r '.key' 2>/dev/null)
    value=$(echo "${record}" | jq -r '.value' 2>/dev/null)

    # Extract pattern components
    local pattern_type pattern_value
    IFS=':' read -r pattern_type pattern_value <<< "${pattern}"

    local new_value="${value}"

    # Apply replacement based on pattern type
    case "${pattern_type}" in
        "json")
            # Replace JSON field
            if [[ "${value}" != "null" && "${value}" =~ ^\{.*\}$ ]]; then
                new_value=$(echo "${value}" | jq --arg new_id "${new_id}" ".\"${pattern_value}\" = \$new_id" 2>/dev/null)
            fi
            ;;
        "contains"|"regex")
            # Replace in string value
            new_value=$(echo "${value}" | sed "s/${pattern_value}[^[:space:][:punct:]]*/${new_id}/g")
            ;;
    esac

    # Return updated record
    jq -n --arg key "${key}" --arg value "${new_value}" '{key: $key, value: $value}'
}

# Apply transform value action
apply_transform_value_action() {
    local record="$1"
    local pattern="$2"
    local rule="$3"

    # Extract transformation parameters
    local transform_type
    transform_type=$(echo "${rule}" | jq -r '.transform_type // "uppercase"' 2>/dev/null)

    local key value
    key=$(echo "${record}" | jq -r '.key' 2>/dev/null)
    value=$(echo "${record}" | jq -r '.value' 2>/dev/null)

    # Apply transformation
    local new_value
    case "${transform_type}" in
        "uppercase")
            new_value=$(echo "${value}" | tr '[:lower:]' '[:upper:]')
            ;;
        "lowercase")
            new_value=$(echo "${value}" | tr '[:upper:]' '[:lower:]')
            ;;
        "hash")
            new_value=$(echo "${value}" | sha256sum | cut -d' ' -f1 2>/dev/null || echo "${value}")
            ;;
        *)
            new_value="${value}"
            ;;
    esac

    # Return updated record
    jq -n --arg key "${key}" --arg value "${new_value}" '{key: $key, value: $value}'
}

# Get transformation rules statistics
get_transformation_rules_stats() {
    log_info "转换规则引擎统计信息:"
    for stat_name in "${!RULE_STATS[@]}"; do
        log_info "  ${stat_name}: ${RULE_STATS["${stat_name}"]}"
    done
}

# Generate transformation rules report
generate_transformation_rules_report() {
    local report_file="${1:-transformation_rules_report_$(get_timestamp).txt}"

    log_info "生成转换规则报告: ${report_file}"

    {
        echo "转换规则引擎操作报告"
        echo "生成时间: $(date)"
        echo "=========================="
        echo ""
        echo "统计信息:"
        for stat_name in "${!RULE_STATS[@]}"; do
            echo "  ${stat_name}: ${RULE_STATS["${stat_name}"]}"
        done
        echo ""
        echo "配置信息:"
        echo "  规则配置文件: ${RULES_CONFIG_FILE}"
        echo "  最大规则数: ${MAX_RULES_PER_SET}"
        echo "  验证超时: ${RULE_VALIDATION_TIMEOUT} 秒"
        echo ""
        echo "支持的模式类型:"
        for pattern_type in "${!RULE_PATTERNS[@]}"; do
            echo "  - ${pattern_type}: ${RULE_PATTERNS["${pattern_type}"]}"
        done

    } > "${report_file}"

    log_success "转换规则报告已生成: ${report_file}"
}

# Test transformation rules with sample data
test_transformation_rules() {
    local rule_set_name="${1:-default}"

    log_info "测试转换规则: ${rule_set_name}"

    # Create sample test data
    local test_data='{"key":"test.machineId.12345","value":"{\"machineId\":\"old_machine_id\",\"deviceId\":\"old_device_id\"}"}'

    log_info "测试数据:"
    echo "${test_data}" | jq '.' 2>/dev/null || echo "${test_data}"

    # Apply transformation rules
    local transformed_data
    transformed_data=$(apply_transformation_rules "${test_data}" "${rule_set_name}")
    if [[ $? -eq 0 ]]; then
        log_info "转换结果:"
        echo "${transformed_data}" | jq '.' 2>/dev/null || echo "${transformed_data}"
        return 0
    else
        log_error "转换规则测试失败"
        return 1
    fi
}

# Validate transformation rules configuration
validate_rules_configuration() {
    local config_file="${1:-${RULES_CONFIG_FILE}}"

    log_info "验证转换规则配置: ${config_file}"

    # Check file exists
    if [[ ! -f "${config_file}" ]]; then
        log_error "配置文件不存在: ${config_file}"
        return 1
    fi

    # Validate JSON format
    if ! jq '.' "${config_file}" >/dev/null 2>&1; then
        log_error "配置文件JSON格式无效"
        return 1
    fi

    # Validate structure
    local rule_sets
    rule_sets=$(jq -r '.rule_sets | keys[]' "${config_file}" 2>/dev/null)
    if [[ -z "${rule_sets}" ]]; then
        log_error "配置文件中没有规则集"
        return 1
    fi

    local total_rules=0
    local valid_rules=0

    # Validate each rule set
    while IFS= read -r rule_set_name; do
        if [[ -n "${rule_set_name}" ]]; then
            log_debug "验证规则集: ${rule_set_name}"

            local rules
            rules=$(jq -r ".rule_sets.\"${rule_set_name}\".rules[]" "${config_file}" 2>/dev/null)

            while IFS= read -r rule; do
                if [[ -n "${rule}" ]]; then
                    ((total_rules++))
                    if validate_transformation_rule "${rule}"; then
                        ((valid_rules++))
                    fi
                fi
            done <<< "${rules}"
        fi
    done <<< "${rule_sets}"

    log_info "配置验证完成: ${valid_rules}/${total_rules} 条规则有效"

    if [[ ${valid_rules} -eq ${total_rules} ]]; then
        log_success "所有转换规则配置有效"
        return 0
    else
        log_warn "存在无效的转换规则配置"
        return 1
    fi
}

# Export transformation rules functions
export -f init_transformation_rules create_default_rules_config
export -f load_transformation_rules validate_transformation_rule
export -f apply_transformation_rules apply_single_rule check_pattern_match
export -f apply_replace_id_action apply_key_replacement apply_value_replacement
export -f apply_transform_value_action get_transformation_rules_stats
export -f generate_transformation_rules_report test_transformation_rules
export -f validate_rules_configuration validate_rule_pattern validate_rule_action
export RULE_STATS RULE_PATTERNS

log_debug "转换规则引擎已加载"
