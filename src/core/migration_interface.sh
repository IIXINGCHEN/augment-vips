#!/bin/bash
# migration_interface.sh
#
# Auto-fixed for readonly variable conflicts

# Prevent multiple loading
if [[ "${MIGRATION_INTERFACE_SH_LOADED:-}" == "true" ]]; then
    return 0
fi
if [[ -z "${MIGRATION_INTERFACE_SH_LOADED:-}" ]]; then
    readonly MIGRATION_INTERFACE_SH_LOADED="true"
fi

# core/migration_interface.sh
#
# Enterprise-grade unified migration interface for VS Code database operations
# Production-ready with comprehensive orchestration and error handling
# Integrates all migration modules into a cohesive system

set -euo pipefail

# Source all migration modules
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/security.sh"
source "$(dirname "${BASH_SOURCE[0]}")/validation.sh"
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/backup.sh"
source "$(dirname "${BASH_SOURCE[0]}")/database.sh"
source "$(dirname "${BASH_SOURCE[0]}")/extraction.sh"
source "$(dirname "${BASH_SOURCE[0]}")/transformation.sh"
source "$(dirname "${BASH_SOURCE[0]}")/transformation_rules.sh"
source "$(dirname "${BASH_SOURCE[0]}")/insertion.sh"
source "$(dirname "${BASH_SOURCE[0]}")/consistency.sh"
source "$(dirname "${BASH_SOURCE[0]}")/vscode_backup.sh"

# Migration interface constants
if [[ -z "${MIGRATION_INTERFACE_VERSION:-}" ]]; then
    readonly MIGRATION_INTERFACE_VERSION="1.0.0"
fi
if [[ -z "${DEFAULT_CONFIG_FILE:-}" ]]; then
    readonly DEFAULT_CONFIG_FILE="config/settings.json"
fi
if [[ -z "${MIGRATION_LOG_PREFIX:-}" ]]; then
    readonly MIGRATION_LOG_PREFIX="migration_interface"
fi

# Migration operation modes
if [[ -z "${MIGRATION_MODES:-}" ]]; then
    readonly MIGRATION_MODES=("full" "extract_only" "transform_only" "insert_only" "validate_only")
fi

# Global interface statistics
declare -A INTERFACE_STATS=()

# Initialize migration interface
init_migration_interface() {
    log_info "初始化统一迁移接口 v${MIGRATION_INTERFACE_VERSION}..."
    
    # Initialize all required modules
    local modules_to_init=(
        "init_backup"
        "init_database"
        "init_extraction"
        "init_transformation"
        "init_transformation_rules"
        "init_insertion"
        "init_consistency"
        "init_vscode_backup"
    )
    
    for module_init in "${modules_to_init[@]}"; do
        if declare -f "${module_init}" >/dev/null 2>&1; then
            log_debug "初始化模块: ${module_init}"
            if ! "${module_init}"; then
                log_error "模块初始化失败: ${module_init}"
                return 1
            fi
        else
            log_warn "模块初始化函数不存在: ${module_init}"
        fi
    done
    
    # Initialize interface statistics
    INTERFACE_STATS["migrations_executed"]=0
    INTERFACE_STATS["successful_migrations"]=0
    INTERFACE_STATS["failed_migrations"]=0
    INTERFACE_STATS["total_records_processed"]=0
    INTERFACE_STATS["total_execution_time"]=0
    
    audit_log "MIGRATION_INTERFACE_INIT" "统一迁移接口已初始化"
    log_success "统一迁移接口初始化完成"
}

