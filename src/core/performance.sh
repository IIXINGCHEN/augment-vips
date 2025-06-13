#!/bin/bash
# performance.sh
#
# Auto-fixed for readonly variable conflicts

# Prevent multiple loading
if [[ "${PERFORMANCE_SH_LOADED:-}" == "true" ]]; then
    return 0
fi
if [[ -z "${PERFORMANCE_SH_LOADED:-}" ]]; then
    readonly PERFORMANCE_SH_LOADED="true"
fi

# core/performance.sh
#
# Enterprise-grade performance optimization and batch processing for VS Code database operations
# Production-ready with memory management, parallel processing and performance monitoring
# Supports large-scale data migration with optimized resource utilization

set -euo pipefail

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/security.sh"
source "$(dirname "${BASH_SOURCE[0]}")/validation.sh"
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

# Performance optimization constants
if [[ -z "${PERFORMANCE_VERSION:-}" ]]; then
    readonly PERFORMANCE_VERSION="1.0.0"
fi
if [[ -z "${DEFAULT_BATCH_SIZE:-}" ]]; then
    readonly DEFAULT_BATCH_SIZE=1000
fi
if [[ -z "${MAX_BATCH_SIZE:-}" ]]; then
    readonly MAX_BATCH_SIZE=10000
fi
if [[ -z "${MIN_BATCH_SIZE:-}" ]]; then
    readonly MIN_BATCH_SIZE=100
fi
if [[ -z "${MEMORY_THRESHOLD_MB:-}" ]]; then
    readonly MEMORY_THRESHOLD_MB=512
fi
if [[ -z "${CPU_THRESHOLD_PERCENT:-}" ]]; then
    readonly CPU_THRESHOLD_PERCENT=80
fi

# Performance monitoring intervals
if [[ -z "${MONITOR_INTERVAL_SECONDS:-}" ]]; then
    readonly MONITOR_INTERVAL_SECONDS=5
fi
if [[ -z "${PERFORMANCE_LOG_FILE:-}" ]]; then
    readonly PERFORMANCE_LOG_FILE="logs/performance.log"
fi

# Batch processing strategies
if [[ -z "${BATCH_STRATEGIES:-}" ]]; then
    readonly BATCH_STRATEGIES=("fixed_size" "adaptive" "memory_based" "time_based")
fi

# Global performance statistics
declare -A PERFORMANCE_STATS=()
declare -A BATCH_METRICS=()
declare -A RESOURCE_USAGE=()

# Initialize performance optimization system
init_performance() {
    log_info "初始化性能优化系统 v${PERFORMANCE_VERSION}..."
    
    # Create performance log directory
    mkdir -p "$(dirname "${PERFORMANCE_LOG_FILE}")"
    
    # Initialize performance statistics
    PERFORMANCE_STATS["operations_processed"]=0
    PERFORMANCE_STATS["total_processing_time"]=0
    PERFORMANCE_STATS["average_batch_time"]=0
    PERFORMANCE_STATS["peak_memory_usage"]=0
    PERFORMANCE_STATS["peak_cpu_usage"]=0
    PERFORMANCE_STATS["batches_processed"]=0
    PERFORMANCE_STATS["optimization_applied"]=0
    
    # Initialize batch metrics
    BATCH_METRICS["optimal_batch_size"]=${DEFAULT_BATCH_SIZE}
    BATCH_METRICS["current_strategy"]="fixed_size"
    BATCH_METRICS["last_adjustment_time"]=0
    
    # Initialize resource monitoring
    start_resource_monitoring
    
    audit_log "PERFORMANCE_INIT" "性能优化系统已初始化"
    log_success "性能优化系统初始化完成"
}

# Start resource monitoring in background
start_resource_monitoring() {
    log_debug "启动资源监控"
    
    # Start background monitoring process
    {
        while true; do
            monitor_system_resources
            sleep "${MONITOR_INTERVAL_SECONDS}"
        done
    } &
    
    local monitor_pid=$!
    echo "${monitor_pid}" > "logs/performance_monitor.pid"
    
    log_debug "资源监控已启动，PID: ${monitor_pid}"
}

