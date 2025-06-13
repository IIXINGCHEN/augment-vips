#!/bin/bash
# vscode_backup.sh
#
# Auto-fixed for readonly variable conflicts

# Prevent multiple loading
if [[ "${VSCODE_BACKUP_SH_LOADED:-}" == "true" ]]; then
    return 0
fi
if [[ -z "${VSCODE_BACKUP_SH_LOADED:-}" ]]; then
    readonly VSCODE_BACKUP_SH_LOADED="true"
fi

# core/vscode_backup.sh
#
# VS Code环境备份模块
# 专门用于备份VS Code配置、扩展、会话记录等环境数据
# 集成到数据迁移系统的主要执行流程中

set -euo pipefail

# 模块版本和配置
if [[ -z "${VSCODE_BACKUP_VERSION:-}" ]]; then
    readonly VSCODE_BACKUP_VERSION="1.0.0"
fi
if [[ -z "${VSCODE_BACKUP_DIR_DEFAULT:-}" ]]; then
    readonly VSCODE_BACKUP_DIR_DEFAULT="backups/vscode_environment"
fi

# 全局变量
declare -A VSCODE_BACKUP_STATS=()
declare -A VSCODE_BACKUP_PATHS=()
declare -A VSCODE_BACKUP_REGISTRY=()

# 源依赖模块
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/paths.sh"
source "$(dirname "${BASH_SOURCE[0]}")/backup.sh"
source "$(dirname "${BASH_SOURCE[0]}")/audit.sh"

# 初始化VS Code备份模块
init_vscode_backup() {
    local backup_base_dir="${1:-${VSCODE_BACKUP_DIR_DEFAULT}}"
    
    log_info "初始化VS Code环境备份模块 v${VSCODE_BACKUP_VERSION}"
    
    # 设置备份目录
    VSCODE_BACKUP_PATHS["base_dir"]="$(realpath "${backup_base_dir}")"
    
    # 创建备份目录结构
    if ! create_vscode_backup_structure; then
        log_error "创建VS Code备份目录结构失败"
        return 1
    fi
    
    # 初始化统计
    VSCODE_BACKUP_STATS["configs_backed_up"]=0
    VSCODE_BACKUP_STATS["extensions_backed_up"]=0
    VSCODE_BACKUP_STATS["sessions_backed_up"]=0
    VSCODE_BACKUP_STATS["databases_backed_up"]=0
    VSCODE_BACKUP_STATS["total_files_backed_up"]=0
    VSCODE_BACKUP_STATS["backup_size_bytes"]=0
    VSCODE_BACKUP_STATS["errors_encountered"]=0
    
    # 发现VS Code安装路径
    if ! discover_vscode_installations; then
        log_warning "VS Code路径发现失败，某些备份功能可能不可用"
    fi
    
    audit_log "VSCODE_BACKUP_INIT" "VS Code环境备份模块已初始化: ${VSCODE_BACKUP_PATHS["base_dir"]}"
    log_success "VS Code环境备份模块初始化完成"
    return 0
}

# 创建VS Code备份目录结构
create_vscode_backup_structure() {
    local base_dir="${VSCODE_BACKUP_PATHS["base_dir"]}"
    
    log_debug "创建VS Code备份目录结构..."
    
    # 创建主备份目录
    if ! mkdir -p "${base_dir}"; then
        log_error "无法创建VS Code备份目录: ${base_dir}"
        return 1
    fi
    
    # 创建子目录
    local subdirs=(
        "configurations"    # 配置文件
        "extensions"       # 扩展数据
        "sessions"         # 会话记录
        "databases"        # 数据库文件
        "workspaces"       # 工作区设置
        "keybindings"      # 键盘绑定
        "snippets"         # 代码片段
        "themes"           # 主题设置
        "manifests"        # 备份清单
        "logs"             # 备份日志
    )
    
    for subdir in "${subdirs[@]}"; do
        local full_path="${base_dir}/${subdir}"
        if ! mkdir -p "${full_path}"; then
            log_error "无法创建VS Code备份子目录: ${full_path}"
            return 1
        fi
        VSCODE_BACKUP_PATHS["${subdir}"]="${full_path}"
    done
    
    # 设置适当的权限
    chmod 750 "${base_dir}"
    
    log_debug "VS Code备份目录结构创建成功"
    return 0
}