# Execute complete migration workflow
execute_migration_workflow() {
    local db_file="$1"
    local migration_mode="${2:-full}"
    local config_file="${3:-${DEFAULT_CONFIG_FILE}}"
    local dry_run="${4:-false}"
    
    log_info "执行迁移工作流: ${db_file} (模式: ${migration_mode})"
    
    # Validate migration mode
    if ! validate_migration_mode "${migration_mode}"; then
        log_error "无效的迁移模式: ${migration_mode}"
        return 1
    fi
    
    # Load migration configuration
    local migration_config
    migration_config=$(load_migration_configuration "${config_file}")
    if [[ $? -ne 0 ]]; then
        log_error "加载迁移配置失败"
        return 1
    fi
    
    # Start migration workflow
    local workflow_start_time=$(date +%s.%3N)
    local migration_id="migration_$(date +%s%3N)"
    
    ((INTERFACE_STATS["migrations_executed"]++))
    
    log_info "开始迁移工作流: ${migration_id}"
    audit_log "MIGRATION_WORKFLOW_START" "迁移工作流开始: ${migration_id}, 模式: ${migration_mode}"
    
    # Execute workflow based on mode
    local workflow_result=false
    case "${migration_mode}" in
        "full")
            workflow_result=$(execute_full_migration_workflow "${db_file}" "${migration_config}" "${dry_run}" "${migration_id}")
            ;;
        "extract_only")
            workflow_result=$(execute_extraction_workflow "${db_file}" "${migration_config}" "${dry_run}")
            ;;
        "transform_only")
            workflow_result=$(execute_transformation_workflow "${db_file}" "${migration_config}" "${dry_run}")
            ;;
        "insert_only")
            workflow_result=$(execute_insertion_workflow "${db_file}" "${migration_config}" "${dry_run}")
            ;;
        "validate_only")
            workflow_result=$(execute_validation_workflow "${db_file}" "${migration_config}")
            ;;
    esac
    
    local workflow_exit_code=$?
    local workflow_end_time=$(date +%s.%3N)
    local workflow_duration=$(echo "${workflow_end_time} - ${workflow_start_time}" | bc -l 2>/dev/null || echo "0")
    
    # Update statistics
    INTERFACE_STATS["total_execution_time"]=$(echo "${INTERFACE_STATS["total_execution_time"]} + ${workflow_duration}" | bc -l 2>/dev/null || echo "${INTERFACE_STATS["total_execution_time"]}")
    
    if [[ ${workflow_exit_code} -eq 0 ]]; then
        ((INTERFACE_STATS["successful_migrations"]++))
        log_success "迁移工作流完成: ${migration_id} (耗时: ${workflow_duration}s)"
        audit_log "MIGRATION_WORKFLOW_SUCCESS" "迁移工作流成功: ${migration_id}"
    else
        ((INTERFACE_STATS["failed_migrations"]++))
        log_error "迁移工作流失败: ${migration_id} (耗时: ${workflow_duration}s)"
        audit_log "MIGRATION_WORKFLOW_FAILURE" "迁移工作流失败: ${migration_id}"
    fi
    
    return ${workflow_exit_code}
}