# Monitor system resources
monitor_system_resources() {
    # Get memory usage
    local memory_usage
    if command -v free >/dev/null 2>&1; then
        memory_usage=$(free -m | awk 'NR==2{printf "%.1f", $3*100/$2}')
    elif command -v vm_stat >/dev/null 2>&1; then
        # macOS
        memory_usage=$(vm_stat | awk '/Pages active/ {active=$3} /Pages free/ {free=$3} /Pages inactive/ {inactive=$3} END {total=active+free+inactive; used=active+inactive; printf "%.1f", used*100/total}')
    else
        memory_usage="0"
    fi
    
    # Get CPU usage
    local cpu_usage
    if command -v top >/dev/null 2>&1; then
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "0")
    else
        cpu_usage="0"
    fi
    
    # Update resource usage
    RESOURCE_USAGE["memory_percent"]="${memory_usage}"
    RESOURCE_USAGE["cpu_percent"]="${cpu_usage}"
    RESOURCE_USAGE["last_update"]=$(date +%s)
    
    # Update peak usage
    if (( $(echo "${memory_usage} > ${PERFORMANCE_STATS["peak_memory_usage"]}" | bc -l 2>/dev/null || echo "0") )); then
        PERFORMANCE_STATS["peak_memory_usage"]="${memory_usage}"
    fi
    
    if (( $(echo "${cpu_usage} > ${PERFORMANCE_STATS["peak_cpu_usage"]}" | bc -l 2>/dev/null || echo "0") )); then
        PERFORMANCE_STATS["peak_cpu_usage"]="${cpu_usage}"
    fi
    
    # Log resource usage
    echo "$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ'),${memory_usage},${cpu_usage}" >> "${PERFORMANCE_LOG_FILE}"
}

# Optimize batch size based on system performance
optimize_batch_size() {
    local current_batch_size="$1"
    local processing_time="$2"
    local memory_usage="${3:-${RESOURCE_USAGE["memory_percent"]}}"
    local cpu_usage="${4:-${RESOURCE_USAGE["cpu_percent"]}}"
    
    log_debug "优化批处理大小: 当前=${current_batch_size}, 时间=${processing_time}s"
    
    local optimal_size=${current_batch_size}
    local adjustment_factor=1.0
    
    # Analyze performance metrics
    if (( $(echo "${memory_usage} > ${MEMORY_THRESHOLD_MB}" | bc -l 2>/dev/null || echo "0") )); then
        # High memory usage - reduce batch size
        adjustment_factor=0.8
        log_debug "内存使用率高 (${memory_usage}%)，减少批处理大小"
    elif (( $(echo "${cpu_usage} > ${CPU_THRESHOLD_PERCENT}" | bc -l 2>/dev/null || echo "0") )); then
        # High CPU usage - reduce batch size
        adjustment_factor=0.9
        log_debug "CPU使用率高 (${cpu_usage}%)，减少批处理大小"
    elif (( $(echo "${processing_time} < 1.0" | bc -l 2>/dev/null || echo "0") )); then
        # Fast processing - increase batch size
        adjustment_factor=1.2
        log_debug "处理速度快 (${processing_time}s)，增加批处理大小"
    fi
    
    # Calculate new optimal size
    optimal_size=$(echo "${current_batch_size} * ${adjustment_factor}" | bc -l 2>/dev/null | cut -d'.' -f1)
    
    # Apply constraints
    if [[ ${optimal_size} -lt ${MIN_BATCH_SIZE} ]]; then
        optimal_size=${MIN_BATCH_SIZE}
    elif [[ ${optimal_size} -gt ${MAX_BATCH_SIZE} ]]; then
        optimal_size=${MAX_BATCH_SIZE}
    fi
    
    # Update batch metrics
    BATCH_METRICS["optimal_batch_size"]=${optimal_size}
    BATCH_METRICS["last_adjustment_time"]=$(date +%s)
    
    if [[ ${optimal_size} -ne ${current_batch_size} ]]; then
        ((PERFORMANCE_STATS["optimization_applied"]++))
        log_info "批处理大小已优化: ${current_batch_size} -> ${optimal_size}"
    fi
    
    echo "${optimal_size}"
}

