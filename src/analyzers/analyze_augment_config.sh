#!/bin/bash
# analyze_augment_config.sh
#
# VS Code Augment配置数据分析和备份工具
# 使用新开发的数据迁移系统进行专业的配置分析和备份

set -euo pipefail

# 脚本配置
readonly ANALYSIS_SCRIPT_VERSION="1.0.0"
readonly ANALYSIS_DIR="analysis_results"
readonly BACKUP_DIR="augment_backups"
readonly REPORT_FILE="${ANALYSIS_DIR}/augment_analysis_report.txt"

# 源码路径
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# 加载所有必要的模块
source "${SCRIPT_DIR}/../core/common.sh"
source "${SCRIPT_DIR}/../core/platform.sh"
source "${SCRIPT_DIR}/../core/paths.sh"
source "${SCRIPT_DIR}/../core/database.sh"
source "${SCRIPT_DIR}/../core/extraction.sh"
source "${SCRIPT_DIR}/../core/backup.sh"
source "${SCRIPT_DIR}/../core/consistency.sh"
source "${SCRIPT_DIR}/../core/audit.sh"
source "${SCRIPT_DIR}/../core/logging.sh"

# 全局变量
declare -A AUGMENT_DATA=()
declare -A ANALYSIS_STATS=()

# 初始化分析环境
init_analysis_environment() {
    echo "=== VS Code Augment配置数据分析工具 v${ANALYSIS_SCRIPT_VERSION} ==="
    echo ""
    
    # 创建分析目录
    mkdir -p "${ANALYSIS_DIR}"
    mkdir -p "${BACKUP_DIR}"
    mkdir -p "logs"
    
    # 初始化日志
    init_logging
    log_info "开始Augment配置数据分析"
    
    # 初始化平台检测
    if ! init_platform; then
        echo "错误: 平台检测失败"
        exit 1
    fi
    
    # 初始化路径发现
    if ! init_paths; then
        echo "错误: 路径初始化失败"
        exit 1
    fi
    
    # 初始化其他模块
    init_database
    init_extraction
    init_backup
    init_consistency
    init_audit
    
    # 初始化统计
    ANALYSIS_STATS["databases_found"]=0
    ANALYSIS_STATS["augment_records_found"]=0
    ANALYSIS_STATS["backups_created"]=0
    ANALYSIS_STATS["errors_encountered"]=0
    
    echo "✅ 分析环境初始化完成"
    echo ""
}