# 执行完整的VS Code环境备份
backup_vscode_environment() {
    local backup_type="${1:-full}"
    local description="${2:-VS Code环境自动备份}"
    local dry_run="${3:-false}"
    
    log_info "开始VS Code环境备份 (类型: ${backup_type})"
    
    if [[ "${dry_run}" == "true" ]]; then
        log_info "DRY RUN模式: 仅模拟备份过程"
    fi
    
    local start_time=$(date +%s.%3N)
    local backup_id="vscode_env_$(date +%Y%m%d_%H%M%S)"
    local backup_success=true
    
    # 创建备份清单
    local manifest_file="${VSCODE_BACKUP_PATHS["manifests"]}/${backup_id}_manifest.json"
    
    {
        echo "{"
        echo "  \"backup_id\": \"${backup_id}\","
        echo "  \"timestamp\": \"$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')\","
        echo "  \"backup_type\": \"${backup_type}\","
        echo "  \"description\": \"${description}\","
        echo "  \"dry_run\": ${dry_run},"
        echo "  \"version\": \"${VSCODE_BACKUP_VERSION}\","
        echo "  \"components\": {"
    } > "${manifest_file}"
    
    # 备份各个组件
    local component_count=0
    
    # 1. 备份配置文件
    if backup_vscode_configurations "${backup_id}" "${dry_run}"; then
        echo "    \"configurations\": true," >> "${manifest_file}"
        ((component_count++))
    else
        echo "    \"configurations\": false," >> "${manifest_file}"
        backup_success=false
    fi
    
    # 2. 备份扩展数据
    if backup_vscode_extensions "${backup_id}" "${dry_run}"; then
        echo "    \"extensions\": true," >> "${manifest_file}"
        ((component_count++))
    else
        echo "    \"extensions\": false," >> "${manifest_file}"
        backup_success=false
    fi
    
    # 3. 备份会话记录
    if backup_vscode_sessions "${backup_id}" "${dry_run}"; then
        echo "    \"sessions\": true," >> "${manifest_file}"
        ((component_count++))
    else
        echo "    \"sessions\": false," >> "${manifest_file}"
        backup_success=false
    fi
    
    # 4. 备份数据库文件
    if backup_vscode_databases "${backup_id}" "${dry_run}"; then
        echo "    \"databases\": true" >> "${manifest_file}"
        ((component_count++))
    else
        echo "    \"databases\": false" >> "${manifest_file}"
        backup_success=false
    fi
    
    # 完成清单文件
    {
        echo "  },"
        echo "  \"statistics\": {"
        echo "    \"components_backed_up\": ${component_count},"
        echo "    \"configs_backed_up\": ${VSCODE_BACKUP_STATS["configs_backed_up"]},"
        echo "    \"extensions_backed_up\": ${VSCODE_BACKUP_STATS["extensions_backed_up"]},"
        echo "    \"sessions_backed_up\": ${VSCODE_BACKUP_STATS["sessions_backed_up"]},"
        echo "    \"databases_backed_up\": ${VSCODE_BACKUP_STATS["databases_backed_up"]},"
        echo "    \"total_files_backed_up\": ${VSCODE_BACKUP_STATS["total_files_backed_up"]},"
        echo "    \"backup_size_bytes\": ${VSCODE_BACKUP_STATS["backup_size_bytes"]},"
        echo "    \"errors_encountered\": ${VSCODE_BACKUP_STATS["errors_encountered"]}"
        echo "  },"
        echo "  \"backup_success\": ${backup_success}"
        echo "}"
    } >> "${manifest_file}"
    
    local end_time=$(date +%s.%3N)
    log_performance "vscode_backup_complete" "${start_time}" "${end_time}" "${backup_id}"
    
    # 注册备份到全局备份系统
    if [[ "${backup_success}" == "true" ]]; then
        register_vscode_backup "${backup_id}" "${manifest_file}" "${backup_type}" "${description}"
        audit_log "VSCODE_BACKUP_SUCCESS" "VS Code环境备份成功: ${backup_id}"
        log_success "VS Code环境备份完成: ${backup_id}"
        echo "${backup_id}"
        return 0
    else
        audit_log "VSCODE_BACKUP_FAILED" "VS Code环境备份失败: ${backup_id}"
        log_error "VS Code环境备份失败: ${backup_id}"
        return 1
    fi
}

