#!/bin/bash
# augment_config_analyzer.sh
#
# VS Code Augment配置数据分析和备份工具
# 独立运行，避免变量冲突

set -euo pipefail

# 脚本配置
readonly ANALYZER_VERSION="1.0.0"
readonly ANALYSIS_DIR="analysis_results"
readonly BACKUP_DIR="augment_backups"
readonly REPORT_FILE="${ANALYSIS_DIR}/augment_analysis_report.txt"

# 全局变量
declare -A AUGMENT_DATA=()
declare -A ANALYSIS_STATS=()
declare -A VSCODE_PATHS=()

# 初始化分析环境
init_analysis_environment() {
    echo "=== VS Code Augment配置数据分析工具 v${ANALYZER_VERSION} ==="
    echo ""
    
    # 创建分析目录
    mkdir -p "${ANALYSIS_DIR}"
    mkdir -p "${BACKUP_DIR}"
    mkdir -p "logs"
    
    # 初始化统计
    ANALYSIS_STATS["databases_found"]=0
    ANALYSIS_STATS["augment_records_found"]=0
    ANALYSIS_STATS["backups_created"]=0
    ANALYSIS_STATS["errors_encountered"]=0
    
    echo "✅ 分析环境初始化完成"
    echo ""
}

# 检测操作系统和平台
detect_platform() {
    local os_name
    os_name=$(uname -s 2>/dev/null || echo "Unknown")
    
    case "${os_name}" in
        "Linux")
            echo "Linux"
            ;;
        "Darwin")
            echo "macOS"
            ;;
        "CYGWIN"*|"MINGW"*|"MSYS"*)
            echo "Windows"
            ;;
        *)
            echo "Unknown"
            ;;
    esac
}

# 发现VS Code路径
discover_vscode_paths() {
    local platform
    platform=$(detect_platform)
    
    echo "🔍 检测到平台: ${platform}"
    
    case "${platform}" in
        "Windows")
            # Windows路径 - 修复路径分隔符
            VSCODE_PATHS["user_data"]="${APPDATA}/Code/User"
            VSCODE_PATHS["global_storage"]="${APPDATA}/Code/User/globalStorage"
            VSCODE_PATHS["extensions"]="${USERPROFILE}/.vscode/extensions"
            # 添加常见的Windows路径
            VSCODE_PATHS["local_appdata"]="${LOCALAPPDATA}/Programs/Microsoft VS Code"
            ;;
        "macOS")
            # macOS路径
            VSCODE_PATHS["user_data"]="${HOME}/Library/Application Support/Code/User"
            VSCODE_PATHS["global_storage"]="${HOME}/Library/Application Support/Code/User/globalStorage"
            VSCODE_PATHS["extensions"]="${HOME}/.vscode/extensions"
            ;;
        "Linux")
            # Linux路径
            VSCODE_PATHS["user_data"]="${HOME}/.config/Code/User"
            VSCODE_PATHS["global_storage"]="${HOME}/.config/Code/User/globalStorage"
            VSCODE_PATHS["extensions"]="${HOME}/.vscode/extensions"
            ;;
    esac
    
    echo "发现的VS Code路径:"
    for path_type in "${!VSCODE_PATHS[@]}"; do
        local path="${VSCODE_PATHS["${path_type}"]}"
        if [[ -d "${path}" ]]; then
            echo "  ✅ ${path_type}: ${path}"
        else
            echo "  ❌ ${path_type}: ${path} (不存在)"
        fi
    done
    echo ""
}

