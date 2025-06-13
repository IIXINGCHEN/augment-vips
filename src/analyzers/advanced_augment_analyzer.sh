#!/bin/bash
# advanced_augment_analyzer.sh
#
# 高级VS Code Augment配置数据分析工具
# 独立运行版本，不依赖外部模块

set -euo pipefail

# 配置
readonly ADVANCED_ANALYZER_VERSION="2.0.0"
readonly ANALYSIS_DIR="analysis_results"
readonly BACKUP_DIR="augment_backups"
readonly REPORT_FILE="${ANALYSIS_DIR}/advanced_augment_analysis_report.txt"

# 脚本目录
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

echo "=== 高级VS Code Augment配置数据分析工具 v${ADVANCED_ANALYZER_VERSION} ==="
echo "独立运行版本，内置所有必要功能"
echo ""

# 创建目录
mkdir -p "${ANALYSIS_DIR}"
mkdir -p "${BACKUP_DIR}"
mkdir -p "logs"

# 统计变量
databases_found=0
augment_records_found=0
backups_created=0
errors_encountered=0

# 内置日志函数
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*"
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $*"
}

log_warn() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $*"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*"
}

# 检测平台
detect_platform() {
    local os_name
    os_name=$(uname -s 2>/dev/null || echo "Unknown")
    
    case "${os_name}" in
        "Linux") echo "Linux" ;;
        "Darwin") echo "macOS" ;;
        "CYGWIN"*|"MINGW"*|"MSYS"*) echo "Windows" ;;
        *) echo "Unknown" ;;
    esac
}

# 发现VS Code路径
discover_vscode_paths() {
    local platform
    platform=$(detect_platform)
    
    case "${platform}" in
        "Windows")
            echo "user_data:${APPDATA}/Code/User"
            echo "global_storage:${APPDATA}/Code/User/globalStorage"
            echo "workspace_storage:${APPDATA}/Code/User/workspaceStorage"
            echo "extensions:${USERPROFILE}/.vscode/extensions"
            ;;
        "macOS")
            echo "user_data:${HOME}/Library/Application Support/Code/User"
            echo "global_storage:${HOME}/Library/Application Support/Code/User/globalStorage"
            echo "workspace_storage:${HOME}/Library/Application Support/Code/User/workspaceStorage"
            echo "extensions:${HOME}/.vscode/extensions"
            ;;
        "Linux")
            echo "user_data:${HOME}/.config/Code/User"
            echo "global_storage:${HOME}/.config/Code/User/globalStorage"
            echo "workspace_storage:${HOME}/.config/Code/User/workspaceStorage"
            echo "extensions:${HOME}/.vscode/extensions"
            ;;
    esac
}

# 查找数据库文件
find_database_files() {
    local search_paths=()
    
    # 获取VS Code路径
    while IFS=':' read -r path_type path_value; do
        if [[ -d "${path_value}" ]]; then
            search_paths+=("${path_value}")
        fi
    done < <(discover_vscode_paths)
    
    # 搜索数据库文件
    local db_files=()
    for search_path in "${search_paths[@]}"; do
        while IFS= read -r file; do
            if [[ -f "${file}" ]]; then
                db_files+=("${file}")
            fi
        done < <(find "${search_path}" -name "*.vscdb" -type f 2>/dev/null || true)
    done
    
    printf '%s\n' "${db_files[@]}"
}

# 验证数据库文件
validate_database_file() {
    local db_file="$1"
    
    # 检查文件是否存在和可读
    if [[ ! -r "${db_file}" ]]; then
        return 1
    fi
    
    # 检查文件大小
    local file_size
    file_size=$(stat -c%s "${db_file}" 2>/dev/null || stat -f%z "${db_file}" 2>/dev/null || echo "0")
    
    if [[ ${file_size} -eq 0 ]]; then
        return 1
    fi
    
    # 尝试SQLite验证
    if command -v sqlite3 >/dev/null 2>&1; then
        if ! sqlite3 "${db_file}" "PRAGMA integrity_check;" >/dev/null 2>&1; then
            return 1
        fi
    fi
    
    return 0
}

echo "🔧 初始化分析系统..."
echo "  ✅ 内置日志系统"
echo "  ✅ 平台检测功能"
echo "  ✅ VS Code路径发现"
echo "  ✅ 数据库文件搜索"
echo "  ✅ 数据库验证功能"
echo "  📊 所有功能已就绪"
echo ""

# 发现数据库文件
echo "🔍 发现VS Code数据库文件..."

# 查找数据库文件
mapfile -t db_files < <(find_database_files)