# 备份VS Code配置文件
backup_vscode_configurations() {
    local backup_id="$1"
    local dry_run="$2"
    
    log_info "备份VS Code配置文件..."
    
    local config_backup_dir="${VSCODE_BACKUP_PATHS["configurations"]}/${backup_id}"
    
    if [[ "${dry_run}" != "true" ]]; then
        mkdir -p "${config_backup_dir}"
    fi
    
    local configs_found=0
    
    # 备份用户设置
    for path_type in "${!VSCODE_PATHS[@]}"; do
        local vscode_path="${VSCODE_PATHS["${path_type}"]}"
        
        if [[ -d "${vscode_path}" ]]; then
            # 备份settings.json
            local settings_file="${vscode_path}/User/settings.json"
            if [[ -f "${settings_file}" ]]; then
                if [[ "${dry_run}" != "true" ]]; then
                    cp "${settings_file}" "${config_backup_dir}/settings_${path_type}.json"
                fi
                ((configs_found++))
                log_debug "备份设置文件: ${settings_file}"
            fi
            
            # 备份keybindings.json
            local keybindings_file="${vscode_path}/User/keybindings.json"
            if [[ -f "${keybindings_file}" ]]; then
                if [[ "${dry_run}" != "true" ]]; then
                    cp "${keybindings_file}" "${config_backup_dir}/keybindings_${path_type}.json"
                fi
                ((configs_found++))
                log_debug "备份键盘绑定: ${keybindings_file}"
            fi
            
            # 备份snippets目录
            local snippets_dir="${vscode_path}/User/snippets"
            if [[ -d "${snippets_dir}" ]]; then
                if [[ "${dry_run}" != "true" ]]; then
                    cp -r "${snippets_dir}" "${config_backup_dir}/snippets_${path_type}/"
                fi
                local snippet_count=$(find "${snippets_dir}" -name "*.json" | wc -l)
                configs_found=$((configs_found + snippet_count))
                log_debug "备份代码片段目录: ${snippets_dir} (${snippet_count}个文件)"
            fi
        fi
    done
    
    VSCODE_BACKUP_STATS["configs_backed_up"]=${configs_found}
    VSCODE_BACKUP_STATS["total_files_backed_up"]=$((VSCODE_BACKUP_STATS["total_files_backed_up"] + configs_found))
    
    if [[ ${configs_found} -gt 0 ]]; then
        log_success "配置文件备份完成: ${configs_found}个文件"
        return 0
    else
        log_warning "未找到VS Code配置文件"
        return 1
    fi
}

# 备份VS Code扩展数据
backup_vscode_extensions() {
    local backup_id="$1"
    local dry_run="$2"
    
    log_info "备份VS Code扩展数据..."
    
    local ext_backup_dir="${VSCODE_BACKUP_PATHS["extensions"]}/${backup_id}"
    
    if [[ "${dry_run}" != "true" ]]; then
        mkdir -p "${ext_backup_dir}"
    fi
    
    local extensions_found=0
    
    # 备份扩展列表和数据
    for path_type in "${!VSCODE_PATHS[@]}"; do
        local vscode_path="${VSCODE_PATHS["${path_type}"]}"
        
        if [[ -d "${vscode_path}" ]]; then
            # 备份扩展列表
            local extensions_dir="${vscode_path}/../extensions"
            if [[ -d "${extensions_dir}" ]]; then
                if [[ "${dry_run}" != "true" ]]; then
                    # 创建扩展列表
                    find "${extensions_dir}" -maxdepth 1 -type d -name "*.*" | \
                        sed 's|.*/||' > "${ext_backup_dir}/extensions_list_${path_type}.txt"
                fi
                local ext_count=$(find "${extensions_dir}" -maxdepth 1 -type d -name "*.*" | wc -l)
                extensions_found=$((extensions_found + ext_count))
                log_debug "发现扩展: ${ext_count}个 (${path_type})"
            fi
            
            # 备份全局存储中的扩展数据
            local global_storage="${vscode_path}/User/globalStorage"
            if [[ -d "${global_storage}" ]]; then
                if [[ "${dry_run}" != "true" ]]; then
                    cp -r "${global_storage}" "${ext_backup_dir}/globalStorage_${path_type}/"
                fi
                local storage_count=$(find "${global_storage}" -type f | wc -l)
                extensions_found=$((extensions_found + storage_count))
                log_debug "备份全局存储: ${storage_count}个文件"
            fi
        fi
    done
    
    VSCODE_BACKUP_STATS["extensions_backed_up"]=${extensions_found}
    VSCODE_BACKUP_STATS["total_files_backed_up"]=$((VSCODE_BACKUP_STATS["total_files_backed_up"] + extensions_found))
    
    if [[ ${extensions_found} -gt 0 ]]; then
        log_success "扩展数据备份完成: ${extensions_found}个项目"
        return 0
    else
        log_warning "未找到VS Code扩展数据"
        return 1
    fi
}