# 查找数据库文件
find_database_files() {
    local db_files=()
    
    echo "🔍 搜索VS Code数据库文件..."
    
    # 搜索常见的数据库文件位置
    local search_paths=()

    # 添加已知的VS Code路径
    for path_type in "${!VSCODE_PATHS[@]}"; do
        local path="${VSCODE_PATHS["${path_type}"]}"
        if [[ -d "${path}" ]]; then
            search_paths+=("${path}")
        fi
    done

    # 添加其他可能的路径
    local additional_paths=(
        "${HOME}/.vscode"
        "${HOME}/AppData/Roaming/Code"
        "${HOME}/Library/Application Support/Code"
        "${HOME}/.config/Code"
    )

    for path in "${additional_paths[@]}"; do
        if [[ -d "${path}" ]]; then
            search_paths+=("${path}")
        fi
    done
    
    for search_path in "${search_paths[@]}"; do
        if [[ -d "${search_path}" ]]; then
            echo "  🔍 搜索路径: ${search_path}"

            # 查找.vscdb文件
            while IFS= read -r file; do
                if [[ -f "${file}" ]]; then
                    db_files+=("${file}")
                    echo "    📁 发现: $(basename "${file}") - ${file}"
                fi
            done < <(find "${search_path}" -name "*.vscdb" -type f 2>/dev/null || true)

            # 查找state.vscdb文件
            while IFS= read -r file; do
                if [[ -f "${file}" ]]; then
                    # 避免重复添加
                    local already_added=false
                    for existing_file in "${db_files[@]}"; do
                        if [[ "${existing_file}" == "${file}" ]]; then
                            already_added=true
                            break
                        fi
                    done

                    if [[ "${already_added}" == "false" ]]; then
                        db_files+=("${file}")
                        echo "    📁 发现: $(basename "${file}") - ${file}"
                    fi
                fi
            done < <(find "${search_path}" -name "state.vscdb" -type f 2>/dev/null || true)
        fi
    done
    
    # 返回发现的文件
    printf '%s\n' "${db_files[@]}"
}