# Process data in optimized batches
process_data_in_batches() {
    local data="$1"
    local processing_function="$2"
    local initial_batch_size="${3:-${DEFAULT_BATCH_SIZE}}"
    local strategy="${4:-adaptive}"
    
    log_info "开始批量处理数据，策略: ${strategy}"
    
    # Count total records
    local total_records=0
    if [[ -n "${data}" ]]; then
        total_records=$(echo "${data}" | wc -l)
    fi
    
    if [[ ${total_records} -eq 0 ]]; then
        log_warn "没有数据需要处理"
        return 0
    fi
    
    log_info "总记录数: ${total_records}"
    
    local current_batch_size=${initial_batch_size}
    local processed_records=0
    local batch_number=0
    local total_start_time=$(date +%s.%3N)
    
    # Process data in batches
    while [[ ${processed_records} -lt ${total_records} ]]; do
        ((batch_number++))
        local batch_start_time=$(date +%s.%3N)
        
        # Extract batch data
        local batch_data
        batch_data=$(echo "${data}" | sed -n "${processed_records},$((processed_records + current_batch_size - 1))p")
        
        local batch_size=$(echo "${batch_data}" | wc -l)
        log_debug "处理批次 ${batch_number}: ${batch_size} 条记录"
        
        # Process batch
        if ! "${processing_function}" "${batch_data}"; then
            log_error "批次 ${batch_number} 处理失败"
            return 1
        fi
        
        local batch_end_time=$(date +%s.%3N)
        local batch_duration=$(echo "${batch_end_time} - ${batch_start_time}" | bc -l 2>/dev/null || echo "0")
        
        # Update statistics
        ((PERFORMANCE_STATS["batches_processed"]++))
        PERFORMANCE_STATS["total_processing_time"]=$(echo "${PERFORMANCE_STATS["total_processing_time"]} + ${batch_duration}" | bc -l 2>/dev/null || echo "${PERFORMANCE_STATS["total_processing_time"]}")
        
        # Calculate average batch time
        PERFORMANCE_STATS["average_batch_time"]=$(echo "${PERFORMANCE_STATS["total_processing_time"]} / ${PERFORMANCE_STATS["batches_processed"]}" | bc -l 2>/dev/null || echo "0")
        
        # Update processed count
        processed_records=$((processed_records + batch_size))
        ((PERFORMANCE_STATS["operations_processed"] += batch_size))
        
        # Report progress
        local progress=$((processed_records * 100 / total_records))
        log_info "批量处理进度: ${processed_records}/${total_records} (${progress}%) - 批次耗时: ${batch_duration}s"
        
        # Optimize batch size for next iteration
        if [[ "${strategy}" == "adaptive" ]]; then
            current_batch_size=$(optimize_batch_size "${current_batch_size}" "${batch_duration}")
        fi
        
        # Check if we should continue
        if [[ ${processed_records} -ge ${total_records} ]]; then
            break
        fi
    done
    
    local total_end_time=$(date +%s.%3N)
    local total_duration=$(echo "${total_end_time} - ${total_start_time}" | bc -l 2>/dev/null || echo "0")
    
    log_success "批量处理完成: ${processed_records} 条记录，${batch_number} 个批次，总耗时: ${total_duration}s"
    
    # Update batch metrics
    BATCH_METRICS["current_strategy"]="${strategy}"
    
    return 0
}

# Optimize database operations for performance
optimize_database_operations() {
    local db_file="$1"
    
    log_info "优化数据库操作性能: ${db_file}"
    
    # Set SQLite pragmas for better performance
    local optimization_commands=(
        "PRAGMA synchronous = OFF;"
        "PRAGMA journal_mode = MEMORY;"
        "PRAGMA cache_size = 10000;"
        "PRAGMA temp_store = MEMORY;"
        "PRAGMA mmap_size = 268435456;"  # 256MB
        "PRAGMA page_size = 4096;"
    )
    
    for command in "${optimization_commands[@]}"; do
        if sqlite3 "${db_file}" "${command}" 2>/dev/null; then
            log_debug "应用优化: ${command}"
        else
            log_warn "优化失败: ${command}"
        fi
    done
    
    ((PERFORMANCE_STATS["optimization_applied"]++))
    log_success "数据库性能优化完成"
}

# Restore database performance settings
restore_database_performance() {
    local db_file="$1"
    
    log_info "恢复数据库性能设置: ${db_file}"
    
    # Restore default SQLite pragmas
    local restore_commands=(
        "PRAGMA synchronous = FULL;"
        "PRAGMA journal_mode = DELETE;"
        "PRAGMA cache_size = 2000;"
        "PRAGMA temp_store = DEFAULT;"
        "PRAGMA mmap_size = 0;"
    )
    
    for command in "${restore_commands[@]}"; do
        if sqlite3 "${db_file}" "${command}" 2>/dev/null; then
            log_debug "恢复设置: ${command}"
        else
            log_warn "恢复失败: ${command}"
        fi
    done
    
    log_success "数据库性能设置已恢复"
}