# 备份VS Code会话记录
backup_vscode_sessions() {
    local backup_id="$1"
    local dry_run="$2"
    
    log_info "备份VS Code会话记录..."
    
    local session_backup_dir="${VSCODE_BACKUP_PATHS["sessions"]}/${backup_id}"
    
    if [[ "${dry_run}" != "true" ]]; then
        mkdir -p "${session_backup_dir}"
    fi
    
    local sessions_found=0
    
    # 备份工作区存储
    for path_type in "${!VSCODE_PATHS[@]}"; do
        local vscode_path="${VSCODE_PATHS["${path_type}"]}"
        
        if [[ -d "${vscode_path}" ]]; then
            # 备份工作区存储
            local workspace_storage="${vscode_path}/User/workspaceStorage"
            if [[ -d "${workspace_storage}" ]]; then
                if [[ "${dry_run}" != "true" ]]; then
                    cp -r "${workspace_storage}" "${session_backup_dir}/workspaceStorage_${path_type}/"
                fi
                local workspace_count=$(find "${workspace_storage}" -type f | wc -l)
                sessions_found=$((sessions_found + workspace_count))
                log_debug "备份工作区存储: ${workspace_count}个文件"
            fi
            
            # 备份最近打开的文件列表
            local storage_file="${vscode_path}/User/storage.json"
            if [[ -f "${storage_file}" ]]; then
                if [[ "${dry_run}" != "true" ]]; then
                    cp "${storage_file}" "${session_backup_dir}/storage_${path_type}.json"
                fi
                ((sessions_found++))
                log_debug "备份存储文件: ${storage_file}"
            fi
        fi
    done
    
    VSCODE_BACKUP_STATS["sessions_backed_up"]=${sessions_found}
    VSCODE_BACKUP_STATS["total_files_backed_up"]=$((VSCODE_BACKUP_STATS["total_files_backed_up"] + sessions_found))
    
    if [[ ${sessions_found} -gt 0 ]]; then
        log_success "会话记录备份完成: ${sessions_found}个文件"
        return 0
    else
        log_warning "未找到VS Code会话记录"
        return 1
    fi
}

