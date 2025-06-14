#!/bin/bash
# process_manager.sh
# 进程检测和管理模块 - Bash版本
# 支持多种VS Code变体的检测和强制结束

# 全局变量
PROCESS_CONFIG_FILE=""
DETECTED_PROCESSES=()

# 加载进程配置
load_process_config() {
    local config_path="${1:-}"
    
    if [[ -z "${config_path}" ]]; then
        config_path="$(dirname "${BASH_SOURCE[0]}")/../config/process_config.json"
    fi
    
    if [[ ! -f "${config_path}" ]]; then
        log_warn "进程配置文件未找到: ${config_path}"
        return 1
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        log_error "需要jq命令来解析配置文件"
        return 1
    fi
    
    PROCESS_CONFIG_FILE="${config_path}"
    log_info "✓ 进程配置加载成功"
    return 0
}

# 检测所有支持的VS Code进程
find_vscode_processes() {
    local detailed="${1:-false}"
    
    if [[ -z "${PROCESS_CONFIG_FILE}" ]] || [[ ! -f "${PROCESS_CONFIG_FILE}" ]]; then
        log_warn "进程配置未加载，使用默认配置"
        if ! load_process_config; then
            return 1
        fi
    fi
    
    log_info "正在检测VS Code相关进程..."
    
    DETECTED_PROCESSES=()
    local process_types
    process_types=$(jq -r '.supported_processes | keys[]' "${PROCESS_CONFIG_FILE}")
    
    while IFS= read -r process_type; do
        local process_names
        process_names=$(jq -r ".supported_processes.${process_type}.process_names[]" "${PROCESS_CONFIG_FILE}")
        local display_name
        display_name=$(jq -r ".supported_processes.${process_type}.display_name" "${PROCESS_CONFIG_FILE}")
        local priority
        priority=$(jq -r ".supported_processes.${process_type}.priority" "${PROCESS_CONFIG_FILE}")
        
        while IFS= read -r process_name; do
            # 移除.exe扩展名（Linux/macOS不需要）
            local clean_name="${process_name%.exe}"
            
            # 使用pgrep查找进程
            local pids
            pids=$(pgrep -f "${clean_name}" 2>/dev/null || true)
            
            if [[ -n "${pids}" ]]; then
                while IFS= read -r pid; do
                    if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
                        local process_info="${pid}|${clean_name}|${display_name}|${priority}"
                        DETECTED_PROCESSES+=("${process_info}")
                        
                        if [[ "${detailed}" == "true" ]]; then
                            local cmd
                            cmd=$(ps -p "${pid}" -o comm= 2>/dev/null || echo "unknown")
                            local mem
                            mem=$(ps -p "${pid}" -o rss= 2>/dev/null || echo "0")
                            mem=$((mem / 1024))  # 转换为MB
                            
                            log_info "  发现进程: ${display_name} (PID: ${pid})"
                            log_debug "    进程名: ${cmd}"
                            log_debug "    内存使用: ${mem} MB"
                        fi
                    fi
                done <<< "${pids}"
            fi
        done <<< "${process_names}"
    done <<< "${process_types}"
    
    # 按优先级排序
    if [[ ${#DETECTED_PROCESSES[@]} -gt 1 ]]; then
        IFS=$'\n' DETECTED_PROCESSES=($(sort -t'|' -k4 -n <<< "${DETECTED_PROCESSES[*]}"))
        unset IFS
    fi
    
    if [[ ${#DETECTED_PROCESSES[@]} -gt 0 ]]; then
        log_warn "检测到 ${#DETECTED_PROCESSES[@]} 个VS Code相关进程"
    else
        log_success "未检测到VS Code相关进程"
    fi
    
    return 0
}

# 显示检测到的进程信息
show_detected_processes() {
    if [[ ${#DETECTED_PROCESSES[@]} -eq 0 ]]; then
        log_success "未检测到任何VS Code相关进程"
        return 0
    fi
    
    echo ""
    log_warn "检测到以下VS Code相关进程:"
    echo "============================================================"
    
    local index=1
    for process_info in "${DETECTED_PROCESSES[@]}"; do
        IFS='|' read -r pid process_name display_name priority <<< "${process_info}"
        
        echo "[$index] ${display_name}"
        echo "    进程ID: ${pid}"
        echo "    进程名: ${process_name}"
        
        # 获取更多进程信息
        if command -v ps >/dev/null 2>&1; then
            local start_time
            start_time=$(ps -p "${pid}" -o lstart= 2>/dev/null | xargs || echo "未知")
            local mem_mb
            mem_mb=$(ps -p "${pid}" -o rss= 2>/dev/null || echo "0")
            mem_mb=$((mem_mb / 1024))
            
            echo "    启动时间: ${start_time}"
            echo "    内存使用: ${mem_mb} MB"
        fi
        echo ""
        ((index++))
    done
}

# 用户交互选择
get_user_choice() {
    echo ""
    log_warn "请选择操作:"
    echo "[1] 强制关闭所有检测到的进程"
    echo "[2] 跳过进程检测，继续执行"
    echo "[3] 取消操作"
    echo ""
    
    while true; do
        read -p "请输入选择 (1-3): " choice
        case "${choice}" in
            1) echo "force_close"; return 0 ;;
            2) echo "skip"; return 0 ;;
            3) echo "cancel"; return 0 ;;
            *) log_error "无效选择，请输入 1、2 或 3" ;;
        esac
    done
}

# 优雅关闭进程
close_process_gracefully() {
    local pid="$1"
    local timeout="${2:-10}"
    local process_name="$3"
    
    log_info "尝试优雅关闭进程: ${process_name} (PID: ${pid})"
    
    # 发送TERM信号
    if kill -TERM "${pid}" 2>/dev/null; then
        log_debug "  发送TERM信号..."
        
        # 等待进程退出
        local count=0
        while [[ ${count} -lt ${timeout} ]] && kill -0 "${pid}" 2>/dev/null; do
            sleep 1
            ((count++))
        done
        
        if ! kill -0 "${pid}" 2>/dev/null; then
            log_success "  ✓ 进程已优雅关闭"
            return 0
        fi
    fi
    
    log_warn "  优雅关闭失败"
    return 1
}

# 强制结束进程
stop_process_forcefully() {
    local pid="$1"
    local timeout="${2:-5}"
    local process_name="$3"
    
    log_warn "强制结束进程: ${process_name} (PID: ${pid})"
    
    # 发送KILL信号
    if kill -KILL "${pid}" 2>/dev/null; then
        log_debug "  发送KILL信号..."
        
        # 等待确认结束
        local count=0
        while [[ ${count} -lt ${timeout} ]] && kill -0 "${pid}" 2>/dev/null; do
            sleep 1
            ((count++))
        done
        
        if ! kill -0 "${pid}" 2>/dev/null; then
            log_success "  ✓ 进程已强制结束"
            return 0
        else
            log_error "  ⚠ 进程可能未完全结束"
            return 1
        fi
    else
        log_error "  强制结束失败"
        return 1
    fi
}

# 关闭单个进程
close_single_process() {
    local process_info="$1"
    IFS='|' read -r pid process_name display_name priority <<< "${process_info}"
    
    log_info "关闭进程: ${display_name} (PID: ${pid})"
    
    # 检查进程是否还存在
    if ! kill -0 "${pid}" 2>/dev/null; then
        log_success "  ✓ 进程已退出"
        return 0
    fi
    
    # 尝试优雅关闭
    if close_process_gracefully "${pid}" 10 "${display_name}"; then
        return 0
    fi
    
    # 强制结束
    if stop_process_forcefully "${pid}" 5 "${display_name}"; then
        return 0
    fi
    
    log_error "  ✗ 所有关闭方法都失败了"
    return 1
}

# 关闭所有检测到的进程
close_all_detected_processes() {
    if [[ ${#DETECTED_PROCESSES[@]} -eq 0 ]]; then
        log_success "没有需要关闭的进程"
        return 0
    fi
    
    echo ""
    log_warn "开始关闭检测到的进程..."
    echo "=================================================="
    
    local success_count=0
    local fail_count=0
    
    for process_info in "${DETECTED_PROCESSES[@]}"; do
        if close_single_process "${process_info}"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
        
        sleep 0.5  # 短暂延迟
    done
    
    echo ""
    log_warn "进程关闭结果:"
    log_success "  成功关闭: ${success_count}"
    if [[ ${fail_count} -gt 0 ]]; then
        log_error "  关闭失败: ${fail_count}"
        return 1
    fi
    
    return 0
}

# 主要的进程检测和处理函数
invoke_process_detection_and_handling() {
    local auto_close="${1:-false}"
    local interactive="${2:-true}"

    echo ""
    log_info "=== VS Code 进程检测和管理 ==="

    # 加载配置
    if [[ -z "${PROCESS_CONFIG_FILE}" ]] || [[ ! -f "${PROCESS_CONFIG_FILE}" ]]; then
        if ! load_process_config; then
            log_warn "无法加载进程配置，跳过进程检测"
            return 0
        fi
    fi

    # 检测进程
    if ! find_vscode_processes true; then
        log_error "进程检测失败"
        return 1
    fi

    if [[ ${#DETECTED_PROCESSES[@]} -eq 0 ]]; then
        log_success "✓ 未检测到VS Code相关进程，可以安全继续"
        return 0
    fi

    # 显示检测到的进程
    show_detected_processes

    # 决定处理方式
    local action="prompt"
    if [[ "${auto_close}" == "true" ]]; then
        action="force_close"
    elif [[ "${interactive}" == "true" ]]; then
        action=$(get_user_choice)
    fi

    case "${action}" in
        "force_close")
            echo ""
            log_warn "正在强制关闭所有检测到的进程..."
            close_all_detected_processes
            return $?
            ;;
        "skip")
            echo ""
            log_warn "⚠ 跳过进程处理，继续执行（可能会遇到文件锁定问题）"
            return 0
            ;;
        "cancel")
            echo ""
            log_info "操作已取消"
            return 1
            ;;
        *)
            echo ""
            log_error "未知操作，取消执行"
            return 1
            ;;
    esac
}

# 导出函数（如果被source）
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f load_process_config
    export -f find_vscode_processes
    export -f show_detected_processes
    export -f close_all_detected_processes
    export -f invoke_process_detection_and_handling
fi