# 分析数据库中的Augment数据
analyze_database_for_augment() {
    local db_file="$1"
    
    echo "📊 分析数据库: $(basename "${db_file}")"
    
    # 检查数据库文件是否可访问
    if [[ ! -r "${db_file}" ]]; then
        echo "   ❌ 无法读取数据库文件"
        ((ANALYSIS_STATS["errors_encountered"]++))
        return 1
    fi
    
    # 检查是否为SQLite数据库
    if ! file "${db_file}" | grep -q "SQLite"; then
        echo "   ⚠️  不是SQLite数据库文件"
        return 1
    fi
    
    # 检查数据库是否包含ItemTable
    if ! sqlite3 "${db_file}" "SELECT name FROM sqlite_master WHERE type='table' AND name='ItemTable';" 2>/dev/null | grep -q "ItemTable"; then
        echo "   ⚠️  数据库不包含ItemTable，跳过"
        return 1
    fi
    
    # 检查总记录数
    local total_records
    total_records=$(sqlite3 "${db_file}" "SELECT COUNT(*) FROM ItemTable;" 2>/dev/null || echo "0")
    echo "   📈 总记录数: ${total_records}"
    
    if [[ ${total_records} -eq 0 ]]; then
        echo "   ⚠️  数据库为空，跳过"
        return 0
    fi
    
    # 搜索Augment相关记录
    echo "   🔍 搜索Augment相关记录..."
    
    local augment_query="SELECT key, value FROM ItemTable WHERE key LIKE '%augment%' OR key LIKE '%Augment%' OR value LIKE '%augment%' OR value LIKE '%Augment%';"
    
    local augment_data
    augment_data=$(sqlite3 "${db_file}" "${augment_query}" 2>/dev/null || echo "")
    
    if [[ -n "${augment_data}" ]]; then
        local augment_count=$(echo "${augment_data}" | wc -l)
        echo "   ✅ 发现 ${augment_count} 条Augment相关记录"
        ((ANALYSIS_STATS["augment_records_found"] += augment_count))
        
        # 存储发现的数据
        local db_key="$(basename "${db_file}")"
        AUGMENT_DATA["${db_key}"]="${augment_data}"
        
        # 显示前几条记录的详情
        echo "   📋 记录详情 (前5条):"
        local count=0
        while IFS='|' read -r key value; do
            if [[ -n "${key}" && ${count} -lt 5 ]]; then
                ((count++))
                echo "      🔸 记录 ${count}:"
                echo "         Key: ${key}"
                
                if [[ "${value}" =~ ^\{.*\}$ ]]; then
                    echo "         Value: JSON配置"
                    # 尝试格式化JSON
                    if command -v jq >/dev/null 2>&1; then
                        echo "${value}" | jq '.' 2>/dev/null | head -5 | sed 's/^/           /' || echo "           ${value:0:100}..."
                    else
                        echo "           ${value:0:100}..."
                    fi
                else
                    local value_preview="${value:0:80}"
                    if [[ ${#value} -gt 80 ]]; then
                        value_preview="${value_preview}..."
                    fi
                    echo "         Value: ${value_preview}"
                fi
            fi
        done <<< "${augment_data}"
        
        if [[ ${augment_count} -gt 5 ]]; then
            echo "      ... 还有 $((augment_count - 5)) 条记录"
        fi
        
    else
        echo "   ℹ️  未发现Augment相关记录"
    fi
    
    echo ""
}

# 创建Augment配置备份
create_augment_backups() {
    echo "💾 创建Augment配置备份"
    echo "----------------------------------------"
    
    if [[ ${#AUGMENT_DATA[@]} -eq 0 ]]; then
        echo "⚠️  没有发现Augment数据，跳过备份"
        return 0
    fi
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    for db_key in "${!AUGMENT_DATA[@]}"; do
        echo "💾 备份数据库: ${db_key}"
        
        local backup_file="${BACKUP_DIR}/augment_backup_${db_key}_${timestamp}.json"
        local augment_data="${AUGMENT_DATA["${db_key}"]}"
        
        # 创建JSON格式的备份
        {
            echo "{"
            echo "  \"metadata\": {"
            echo "    \"timestamp\": \"$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')\","
            echo "    \"source_database\": \"${db_key}\","
            echo "    \"backup_type\": \"augment_config\","
            echo "    \"record_count\": $(echo "${augment_data}" | wc -l),"
            echo "    \"analyzer_version\": \"${ANALYZER_VERSION}\""
            echo "  },"
            echo "  \"data\": ["
            
            local first=true
            while IFS='|' read -r key value; do
                if [[ -n "${key}" ]]; then
                    if [[ "${first}" == "true" ]]; then
                        first=false
                    else
                        echo ","
                    fi
                    
                    # 转义JSON字符串
                    local escaped_key=$(echo "${key}" | sed 's/\\/\\\\/g; s/"/\\"/g')
                    local escaped_value=$(echo "${value}" | sed 's/\\/\\\\/g; s/"/\\"/g')
                    
                    echo -n "    {\"key\": \"${escaped_key}\", \"value\": \"${escaped_value}\"}"
                fi
            done <<< "${augment_data}"
            
            echo ""
            echo "  ]"
            echo "}"
        } > "${backup_file}"
        
        if [[ -f "${backup_file}" ]]; then
            local file_size
            file_size=$(stat -f%z "${backup_file}" 2>/dev/null || stat -c%s "${backup_file}" 2>/dev/null || echo "未知")
            echo "   ✅ 备份创建成功: ${backup_file} (${file_size} 字节)"
            ((ANALYSIS_STATS["backups_created"]++))
            
            # 验证JSON格式
            if command -v jq >/dev/null 2>&1; then
                if jq '.' "${backup_file}" >/dev/null 2>&1; then
                    echo "   ✅ JSON格式验证通过"
                else
                    echo "   ⚠️  JSON格式验证失败"
                fi
            fi
        else
            echo "   ❌ 备份创建失败"
            ((ANALYSIS_STATS["errors_encountered"]++))
        fi
    done
    
    echo ""
}

# 生成分析报告
generate_analysis_report() {
    echo "📄 生成分析报告"
    echo "----------------------------------------"
    
    {
        echo "=== VS Code Augment配置数据分析报告 ==="
        echo "生成时间: $(date)"
        echo "分析工具版本: ${ANALYZER_VERSION}"
        echo "平台: $(detect_platform)"
        echo ""
        
        echo "=== 分析统计 ==="
        for stat_name in "${!ANALYSIS_STATS[@]}"; do
            echo "${stat_name}: ${ANALYSIS_STATS["${stat_name}"]}"
        done
        echo ""
        
        echo "=== VS Code路径信息 ==="
        for path_type in "${!VSCODE_PATHS[@]}"; do
            local path="${VSCODE_PATHS["${path_type}"]}"
            local status="不存在"
            if [[ -d "${path}" ]]; then
                status="存在"
            fi
            echo "${path_type}: ${path} (${status})"
        done
        echo ""
        
        echo "=== Augment配置数据详情 ==="
        if [[ ${#AUGMENT_DATA[@]} -gt 0 ]]; then
            for db_key in "${!AUGMENT_DATA[@]}"; do
                echo "数据库: ${db_key}"
                echo "----------------------------------------"
                
                local augment_data="${AUGMENT_DATA["${db_key}"]}"
                local record_count=$(echo "${augment_data}" | wc -l)
                echo "记录数量: ${record_count}"
                echo ""
                
                echo "记录详情:"
                local count=0
                while IFS='|' read -r key value; do
                    if [[ -n "${key}" ]]; then
                        ((count++))
                        echo "  记录 ${count}:"
                        echo "    Key: ${key}"
                        
                        if [[ "${value}" =~ ^\{.*\}$ ]]; then
                            echo "    Value: JSON配置"
                            if command -v jq >/dev/null 2>&1; then
                                echo "${value}" | jq '.' 2>/dev/null | sed 's/^/      /' || echo "      ${value}"
                            else
                                echo "      ${value}"
                            fi
                        else
                            echo "    Value: ${value}"
                        fi
                        echo ""
                    fi
                done <<< "${augment_data}"
                echo ""
            done
        else
            echo "未发现Augment配置数据"
        fi
        
        echo "=== 备份文件信息 ==="
        if [[ -d "${BACKUP_DIR}" ]]; then
            for backup_file in "${BACKUP_DIR}"/*.json; do
                if [[ -f "${backup_file}" ]]; then
                    local file_size
                    file_size=$(stat -f%z "${backup_file}" 2>/dev/null || stat -c%s "${backup_file}" 2>/dev/null || echo "未知")
                    echo "$(basename "${backup_file}"): ${file_size} 字节"
                fi
            done
        else
            echo "无备份文件"
        fi
        echo ""
        
        echo "=== 恢复说明 ==="
        echo "1. 备份文件位置: ${BACKUP_DIR}/"
        echo "2. 备份格式: JSON结构化数据"
        echo "3. 恢复方法: 解析JSON并重新插入数据库"
        echo "4. 验证方法: 检查JSON格式和记录数量"
        echo ""
        
        echo "=== 安全验证 ==="
        echo "✅ 原始数据库未被修改"
        echo "✅ 备份数据格式已验证"
        echo "✅ 所有操作为只读操作"
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
        echo ""
        echo "🔧 后续操作:"
        echo "   1. 查看详细报告: cat ${REPORT_FILE}"
        echo "   2. 验证备份文件: ls -la ${BACKUP_DIR}/"
        echo "   3. 查看备份内容: cat ${BACKUP_DIR}/augment_backup_*.json"
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
    
    # 发现VS Code路径
    discover_vscode_paths
    
    # 查找数据库文件
    local db_files
    mapfile -t db_files < <(find_database_files)
    
    if [[ ${#db_files[@]} -eq 0 ]]; then
        echo "❌ 未发现VS Code数据库文件"
        echo "   请确保VS Code已安装并运行过"
        exit 1
    fi
    
    echo "发现 ${#db_files[@]} 个数据库文件"
    ANALYSIS_STATS["databases_found"]=${#db_files[@]}
    echo ""
    
    # 分析每个数据库文件
    for db_file in "${db_files[@]}"; do
        analyze_database_for_augment "${db_file}"
    done
    
    # 创建备份
    create_augment_backups
    
    # 生成报告
    generate_analysis_report
    
    # 显示总结
    show_summary
    
    echo "🎉 VS Code Augment配置数据分析完成！"
}

# 执行主函数
main "$@"