# Stop resource monitoring
stop_resource_monitoring() {
    log_debug "停止资源监控"

    local pid_file="logs/performance_monitor.pid"
    if [[ -f "${pid_file}" ]]; then
        local monitor_pid
        monitor_pid=$(cat "${pid_file}")

        if kill -0 "${monitor_pid}" 2>/dev/null; then
            kill "${monitor_pid}" 2>/dev/null || true
            log_debug "资源监控已停止，PID: ${monitor_pid}"
        fi

        rm -f "${pid_file}"
    fi
}

# Get performance statistics
get_performance_stats() {
    log_info "性能优化统计信息:"
    for stat_name in "${!PERFORMANCE_STATS[@]}"; do
        log_info "  ${stat_name}: ${PERFORMANCE_STATS["${stat_name}"]}"
    done

    log_info ""
    log_info "批处理指标:"
    for metric_name in "${!BATCH_METRICS[@]}"; do
        log_info "  ${metric_name}: ${BATCH_METRICS["${metric_name}"]}"
    done

    log_info ""
    log_info "资源使用情况:"
    for resource_name in "${!RESOURCE_USAGE[@]}"; do
        log_info "  ${resource_name}: ${RESOURCE_USAGE["${resource_name}"]}"
    done
}

# Generate performance report
generate_performance_report() {
    local report_file="${1:-performance_report_$(get_timestamp).txt}"

    log_info "生成性能报告: ${report_file}"

    # Calculate performance metrics
    local throughput=0
    if [[ ${PERFORMANCE_STATS["total_processing_time"]} != "0" ]]; then
        throughput=$(echo "${PERFORMANCE_STATS["operations_processed"]} / ${PERFORMANCE_STATS["total_processing_time"]}" | bc -l 2>/dev/null || echo "0")
    fi

    {
        echo "性能优化系统报告"
        echo "版本: ${PERFORMANCE_VERSION}"
        echo "生成时间: $(date)"
        echo "=========================="
        echo ""
        echo "性能统计:"
        for stat_name in "${!PERFORMANCE_STATS[@]}"; do
            echo "  ${stat_name}: ${PERFORMANCE_STATS["${stat_name}"]}"
        done
        echo "  throughput_records_per_second: ${throughput}"
        echo ""
        echo "批处理指标:"
        for metric_name in "${!BATCH_METRICS[@]}"; do
            echo "  ${metric_name}: ${BATCH_METRICS["${metric_name}"]}"
        done
        echo ""
        echo "资源使用情况:"
        for resource_name in "${!RESOURCE_USAGE[@]}"; do
            echo "  ${resource_name}: ${RESOURCE_USAGE["${resource_name}"]}"
        done
        echo ""
        echo "配置信息:"
        echo "  默认批处理大小: ${DEFAULT_BATCH_SIZE}"
        echo "  最大批处理大小: ${MAX_BATCH_SIZE}"
        echo "  最小批处理大小: ${MIN_BATCH_SIZE}"
        echo "  内存阈值: ${MEMORY_THRESHOLD_MB}%"
        echo "  CPU阈值: ${CPU_THRESHOLD_PERCENT}%"
        echo ""
        echo "支持的批处理策略:"
        for strategy in "${BATCH_STRATEGIES[@]}"; do
            echo "  - ${strategy}"
        done

    } > "${report_file}"

    log_success "性能报告已生成: ${report_file}"
}

# Test performance optimization
test_performance_optimization() {
    log_info "测试性能优化功能"

    # Create test data
    local test_data=""
    for i in {1..1000}; do
        test_data="${test_data}{\"key\":\"test.key.${i}\",\"value\":\"test_value_${i}\"}\n"
    done

    # Define test processing function
    test_processing_function() {
        local batch_data="$1"
        local batch_size=$(echo "${batch_data}" | wc -l)

        # Simulate processing time
        sleep 0.1

        log_debug "处理了 ${batch_size} 条测试记录"
        return 0
    }

    # Test batch processing
    if process_data_in_batches "${test_data}" "test_processing_function" 100 "adaptive"; then
        log_success "性能优化功能测试通过"
        return 0
    else
        log_error "性能优化功能测试失败"
        return 1
    fi
}