# 备份VS Code数据库文件
backup_vscode_databases() {
    local backup_id="$1"
    local dry_run="$2"
    
    log_info "备份VS Code数据库文件..."
    
    local db_backup_dir="${VSCODE_BACKUP_PATHS["databases"]}/${backup_id}"
    
    if [[ "${dry_run}" != "true" ]]; then
        mkdir -p "${db_backup_dir}"
    fi
    
    local databases_found=0
    
    # 获取所有数据库文件
    local db_files
    mapfile -t db_files < <(get_database_files 2>/dev/null || true)
    
    for db_file in "${db_files[@]}"; do
        if [[ -f "${db_file}" ]]; then
            local db_name=$(basename "${db_file}")
            local db_dir=$(dirname "${db_file}")
            local relative_path=${db_dir#*/}
            
            if [[ "${dry_run}" != "true" ]]; then
                # 创建相对路径目录
                mkdir -p "${db_backup_dir}/${relative_path}"
                # 备份数据库文件
                cp "${db_file}" "${db_backup_dir}/${relative_path}/${db_name}"
            fi
            
            ((databases_found++))
            log_debug "备份数据库: ${db_file}"
        fi
    done
    
    VSCODE_BACKUP_STATS["databases_backed_up"]=${databases_found}
    VSCODE_BACKUP_STATS["total_files_backed_up"]=$((VSCODE_BACKUP_STATS["total_files_backed_up"] + databases_found))
    
    if [[ ${databases_found} -gt 0 ]]; then
        log_success "数据库文件备份完成: ${databases_found}个文件"
        return 0
    else
        log_warning "未找到VS Code数据库文件"
        return 1
    fi
}

# 注册VS Code备份到系统
register_vscode_backup() {
    local backup_id="$1"
    local manifest_file="$2"
    local backup_type="$3"
    local description="$4"
    
    VSCODE_BACKUP_REGISTRY["${backup_id}"]="${manifest_file}"
    
    # 计算备份总大小
    local backup_size=0
    if [[ -d "${VSCODE_BACKUP_PATHS["base_dir"]}" ]]; then
        backup_size=$(du -sb "${VSCODE_BACKUP_PATHS["base_dir"]}" 2>/dev/null | cut -f1 || echo "0")
    fi
    VSCODE_BACKUP_STATS["backup_size_bytes"]=${backup_size}
    
    log_debug "VS Code备份已注册: ${backup_id} (${backup_size} 字节)"
}

# 生成VS Code备份报告
generate_vscode_backup_report() {
    local report_file="${1:-${VSCODE_BACKUP_PATHS["logs"]}/vscode_backup_report.txt}"
    
    log_info "生成VS Code备份报告: ${report_file}"
    
    {
        echo "=== VS Code环境备份报告 ==="
        echo "生成时间: $(date)"
        echo "模块版本: ${VSCODE_BACKUP_VERSION}"
        echo ""
        
        echo "=== 备份统计 ==="
        for stat_name in "${!VSCODE_BACKUP_STATS[@]}"; do
            echo "${stat_name}: ${VSCODE_BACKUP_STATS["${stat_name}"]}"
        done
        echo ""
        
        echo "=== 已注册的备份 ==="
        for backup_id in "${!VSCODE_BACKUP_REGISTRY[@]}"; do
            local manifest_file="${VSCODE_BACKUP_REGISTRY["${backup_id}"]}"
            echo "备份ID: ${backup_id}"
            echo "清单文件: ${manifest_file}"
            if [[ -f "${manifest_file}" ]]; then
                local backup_time=$(jq -r '.timestamp' "${manifest_file}" 2>/dev/null || echo "未知")
                local backup_type=$(jq -r '.backup_type' "${manifest_file}" 2>/dev/null || echo "未知")
                echo "备份时间: ${backup_time}"
                echo "备份类型: ${backup_type}"
            fi
            echo ""
        done
        
        echo "=== 备份目录结构 ==="
        for path_name in "${!VSCODE_BACKUP_PATHS[@]}"; do
            echo "${path_name}: ${VSCODE_BACKUP_PATHS["${path_name}"]}"
        done
        
    } > "${report_file}"
    
    log_success "VS Code备份报告已生成: ${report_file}"
}

# 恢复VS Code环境
restore_vscode_environment() {
    local backup_id="$1"
    local restore_components="${2:-all}"
    local dry_run="${3:-false}"

    log_info "开始恢复VS Code环境: ${backup_id}"

    # 查找备份清单
    local manifest_file="${VSCODE_BACKUP_PATHS["manifests"]}/${backup_id}_manifest.json"
    if [[ ! -f "${manifest_file}" ]]; then
        log_error "备份清单文件不存在: ${manifest_file}"
        return 1
    fi

    # 验证备份完整性
    if ! verify_vscode_backup_integrity "${backup_id}"; then
        log_error "备份完整性验证失败: ${backup_id}"
        return 1
    fi

    local start_time=$(date +%s.%3N)
    local restore_success=true

    # 根据组件类型恢复
    case "${restore_components}" in
        "all")
            restore_vscode_configurations "${backup_id}" "${dry_run}" || restore_success=false
            restore_vscode_extensions "${backup_id}" "${dry_run}" || restore_success=false
            restore_vscode_sessions "${backup_id}" "${dry_run}" || restore_success=false
            restore_vscode_databases "${backup_id}" "${dry_run}" || restore_success=false
            ;;
        "configurations")
            restore_vscode_configurations "${backup_id}" "${dry_run}" || restore_success=false
            ;;
        "extensions")
            restore_vscode_extensions "${backup_id}" "${dry_run}" || restore_success=false
            ;;
        "sessions")
            restore_vscode_sessions "${backup_id}" "${dry_run}" || restore_success=false
            ;;
        "databases")
            restore_vscode_databases "${backup_id}" "${dry_run}" || restore_success=false
            ;;
        *)
            log_error "无效的恢复组件: ${restore_components}"
            return 1
            ;;
    esac

    local end_time=$(date +%s.%3N)
    log_performance "vscode_restore_complete" "${start_time}" "${end_time}" "${backup_id}"

    if [[ "${restore_success}" == "true" ]]; then
        audit_log "VSCODE_RESTORE_SUCCESS" "VS Code环境恢复成功: ${backup_id}"
        log_success "VS Code环境恢复完成: ${backup_id}"
        return 0
    else
        audit_log "VSCODE_RESTORE_FAILED" "VS Code环境恢复失败: ${backup_id}"
        log_error "VS Code环境恢复失败: ${backup_id}"
        return 1
    fi
}