# Execute full migration workflow
execute_full_migration_workflow() {
    local db_file="$1"
    local migration_config="$2"
    local dry_run="$3"
    local migration_id="$4"
    
    log_info "执行完整迁移工作流"
    
    # Phase 0: VS Code环境备份 (新增)
    log_info "阶段0: VS Code环境备份"
    local vscode_backup_id=""
    if [[ "${dry_run}" != "true" ]]; then
        vscode_backup_id=$(backup_vscode_environment "pre_migration" "迁移前VS Code环境备份" "${dry_run}")
        if [[ $? -eq 0 && -n "${vscode_backup_id}" ]]; then
            log_info "VS Code环境备份已创建: ${vscode_backup_id}"
        else
            log_warning "VS Code环境备份失败，但继续迁移过程"
        fi
    else
        log_info "DRY RUN: 跳过VS Code环境备份"
    fi

    # Phase 1: Pre-migration validation
    log_info "阶段1: 迁移前验证"
    if ! validate_migration_consistency "${db_file}" "basic"; then
        log_error "迁移前验证失败"
        return 1
    fi

    # Phase 2: Create backup
    log_info "阶段2: 创建数据库备份"
    local backup_file
    if [[ "${dry_run}" != "true" ]]; then
        backup_file=$(create_backup "${db_file}" "migration" "Pre-migration backup for ${migration_id}")
        if [[ $? -ne 0 || -z "${backup_file}" ]]; then
            log_error "创建备份失败"
            return 1
        fi
        log_info "备份已创建: ${backup_file}"
    else
        log_info "DRY RUN: 跳过备份创建"
    fi
    
    # Phase 3: Begin transaction
    log_info "阶段3: 开始事务"
    local transaction_id
    if [[ "${dry_run}" != "true" ]]; then
        transaction_id=$(begin_migration_transaction "${db_file}" "${migration_id}")
        if [[ $? -ne 0 || -z "${transaction_id}" ]]; then
            log_error "开始事务失败"
            return 1
        fi
        log_info "事务已开始: ${transaction_id}"
    else
        log_info "DRY RUN: 跳过事务开始"
    fi
    
    # Phase 4: Extract data
    log_info "阶段4: 提取数据"
    local extracted_data
    extracted_data=$(extract_by_patterns "${db_file}" "default" "json" "${dry_run}")
    if [[ $? -ne 0 ]]; then
        log_error "数据提取失败"
        if [[ -n "${transaction_id}" ]]; then
            rollback_migration_transaction "${transaction_id}"
        fi
        return 1
    fi
    
    local extraction_count=$(echo "${extracted_data}" | wc -l 2>/dev/null || echo "0")
    log_info "提取了 ${extraction_count} 条记录"
    
    # Phase 5: Transform data
    log_info "阶段5: 转换数据"
    local transformed_data
    transformed_data=$(transform_extracted_data "${extracted_data}" "default" "false")
    if [[ $? -ne 0 ]]; then
        log_error "数据转换失败"
        if [[ -n "${transaction_id}" ]]; then
            rollback_migration_transaction "${transaction_id}"
        fi
        return 1
    fi
    
    local transformation_count=$(echo "${transformed_data}" | wc -l 2>/dev/null || echo "0")
    log_info "转换了 ${transformation_count} 条记录"
    
    if [[ "${dry_run}" == "true" ]]; then
        log_info "DRY RUN: 迁移预览完成，未执行实际数据修改"
        log_info "预览结果: 提取 ${extraction_count} 条，转换 ${transformation_count} 条"
        return 0
    fi
    
    # Phase 6: Delete original data
    log_info "阶段6: 删除原始数据"
    if ! delete_original_data "${db_file}" "default"; then
        log_error "删除原始数据失败"
        rollback_migration_transaction "${transaction_id}"
        return 1
    fi
    
    # Phase 7: Insert transformed data
    log_info "阶段7: 插入转换数据"
    if ! insert_transformed_data "${db_file}" "${transformed_data}" "ignore" 1000; then
        log_error "插入转换数据失败"
        rollback_migration_transaction "${transaction_id}"
        return 1
    fi
    
    # Phase 8: Post-migration validation
    log_info "阶段8: 迁移后验证"
    if ! validate_migration_consistency "${db_file}" "full" "${extracted_data}"; then
        log_error "迁移后验证失败"
        rollback_migration_transaction "${transaction_id}"
        return 1
    fi
    
    # Phase 9: Commit transaction
    log_info "阶段9: 提交事务"
    if ! commit_migration_transaction "${transaction_id}"; then
        log_error "提交事务失败"
        return 1
    fi
    
    # Update statistics
    ((INTERFACE_STATS["total_records_processed"] += transformation_count))
    
    log_success "完整迁移工作流执行成功"
    return 0
}

# Validate migration mode
validate_migration_mode() {
    local mode="$1"
    
    for valid_mode in "${MIGRATION_MODES[@]}"; do
        if [[ "${mode}" == "${valid_mode}" ]]; then
            return 0
        fi
    done
    
    return 1
}

# Load migration configuration
load_migration_configuration() {
    local config_file="$1"
    
    log_debug "加载迁移配置: ${config_file}"
    
    if [[ ! -f "${config_file}" ]]; then
        log_error "配置文件不存在: ${config_file}"
        return 1
    fi
    
    # Validate JSON format
    if ! jq '.' "${config_file}" >/dev/null 2>&1; then
        log_error "配置文件格式无效: ${config_file}"
        return 1
    fi
    
    # Extract migration configuration
    local migration_config
    migration_config=$(jq '.migration' "${config_file}" 2>/dev/null)
    if [[ "${migration_config}" == "null" ]]; then
        log_error "配置文件中没有migration配置节"
        return 1
    fi
    
    echo "${migration_config}"
    return 0
}