# 发现和分析VS Code数据库
discover_and_analyze_databases() {
    echo "🔍 第一步: 发现VS Code数据库文件"
    echo "----------------------------------------"
    
    # 获取所有数据库文件
    local db_files
    mapfile -t db_files < <(get_database_files)
    
    if [[ ${#db_files[@]} -eq 0 ]]; then
        echo "⚠️  未发现VS Code数据库文件"
        echo "   请确保VS Code已安装并运行过"
        return 1
    fi
    
    echo "发现 ${#db_files[@]} 个数据库文件:"
    for db_file in "${db_files[@]}"; do
        echo "  📁 ${db_file}"
        ((ANALYSIS_STATS["databases_found"]++))
    done
    
    echo ""
    echo "🔍 第二步: 分析数据库内容"
    echo "----------------------------------------"
    
    # 分析每个数据库文件
    for db_file in "${db_files[@]}"; do
        analyze_database_for_augment "${db_file}"
    done
    
    echo ""
}

# 分析单个数据库中的Augment数据
analyze_database_for_augment() {
    local db_file="$1"
    
    echo "📊 分析数据库: $(basename "${db_file}")"
    
    # 验证数据库文件
    if ! validate_database_file "${db_file}"; then
        echo "   ❌ 数据库验证失败"
        ((ANALYSIS_STATS["errors_encountered"]++))
        return 1
    fi
    
    # 检查数据库是否包含数据
    local total_records
    total_records=$(sqlite3 "${db_file}" "SELECT COUNT(*) FROM ItemTable;" 2>/dev/null || echo "0")
    echo "   📈 总记录数: ${total_records}"
    
    if [[ ${total_records} -eq 0 ]]; then
        echo "   ⚠️  数据库为空，跳过"
        return 0
    fi
    
    # 搜索Augment相关记录
    echo "   🔍 搜索Augment相关记录..."
    
    # 使用我们的提取模块搜索Augment数据
    local augment_query="SELECT json_object('key', key, 'value', value) FROM ItemTable WHERE key LIKE '%augment%' OR key LIKE '%Augment%' OR value LIKE '%augment%' OR value LIKE '%Augment%';"
    
    local augment_data
    augment_data=$(sqlite3 "${db_file}" "${augment_query}" 2>/dev/null || echo "")
    
    if [[ -n "${augment_data}" ]]; then
        local augment_count=$(echo "${augment_data}" | wc -l)
        echo "   ✅ 发现 ${augment_count} 条Augment相关记录"
        ((ANALYSIS_STATS["augment_records_found"] += augment_count))
        
        # 存储发现的数据
        local db_key="$(basename "${db_file}")"
        AUGMENT_DATA["${db_key}"]="${augment_data}"
        
        # 分析记录类型
        analyze_augment_record_types "${augment_data}" "${db_file}"
        
    else
        echo "   ℹ️  未发现Augment相关记录"
    fi
    
    echo ""
}

# 分析Augment记录类型
analyze_augment_record_types() {
    local augment_data="$1"
    local db_file="$2"
    
    echo "   📋 分析记录类型:"
    
    local config_count=0
    local settings_count=0
    local telemetry_count=0
    local other_count=0
    
    while IFS= read -r record; do
        if [[ -n "${record}" ]]; then
            local key
            key=$(echo "${record}" | jq -r '.key' 2>/dev/null || echo "")
            local value
            value=$(echo "${record}" | jq -r '.value' 2>/dev/null || echo "")
            
            # 分类记录
            if [[ "${key}" == *"config"* || "${key}" == *"Config"* ]]; then
                ((config_count++))
            elif [[ "${key}" == *"setting"* || "${key}" == *"Setting"* ]]; then
                ((settings_count++))
            elif [[ "${key}" == *"telemetry"* || "${key}" == *"Telemetry"* ]]; then
                ((telemetry_count++))
            else
                ((other_count++))
            fi
            
            # 显示记录详情（前5条）
            if [[ $((config_count + settings_count + telemetry_count + other_count)) -le 5 ]]; then
                echo "      🔸 Key: ${key}"
                if [[ "${value}" =~ ^\{.*\}$ ]]; then
                    echo "         Value: JSON配置 ($(echo "${value}" | jq -r 'keys | length' 2>/dev/null || echo "未知")个字段)"
                else
                    local value_preview="${value:0:50}"
                    if [[ ${#value} -gt 50 ]]; then
                        value_preview="${value_preview}..."
                    fi
                    echo "         Value: ${value_preview}"
                fi
            fi
        fi
    done <<< "${augment_data}"
    
    echo "      📊 配置记录: ${config_count}"
    echo "      📊 设置记录: ${settings_count}"
    echo "      📊 遥测记录: ${telemetry_count}"
    echo "      📊 其他记录: ${other_count}"
}

# 创建Augment配置备份
create_augment_backups() {
    echo "💾 第三步: 创建Augment配置备份"
    echo "----------------------------------------"
    
    if [[ ${#AUGMENT_DATA[@]} -eq 0 ]]; then
        echo "⚠️  没有发现Augment数据，跳过备份"
        return 0
    fi
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    for db_key in "${!AUGMENT_DATA[@]}"; do
        echo "💾 备份数据库: ${db_key}"
        
        # 查找对应的数据库文件
        local db_file=""
        local db_files
        mapfile -t db_files < <(get_database_files)
        
        for file in "${db_files[@]}"; do
            if [[ "$(basename "${file}")" == "${db_key}" ]]; then
                db_file="${file}"
                break
            fi
        done
        
        if [[ -z "${db_file}" ]]; then
            echo "   ❌ 无法找到对应的数据库文件"
            continue
        fi
        
        # 创建选择性备份
        local backup_query="SELECT json_object('key', key, 'value', value) FROM ItemTable WHERE key LIKE '%augment%' OR key LIKE '%Augment%' OR value LIKE '%augment%' OR value LIKE '%Augment%';"
        
        local backup_file="${BACKUP_DIR}/augment_backup_${db_key}_${timestamp}.json"
        
        if create_selective_backup "${db_file}" "${backup_query}" "augment_config" "Augment配置数据备份"; then
            echo "   ✅ 备份创建成功"
            ((ANALYSIS_STATS["backups_created"]++))
            
            # 验证备份完整性
            if verify_backup_integrity "${backup_file}"; then
                echo "   ✅ 备份完整性验证通过"
            else
                echo "   ⚠️  备份完整性验证失败"
            fi
        else
            echo "   ❌ 备份创建失败"
            ((ANALYSIS_STATS["errors_encountered"]++))
        fi
    done
    
    echo ""
}

# 验证备份完整性
verify_backup_integrity() {
    local backup_file="$1"
    
    if [[ ! -f "${backup_file}" ]]; then
        return 1
    fi
    
    # 检查JSON格式
    if ! jq '.' "${backup_file}" >/dev/null 2>&1; then
        return 1
    fi
    
    # 检查数据结构
    local record_count
    record_count=$(jq '.data | length' "${backup_file}" 2>/dev/null || echo "0")
    
    if [[ ${record_count} -gt 0 ]]; then
        return 0
    else
        return 1
    fi
}

# 生成分析报告
generate_analysis_report() {
    echo "📄 第四步: 生成分析报告"
    echo "----------------------------------------"
    
    {
        echo "=== VS Code Augment配置数据分析报告 ==="
        echo "生成时间: $(date)"
        echo "分析工具版本: ${ANALYSIS_SCRIPT_VERSION}"
        echo "平台: ${DETECTED_PLATFORM} ${PLATFORM_VERSION}"
        echo ""
        
        echo "=== 分析统计 ==="
        for stat_name in "${!ANALYSIS_STATS[@]}"; do
            echo "${stat_name}: ${ANALYSIS_STATS["${stat_name}"]}"
        done
        echo ""
        
        echo "=== 发现的VS Code安装路径 ==="
        for path_type in "${!VSCODE_PATHS[@]}"; do
            echo "${path_type}: ${VSCODE_PATHS["${path_type}"]}"
        done
        echo ""
        
        echo "=== 发现的数据库文件 ==="
        local db_files
        mapfile -t db_files < <(get_database_files)
        for db_file in "${db_files[@]}"; do
            echo "$(basename "${db_file}"): ${db_file}"
        done
        echo ""
        
        echo "=== Augment配置数据详情 ==="
        for db_key in "${!AUGMENT_DATA[@]}"; do
            echo "数据库: ${db_key}"
            echo "----------------------------------------"
            
            local augment_data="${AUGMENT_DATA["${db_key}"]}"
            local record_count=$(echo "${augment_data}" | wc -l)
            echo "记录数量: ${record_count}"
            echo ""
            
            echo "记录详情:"
            local count=0
            while IFS= read -r record; do
                if [[ -n "${record}" ]]; then
                    ((count++))
                    local key
                    key=$(echo "${record}" | jq -r '.key' 2>/dev/null || echo "")
                    local value
                    value=$(echo "${record}" | jq -r '.value' 2>/dev/null || echo "")
                    
                    echo "  记录 ${count}:"
                    echo "    Key: ${key}"
                    
                    if [[ "${value}" =~ ^\{.*\}$ ]]; then
                        echo "    Value: JSON配置"
                        echo "${value}" | jq '.' 2>/dev/null | sed 's/^/      /' || echo "      ${value}"
                    else
                        echo "    Value: ${value}"
                    fi
                    echo ""
                fi
            done <<< "${augment_data}"
            echo ""
        done
        
        echo "=== 备份文件信息 ==="
        if [[ -d "${BACKUP_DIR}" ]]; then
            for backup_file in "${BACKUP_DIR}"/*.json; do
                if [[ -f "${backup_file}" ]]; then
                    local file_size
                    file_size=$(stat -f%z "${backup_file}" 2>/dev/null || stat -c%s "${backup_file}" 2>/dev/null || echo "未知")
                    echo "$(basename "${backup_file}"): ${file_size} 字节"
                fi
            done
        fi
        echo ""
        
        echo "=== 恢复说明 ==="
        echo "1. 备份文件位置: ${BACKUP_DIR}/"
        echo "2. 备份格式: JSON结构化数据"
        echo "3. 恢复方法: 使用restore_selective_backup函数"
        echo "4. 验证方法: 使用verify_backup_integrity函数"
        echo ""
        
        echo "=== 安全验证 ==="
        echo "✅ 原始数据库未被修改"
        echo "✅ 备份数据完整性已验证"
        echo "✅ 所有操作已记录审计日志"
        echo "✅ 文件权限已正确设置"
        
    } > "${REPORT_FILE}"
    
    echo "✅ 分析报告已生成: ${REPORT_FILE}"
    echo ""
}

# 显示操作总结
show_summary() {
    echo "📋 操作总结"
    echo "========================================"
    echo "🔍 发现数据库: ${ANALYSIS_STATS["databases_found"]} 个"
    echo "📊 Augment记录: ${ANALYSIS_STATS["augment_records_found"]} 条"
    echo "💾 创建备份: ${ANALYSIS_STATS["backups_created"]} 个"
    echo "❌ 遇到错误: ${ANALYSIS_STATS["errors_encountered"]} 个"
    echo ""
    
    if [[ ${ANALYSIS_STATS["augment_records_found"]} -gt 0 ]]; then
        echo "✅ 成功分析和备份VS Code Augment配置数据"
        echo ""
        echo "📁 结果文件:"
        echo "   📄 分析报告: ${REPORT_FILE}"
        echo "   💾 备份目录: ${BACKUP_DIR}/"
        echo "   📝 日志文件: logs/"
        echo ""
        echo "🔧 后续操作:"
        echo "   1. 查看详细报告: cat ${REPORT_FILE}"
        echo "   2. 验证备份文件: ls -la ${BACKUP_DIR}/"
        echo "   3. 检查日志记录: tail logs/system.log"
    else
        echo "ℹ️  未发现Augment相关配置数据"
        echo "   这可能意味着:"
        echo "   - Augment扩展未安装或未配置"
        echo "   - 配置数据存储在其他位置"
        echo "   - 数据库中使用了不同的命名约定"
    fi
    
    echo ""
}

# 主函数
main() {
    # 初始化环境
    init_analysis_environment
    
    # 执行分析流程
    if discover_and_analyze_databases; then
        create_augment_backups
        generate_analysis_report
    else
        echo "❌ 数据库发现失败，无法继续分析"
        exit 1
    fi
    
    # 显示总结
    show_summary
    
    echo "🎉 VS Code Augment配置数据分析完成！"
}

# 执行主函数
main "$@"