# 验证VS Code备份完整性
verify_vscode_backup_integrity() {
    local backup_id="$1"

    log_debug "验证VS Code备份完整性: ${backup_id}"

    local manifest_file="${VSCODE_BACKUP_PATHS["manifests"]}/${backup_id}_manifest.json"

    # 检查清单文件
    if [[ ! -f "${manifest_file}" ]]; then
        log_error "备份清单文件不存在: ${manifest_file}"
        return 1
    fi

    # 验证JSON格式
    if ! jq '.' "${manifest_file}" >/dev/null 2>&1; then
        log_error "备份清单文件格式无效: ${manifest_file}"
        return 1
    fi

    # 检查备份组件
    local components=(configurations extensions sessions databases)
    for component in "${components[@]}"; do
        local component_dir="${VSCODE_BACKUP_PATHS["${component}"]}/${backup_id}"
        local component_enabled=$(jq -r ".components.${component}" "${manifest_file}" 2>/dev/null)

        if [[ "${component_enabled}" == "true" ]]; then
            if [[ ! -d "${component_dir}" ]]; then
                log_error "备份组件目录不存在: ${component_dir}"
                return 1
            fi
        fi
    done

    log_debug "VS Code备份完整性验证通过: ${backup_id}"
    return 0
}

# 列出可用的VS Code备份
list_vscode_backups() {
    log_info "可用的VS Code环境备份:"

    local manifests_dir="${VSCODE_BACKUP_PATHS["manifests"]}"
    if [[ ! -d "${manifests_dir}" ]]; then
        log_warning "备份清单目录不存在: ${manifests_dir}"
        return 1
    fi

    local backup_count=0
    for manifest_file in "${manifests_dir}"/*_manifest.json; do
        if [[ -f "${manifest_file}" ]]; then
            local backup_id=$(basename "${manifest_file}" "_manifest.json")
            local timestamp=$(jq -r '.timestamp' "${manifest_file}" 2>/dev/null || echo "未知")
            local backup_type=$(jq -r '.backup_type' "${manifest_file}" 2>/dev/null || echo "未知")
            local backup_success=$(jq -r '.backup_success' "${manifest_file}" 2>/dev/null || echo "false")

            echo "  备份ID: ${backup_id}"
            echo "    时间: ${timestamp}"
            echo "    类型: ${backup_type}"
            echo "    状态: $(if [[ "${backup_success}" == "true" ]]; then echo "成功"; else echo "失败"; fi)"
            echo ""

            ((backup_count++))
        fi
    done

    if [[ ${backup_count} -eq 0 ]]; then
        log_info "没有找到VS Code环境备份"
    else
        log_info "总共找到 ${backup_count} 个备份"
    fi
}

# 清理过期的VS Code备份
cleanup_vscode_backups() {
    local retention_days="${1:-30}"
    local max_backups="${2:-10}"
    local dry_run="${3:-false}"

    log_info "清理过期的VS Code备份 (保留: ${retention_days}天, 最大: ${max_backups}个)"

    local manifests_dir="${VSCODE_BACKUP_PATHS["manifests"]}"
    if [[ ! -d "${manifests_dir}" ]]; then
        log_warning "备份清单目录不存在: ${manifests_dir}"
        return 0
    fi

    local current_time=$(date +%s)
    local retention_seconds=$((retention_days * 24 * 3600))
    local cleaned_count=0

    # 按时间排序备份文件
    local backup_files=()
    while IFS= read -r -d '' file; do
        backup_files+=("${file}")
    done < <(find "${manifests_dir}" -name "*_manifest.json" -print0 | sort -z)

    # 清理过期备份
    for manifest_file in "${backup_files[@]}"; do
        local file_time=$(stat -c %Y "${manifest_file}" 2>/dev/null || echo "0")
        local age_seconds=$((current_time - file_time))

        if [[ ${age_seconds} -gt ${retention_seconds} ]]; then
            local backup_id=$(basename "${manifest_file}" "_manifest.json")

            if [[ "${dry_run}" != "true" ]]; then
                remove_vscode_backup "${backup_id}"
            else
                log_info "DRY RUN: 将删除过期备份: ${backup_id}"
            fi

            ((cleaned_count++))
        fi
    done

    # 如果备份数量超过最大限制，删除最旧的备份
    local total_backups=${#backup_files[@]}
    if [[ ${total_backups} -gt ${max_backups} ]]; then
        local excess_count=$((total_backups - max_backups))

        for ((i=0; i<excess_count; i++)); do
            local manifest_file="${backup_files[i]}"
            local backup_id=$(basename "${manifest_file}" "_manifest.json")

            if [[ "${dry_run}" != "true" ]]; then
                remove_vscode_backup "${backup_id}"
            else
                log_info "DRY RUN: 将删除多余备份: ${backup_id}"
            fi

            ((cleaned_count++))
        done
    fi

    if [[ ${cleaned_count} -gt 0 ]]; then
        log_success "清理了 ${cleaned_count} 个VS Code备份"
    else
        log_info "没有需要清理的VS Code备份"
    fi
}

# 删除指定的VS Code备份
remove_vscode_backup() {
    local backup_id="$1"

    log_info "删除VS Code备份: ${backup_id}"

    # 删除各组件备份目录
    local components=(configurations extensions sessions databases)
    for component in "${components[@]}"; do
        local component_dir="${VSCODE_BACKUP_PATHS["${component}"]}/${backup_id}"
        if [[ -d "${component_dir}" ]]; then
            rm -rf "${component_dir}"
            log_debug "删除组件备份目录: ${component_dir}"
        fi
    done

    # 删除清单文件
    local manifest_file="${VSCODE_BACKUP_PATHS["manifests"]}/${backup_id}_manifest.json"
    if [[ -f "${manifest_file}" ]]; then
        rm -f "${manifest_file}"
        log_debug "删除备份清单: ${manifest_file}"
    fi

    # 从注册表中移除
    unset VSCODE_BACKUP_REGISTRY["${backup_id}"]

    audit_log "VSCODE_BACKUP_REMOVED" "VS Code备份已删除: ${backup_id}"
    log_success "VS Code备份删除完成: ${backup_id}"
}

# 导出函数
export -f init_vscode_backup backup_vscode_environment restore_vscode_environment
export -f backup_vscode_configurations backup_vscode_extensions
export -f backup_vscode_sessions backup_vscode_databases
export -f verify_vscode_backup_integrity list_vscode_backups
export -f cleanup_vscode_backups remove_vscode_backup
export -f generate_vscode_backup_report
export VSCODE_BACKUP_STATS VSCODE_BACKUP_PATHS VSCODE_BACKUP_REGISTRY

log_debug "VS Code环境备份模块已加载 v${VSCODE_BACKUP_VERSION}"