# Analyze performance bottlenecks
analyze_performance_bottlenecks() {
    log_info "分析性能瓶颈"

    local bottlenecks=()

    # Check average batch time
    local avg_batch_time=${PERFORMANCE_STATS["average_batch_time"]}
    if (( $(echo "${avg_batch_time} > 5.0" | bc -l 2>/dev/null || echo "0") )); then
        bottlenecks+=("批处理时间过长: ${avg_batch_time}s")
    fi

    # Check memory usage
    local memory_usage=${RESOURCE_USAGE["memory_percent"]}
    if (( $(echo "${memory_usage} > ${MEMORY_THRESHOLD_MB}" | bc -l 2>/dev/null || echo "0") )); then
        bottlenecks+=("内存使用率过高: ${memory_usage}%")
    fi

    # Check CPU usage
    local cpu_usage=${RESOURCE_USAGE["cpu_percent"]}
    if (( $(echo "${cpu_usage} > ${CPU_THRESHOLD_PERCENT}" | bc -l 2>/dev/null || echo "0") )); then
        bottlenecks+=("CPU使用率过高: ${cpu_usage}%")
    fi

    # Check optimization effectiveness
    local optimizations=${PERFORMANCE_STATS["optimization_applied"]}
    local batches=${PERFORMANCE_STATS["batches_processed"]}
    if [[ ${batches} -gt 0 && ${optimizations} -eq 0 ]]; then
        bottlenecks+=("未应用性能优化")
    fi

    if [[ ${#bottlenecks[@]} -eq 0 ]]; then
        log_success "未发现性能瓶颈"
    else
        log_warn "发现性能瓶颈:"
        for bottleneck in "${bottlenecks[@]}"; do
            log_warn "  - ${bottleneck}"
        done
    fi

    return ${#bottlenecks[@]}
}

# Recommend performance improvements
recommend_performance_improvements() {
    log_info "性能改进建议"

    local recommendations=()

    # Analyze current performance
    local avg_batch_time=${PERFORMANCE_STATS["average_batch_time"]}
    local memory_usage=${RESOURCE_USAGE["memory_percent"]}
    local cpu_usage=${RESOURCE_USAGE["cpu_percent"]}
    local current_batch_size=${BATCH_METRICS["optimal_batch_size"]}

    # Batch size recommendations
    if (( $(echo "${avg_batch_time} > 3.0" | bc -l 2>/dev/null || echo "0") )); then
        recommendations+=("减少批处理大小以提高响应性")
    elif (( $(echo "${avg_batch_time} < 0.5" | bc -l 2>/dev/null || echo "0") )); then
        recommendations+=("增加批处理大小以提高吞吐量")
    fi

    # Memory recommendations
    if (( $(echo "${memory_usage} > 70" | bc -l 2>/dev/null || echo "0") )); then
        recommendations+=("启用内存优化模式")
        recommendations+=("减少缓存大小")
    fi

    # CPU recommendations
    if (( $(echo "${cpu_usage} > 70" | bc -l 2>/dev/null || echo "0") )); then
        recommendations+=("启用并行处理")
        recommendations+=("优化算法复杂度")
    fi

    # Strategy recommendations
    local current_strategy=${BATCH_METRICS["current_strategy"]}
    if [[ "${current_strategy}" == "fixed_size" ]]; then
        recommendations+=("考虑使用自适应批处理策略")
    fi

    if [[ ${#recommendations[@]} -eq 0 ]]; then
        log_info "当前性能配置已优化"
    else
        log_info "性能改进建议:"
        for recommendation in "${recommendations[@]}"; do
            log_info "  - ${recommendation}"
        done
    fi
}

# Reset performance statistics
reset_performance_stats() {
    log_info "重置性能统计"

    for stat_name in "${!PERFORMANCE_STATS[@]}"; do
        PERFORMANCE_STATS["${stat_name}"]=0
    done

    BATCH_METRICS["optimal_batch_size"]=${DEFAULT_BATCH_SIZE}
    BATCH_METRICS["current_strategy"]="fixed_size"
    BATCH_METRICS["last_adjustment_time"]=0

    log_success "性能统计已重置"
}

# Export performance functions
export -f init_performance start_resource_monitoring monitor_system_resources
export -f optimize_batch_size process_data_in_batches optimize_database_operations
export -f restore_database_performance stop_resource_monitoring get_performance_stats
export -f generate_performance_report test_performance_optimization analyze_performance_bottlenecks
export -f recommend_performance_improvements reset_performance_stats
export PERFORMANCE_STATS BATCH_METRICS RESOURCE_USAGE BATCH_STRATEGIES

log_debug "性能优化和批量处理模块已加载"