if [[ ${#db_files[@]} -eq 0 ]]; then
    echo "❌ 未发现VS Code数据库文件"
    echo "   请确保VS Code已安装并运行过"
    exit 1
fi

echo "发现 ${#db_files[@]} 个数据库文件"
databases_found=${#db_files[@]}
echo ""

# 分析每个数据库文件
echo "📊 分析数据库内容:"
echo "----------------------------------------"

for db_file in "${db_files[@]}"; do
    echo "📊 分析数据库: $(basename "${db_file}")"
    echo "   路径: ${db_file}"
    
    # 检查文件是否可读
    if [[ ! -r "${db_file}" ]]; then
        echo "   ❌ 无法读取数据库文件"
        ((errors_encountered++))
        continue
    fi
    
    # 获取文件信息
    file_size=$(stat -c%s "${db_file}" 2>/dev/null || stat -f%z "${db_file}" 2>/dev/null || echo "未知")
    echo "   📈 文件大小: ${file_size} 字节"
    
    # 验证数据库格式
    echo "   🔍 验证数据库格式..."
    if validate_database_file "${db_file}"; then
        echo "   ✅ 数据库格式验证通过"
    else
        echo "   ⚠️  数据库格式验证失败，但继续分析"
    fi
    
    # 使用SQLite查询搜索Augment数据
    echo "   🔍 搜索Augment相关数据..."
    
    if command -v sqlite3 >/dev/null 2>&1; then
        echo "   🔧 使用SQLite查询..."
        
        # 构建查询来搜索Augment相关数据
        augment_query="SELECT key, value FROM ItemTable WHERE key LIKE '%augment%' OR key LIKE '%Augment%' OR value LIKE '%augment%' OR value LIKE '%Augment%';"
        
        extracted_data=$(sqlite3 "${db_file}" "${augment_query}" 2>/dev/null || echo "")
        
        if [[ -n "${extracted_data}" ]]; then
            augment_count=$(echo "${extracted_data}" | wc -l)
            echo "   ✅ SQLite查询发现 ${augment_count} 条Augment相关记录"
            augment_records_found=$((augment_records_found + augment_count))
            
            echo "   📋 记录详情 (前5条):"
            echo "${extracted_data}" | head -5 | while IFS='|' read -r key value; do
                if [[ -n "${key}" ]]; then
                    echo "      🔸 Key: ${key}"
                    echo "         Value: ${value:0:80}$(if [[ ${#value} -gt 80 ]]; then echo "..."; fi)"
                fi
            done
            
            # 创建结构化备份
            echo "   💾 创建结构化备份..."
            timestamp=$(date +%Y%m%d_%H%M%S)
            backup_file="${BACKUP_DIR}/augment_structured_$(basename "${db_file}")_${timestamp}.json"
            
            {
                echo "{"
                echo "  \"metadata\": {"
                echo "    \"timestamp\": \"$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')\","
                echo "    \"source_database\": \"${db_file}\","
                echo "    \"backup_type\": \"augment_structured\","
                echo "    \"record_count\": ${augment_count},"
                echo "    \"analyzer_version\": \"${ADVANCED_ANALYZER_VERSION}\""
                echo "  },"
                echo "  \"data\": ["
                
                first=true
                echo "${extracted_data}" | while IFS='|' read -r key value; do
                    if [[ -n "${key}" ]]; then
                        if [[ "${first}" == "true" ]]; then
                            first=false
                        else
                            echo ","
                        fi
                        echo -n "    {\"key\": \"${key}\", \"value\": \"${value}\"}"
                    fi
                done
                
                echo ""
                echo "  ]"
                echo "}"
            } > "${backup_file}"
            
            if [[ -f "${backup_file}" ]]; then
                backup_size=$(stat -c%s "${backup_file}" 2>/dev/null || stat -f%z "${backup_file}" 2>/dev/null || echo "未知")
                echo "   ✅ 结构化备份创建成功: ${backup_file} (${backup_size} 字节)"
                ((backups_created++))
            fi
            
        else
            echo "   ℹ️  SQLite查询未发现Augment相关记录"
        fi
    else
        echo "   ⚠️  SQLite命令不可用，跳过数据库查询"
    fi
    
    # 回退到基本字符串搜索
    echo "   🔧 执行基本字符串搜索..."
    
    if command -v strings >/dev/null 2>&1; then
        augment_strings=$(strings "${db_file}" 2>/dev/null | grep -i "augment" || true)
        
        if [[ -n "${augment_strings}" ]]; then
            string_count=$(echo "${augment_strings}" | wc -l)
            echo "   ✅ 字符串搜索发现 ${string_count} 个匹配"
            
            if [[ ${string_count} -gt ${augment_records_found} ]]; then
                augment_records_found=${string_count}
            fi
            
            echo "   📋 发现的字符串 (前5个):"
            echo "${augment_strings}" | head -5 | while IFS= read -r line; do
                if [[ -n "${line}" ]]; then
                    display_line="${line:0:80}"
                    if [[ ${#line} -gt 80 ]]; then
                        display_line="${display_line}..."
                    fi
                    echo "      🔸 ${display_line}"
                fi
            done
        else
            echo "   ℹ️  字符串搜索未发现匹配"
        fi
    else
        echo "   ⚠️  strings命令不可用"
    fi
    
    echo ""
done

# 生成高级分析报告
echo "📄 生成高级分析报告"
echo "----------------------------------------"

{
    echo "=== VS Code Augment配置数据高级分析报告 ==="
    echo "生成时间: $(date)"
    echo "分析工具版本: ${ADVANCED_ANALYZER_VERSION}"
    echo "使用系统: 独立分析系统"
    echo ""

    echo "=== 分析统计 ==="
    echo "databases_found: ${databases_found}"
    echo "augment_records_found: ${augment_records_found}"
    echo "backups_created: ${backups_created}"
    echo "errors_encountered: ${errors_encountered}"
    echo ""

    echo "=== 分析的数据库文件 ==="
    for db_file in "${db_files[@]}"; do
        file_size=$(stat -c%s "${db_file}" 2>/dev/null || stat -f%z "${db_file}" 2>/dev/null || echo "未知")
        echo "$(basename "${db_file}"): ${db_file} (${file_size} 字节)"
    done
    echo ""

    echo "=== 使用的分析方法 ==="
    echo "1. SQLite数据库查询"
    echo "2. 字符串模式搜索"
    echo "3. 数据库格式验证"
    echo "4. 结构化数据备份"
    echo ""

    echo "=== 备份文件信息 ==="
    if [[ -d "${BACKUP_DIR}" ]]; then
        for backup_file in "${BACKUP_DIR}"/*; do
            if [[ -f "${backup_file}" ]]; then
                file_size=$(stat -c%s "${backup_file}" 2>/dev/null || stat -f%z "${backup_file}" 2>/dev/null || echo "未知")
                echo "$(basename "${backup_file}"): ${file_size} 字节"
            fi
        done
    else
        echo "无备份文件"
    fi
    echo ""

    echo "=== 系统功能可用性 ==="
    echo "sqlite3: $(if command -v sqlite3 >/dev/null 2>&1; then echo "可用"; else echo "不可用"; fi)"
    echo "strings: $(if command -v strings >/dev/null 2>&1; then echo "可用"; else echo "不可用"; fi)"
    echo "find: $(if command -v find >/dev/null 2>&1; then echo "可用"; else echo "不可用"; fi)"
    echo "stat: $(if command -v stat >/dev/null 2>&1; then echo "可用"; else echo "不可用"; fi)"
    echo ""

    echo "=== 恢复说明 ==="
    echo "1. 备份文件位置: ${BACKUP_DIR}/"
    echo "2. 备份格式: JSON结构化数据"
    echo "3. 恢复方法: 手动导入或使用专用恢复工具"
    echo "4. 验证方法: JSON格式验证和记录数量检查"
    echo ""

    echo "=== 安全验证 ==="
    echo "✅ 原始数据库未被修改"
    echo "✅ 使用只读操作进行分析"
    echo "✅ 所有操作为只读操作"
    echo "✅ 备份数据结构化存储"
    echo "✅ 完整的操作记录"

} > "${REPORT_FILE}"

echo "✅ 高级分析报告已生成: ${REPORT_FILE}"
echo ""

# 显示总结
echo "📋 高级分析总结"
echo "========================================"
echo "🔍 发现数据库: ${databases_found} 个"
echo "📊 Augment记录: ${augment_records_found} 条"
echo "💾 创建备份: ${backups_created} 个"
echo "❌ 遇到错误: ${errors_encountered} 个"
echo ""

if [[ ${augment_records_found} -gt 0 ]]; then
    echo "✅ 成功分析和备份VS Code Augment配置数据"
    echo ""
    echo "📁 结果文件:"
    echo "   📄 高级分析报告: ${REPORT_FILE}"
    echo "   💾 备份目录: ${BACKUP_DIR}/"
    echo ""
    echo "🔧 后续操作:"
    echo "   1. 查看详细报告: cat ${REPORT_FILE}"
    echo "   2. 验证备份文件: ls -la ${BACKUP_DIR}/"
    echo "   3. 根据需要进行进一步操作"
else
    echo "ℹ️  未发现Augment相关配置数据"
    echo ""
    echo "🔍 可能的原因:"
    echo "   - Augment扩展未安装或未配置"
    echo "   - 配置数据使用不同的命名约定"
    echo "   - 数据存储在其他位置或格式"
    echo "   - 需要更深入的数据库结构分析"
    echo ""
    echo "💡 建议:"
    echo "   1. 检查VS Code扩展列表确认Augment是否安装"
    echo "   2. 查看VS Code设置文件中的Augment配置"
    echo "   3. 使用其他分析工具进行更深入的分析"
fi

echo ""
echo "🎉 高级VS Code Augment配置数据分析完成！"

log_success "分析完成 - 数据库: ${databases_found}, 记录: ${augment_records_found}, 备份: ${backups_created}, 错误: ${errors_encountered}"