# Execute extraction workflow
execute_extraction_workflow() {
    local db_file="$1"
    local migration_config="$2"
    local dry_run="$3"

    log_info "执行提取工作流"

    # Extract data
    local extracted_data
    extracted_data=$(extract_by_patterns "${db_file}" "default" "json" "false")
    if [[ $? -ne 0 ]]; then
        log_error "数据提取失败"
        return 1
    fi

    local extraction_count=$(echo "${extracted_data}" | wc -l 2>/dev/null || echo "0")
    log_success "提取工作流完成: ${extraction_count} 条记录"

    # Save extracted data
    local output_file="extracted_data_$(get_timestamp).json"
    echo "${extracted_data}" > "${output_file}"
    log_info "提取数据已保存: ${output_file}"

    return 0
}

# Execute transformation workflow
execute_transformation_workflow() {
    local db_file="$1"
    local migration_config="$2"
    local dry_run="$3"

    log_info "执行转换工作流"

    # Load input data (assume from previous extraction)
    local input_file="extracted_data_latest.json"
    if [[ ! -f "${input_file}" ]]; then
        log_error "输入数据文件不存在: ${input_file}"
        return 1
    fi

    local input_data
    input_data=$(cat "${input_file}")

    # Transform data
    local transformed_data
    transformed_data=$(transform_extracted_data "${input_data}" "default" "false")
    if [[ $? -ne 0 ]]; then
        log_error "数据转换失败"
        return 1
    fi

    local transformation_count=$(echo "${transformed_data}" | wc -l 2>/dev/null || echo "0")
    log_success "转换工作流完成: ${transformation_count} 条记录"

    # Save transformed data
    local output_file="transformed_data_$(get_timestamp).json"
    echo "${transformed_data}" > "${output_file}"
    log_info "转换数据已保存: ${output_file}"

    return 0
}

# Execute insertion workflow
execute_insertion_workflow() {
    local db_file="$1"
    local migration_config="$2"
    local dry_run="$3"

    log_info "执行插入工作流"

    # Load transformed data
    local input_file="transformed_data_latest.json"
    if [[ ! -f "${input_file}" ]]; then
        log_error "转换数据文件不存在: ${input_file}"
        return 1
    fi

    local transformed_data
    transformed_data=$(cat "${input_file}")

    # Insert data
    if [[ "${dry_run}" != "true" ]]; then
        if ! insert_transformed_data "${db_file}" "${transformed_data}" "ignore" 1000; then
            log_error "数据插入失败"
            return 1
        fi
    else
        log_info "DRY RUN: 跳过数据插入"
    fi

    local insertion_count=$(echo "${transformed_data}" | wc -l 2>/dev/null || echo "0")
    log_success "插入工作流完成: ${insertion_count} 条记录"

    return 0
}

# Execute validation workflow
execute_validation_workflow() {
    local db_file="$1"
    local migration_config="$2"

    log_info "执行验证工作流"

    # Perform comprehensive validation
    if ! validate_migration_consistency "${db_file}" "full"; then
        log_error "验证工作流失败"
        return 1
    fi

    log_success "验证工作流完成"
    return 0
}

# Get migration interface statistics
get_migration_interface_stats() {
    log_info "统一迁移接口统计信息:"
    for stat_name in "${!INTERFACE_STATS[@]}"; do
        log_info "  ${stat_name}: ${INTERFACE_STATS["${stat_name}"]}"
    done

    # Get statistics from all modules
    log_info ""
    log_info "模块统计信息:"

    if declare -f get_extraction_stats >/dev/null 2>&1; then
        get_extraction_stats
    fi

    if declare -f get_transformation_stats >/dev/null 2>&1; then
        get_transformation_stats
    fi

    if declare -f get_insertion_stats >/dev/null 2>&1; then
        get_insertion_stats
    fi

    if declare -f get_consistency_stats >/dev/null 2>&1; then
        get_consistency_stats
    fi
}

# Generate comprehensive migration report
generate_migration_interface_report() {
    local report_file="${1:-migration_interface_report_$(get_timestamp).txt}"

    log_info "生成统一迁移接口报告: ${report_file}"

    {
        echo "统一迁移接口操作报告"
        echo "版本: ${MIGRATION_INTERFACE_VERSION}"
        echo "生成时间: $(date)"
        echo "=========================="
        echo ""
        echo "接口统计信息:"
        for stat_name in "${!INTERFACE_STATS[@]}"; do
            echo "  ${stat_name}: ${INTERFACE_STATS["${stat_name}"]}"
        done
        echo ""
        echo "支持的迁移模式:"
        for mode in "${MIGRATION_MODES[@]}"; do
            echo "  - ${mode}"
        done
        echo ""
        echo "配置信息:"
        echo "  默认配置文件: ${DEFAULT_CONFIG_FILE}"
        echo "  日志前缀: ${MIGRATION_LOG_PREFIX}"

    } > "${report_file}"

    log_success "统一迁移接口报告已生成: ${report_file}"
}

# Test migration interface
test_migration_interface() {
    local test_db="${1:-test_migration_interface.db}"

    log_info "测试统一迁移接口: ${test_db}"

    # Create test database
    sqlite3 "${test_db}" "CREATE TABLE IF NOT EXISTS ItemTable (key TEXT PRIMARY KEY, value TEXT);" 2>/dev/null
    sqlite3 "${test_db}" "INSERT INTO ItemTable VALUES ('test.machineId.123', 'old_machine_value');" 2>/dev/null
    sqlite3 "${test_db}" "INSERT INTO ItemTable VALUES ('test.deviceId.456', 'old_device_value');" 2>/dev/null

    # Test migration workflow
    if execute_migration_workflow "${test_db}" "full" "${DEFAULT_CONFIG_FILE}" "true"; then
        log_success "统一迁移接口测试通过"

        # Cleanup
        rm -f "${test_db}"
        return 0
    else
        log_error "统一迁移接口测试失败"
        rm -f "${test_db}"
        return 1
    fi
}

# Display migration interface help
show_migration_interface_help() {
    cat << 'EOF'
统一迁移接口使用说明
==================

功能：
  execute_migration_workflow <db_file> [mode] [config_file] [dry_run]
    执行迁移工作流

    参数：
      db_file     - 数据库文件路径
      mode        - 迁移模式 (full|extract_only|transform_only|insert_only|validate_only)
      config_file - 配置文件路径 (默认: config/settings.json)
      dry_run     - 是否为预览模式 (true|false, 默认: false)

迁移模式：
  full          - 完整迁移流程 (提取→转换→删除→插入→验证)
  extract_only  - 仅提取数据
  transform_only- 仅转换数据
  insert_only   - 仅插入数据
  validate_only - 仅验证数据

示例：
  # 完整迁移（预览模式）
  execute_migration_workflow "/path/to/database.vscdb" "full" "config/settings.json" "true"

  # 仅提取数据
  execute_migration_workflow "/path/to/database.vscdb" "extract_only"

  # 验证数据库
  execute_migration_workflow "/path/to/database.vscdb" "validate_only"

其他功能：
  get_migration_interface_stats     - 显示统计信息
  generate_migration_interface_report - 生成报告
  test_migration_interface         - 测试功能
  show_migration_interface_help    - 显示帮助

EOF
}

# Export migration interface functions
export -f init_migration_interface execute_migration_workflow execute_full_migration_workflow
export -f execute_extraction_workflow execute_transformation_workflow execute_insertion_workflow
export -f execute_validation_workflow validate_migration_mode load_migration_configuration
export -f get_migration_interface_stats generate_migration_interface_report test_migration_interface
export -f show_migration_interface_help
export INTERFACE_STATS MIGRATION_MODES

log_debug "统一迁移接口模块已加载"
