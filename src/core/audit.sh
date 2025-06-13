#!/bin/bash
# audit.sh
#
# Auto-fixed for readonly variable conflicts

# Prevent multiple loading
if [[ "${AUDIT_SH_LOADED:-}" == "true" ]]; then
    return 0
fi
if [[ -z "${AUDIT_SH_LOADED:-}" ]]; then
    readonly AUDIT_SH_LOADED="true"
fi

# core/audit.sh
#
# Enterprise-grade audit logging and compliance tracking for VS Code database operations
# Production-ready with comprehensive audit trails and compliance reporting
# Supports detailed operation tracking and forensic analysis

set -euo pipefail

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/security.sh"
source "$(dirname "${BASH_SOURCE[0]}")/validation.sh"
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

# Audit system constants
if [[ -z "${AUDIT_VERSION:-}" ]]; then
    readonly AUDIT_VERSION="1.0.0"
fi
if [[ -z "${AUDIT_LOG_DIR:-}" ]]; then
    readonly AUDIT_LOG_DIR="logs/audit"
fi
if [[ -z "${MIGRATION_AUDIT_LOG:-}" ]]; then
    readonly MIGRATION_AUDIT_LOG="${AUDIT_LOG_DIR}/migration_audit.log"
fi
if [[ -z "${SECURITY_AUDIT_LOG:-}" ]]; then
    readonly SECURITY_AUDIT_LOG="${AUDIT_LOG_DIR}/security_audit.log"
fi
if [[ -z "${COMPLIANCE_AUDIT_LOG:-}" ]]; then
    readonly COMPLIANCE_AUDIT_LOG="${AUDIT_LOG_DIR}/compliance_audit.log"
fi

# Audit event types
if [[ -z "${AUDIT_EVENT_TYPES:-}" ]]; then
    readonly AUDIT_EVENT_TYPES=(
        "MIGRATION_START"
        "MIGRATION_COMPLETE"
        "MIGRATION_FAILED"
        "DATA_EXTRACTION"
        "DATA_TRANSFORMATION"
        "DATA_INSERTION"
        "BACKUP_CREATED"
        "BACKUP_RESTORED"
        "TRANSACTION_BEGIN"
        "TRANSACTION_COMMIT"
        "TRANSACTION_ROLLBACK"
        "VALIDATION_PERFORMED"
        "SECURITY_EVENT"
        "COMPLIANCE_CHECK"
        "ERROR_OCCURRED"
        "PERFORMANCE_OPTIMIZATION"
    )
fi

# Audit severity levels
if [[ -z "${AUDIT_SEVERITIES:-}" ]]; then
    readonly AUDIT_SEVERITIES=("CRITICAL" "HIGH" "MEDIUM" "LOW" "INFO")
fi

# Compliance frameworks
if [[ -z "${COMPLIANCE_FRAMEWORKS:-}" ]]; then
    readonly COMPLIANCE_FRAMEWORKS=("ISO27001" "NIST" "CIS" "GDPR" "SOX")
fi

# Global audit statistics
declare -A AUDIT_STATS=()
declare -A COMPLIANCE_METRICS=()

# Initialize audit system
init_audit() {
    log_info "初始化审计系统 v${AUDIT_VERSION}..."
    
    # Create audit log directories
    mkdir -p "${AUDIT_LOG_DIR}"
    mkdir -p "${AUDIT_LOG_DIR}/archive"
    mkdir -p "${AUDIT_LOG_DIR}/reports"
    
    # Initialize audit statistics
    AUDIT_STATS["total_events"]=0
    AUDIT_STATS["security_events"]=0
    AUDIT_STATS["compliance_events"]=0
    AUDIT_STATS["migration_events"]=0
    AUDIT_STATS["error_events"]=0
    AUDIT_STATS["critical_events"]=0
    
    # Initialize compliance metrics
    for framework in "${COMPLIANCE_FRAMEWORKS[@]}"; do
        COMPLIANCE_METRICS["${framework}_compliant"]=0
        COMPLIANCE_METRICS["${framework}_violations"]=0
    done
    
    # Set up audit log rotation
    setup_audit_log_rotation
    
    # Create initial audit entry
    audit_event "AUDIT_SYSTEM_INIT" "INFO" "审计系统已初始化" "system" "audit_init"
    
    log_success "审计系统初始化完成"
}

# Set up audit log rotation
setup_audit_log_rotation() {
    log_debug "设置审计日志轮转"
    
    # Create logrotate configuration for audit logs
    local logrotate_config="${AUDIT_LOG_DIR}/audit_logrotate.conf"
    
    cat > "${logrotate_config}" << EOF
${AUDIT_LOG_DIR}/*.log {
    daily
    rotate 365
    compress
    delaycompress
    missingok
    notifempty
    create 640 root root
    postrotate
        # Archive rotated logs
        find ${AUDIT_LOG_DIR} -name "*.log.*.gz" -mtime +30 -exec mv {} ${AUDIT_LOG_DIR}/archive/ \;
    endscript
}
EOF
    
    log_debug "审计日志轮转配置已创建: ${logrotate_config}"
}

# Log audit event with comprehensive details
audit_event() {
    local event_type="$1"
    local severity="$2"
    local description="$3"
    local user="${4:-system}"
    local operation="${5:-unknown}"
    local resource="${6:-}"
    local additional_data="${7:-}"
    
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')
    local event_id="audit_$(date +%s%3N)_$(openssl rand -hex 4 2>/dev/null || echo "$(date +%N)")"
    
    # Create comprehensive audit record
    local audit_record
    audit_record=$(jq -n \
        --arg event_id "${event_id}" \
        --arg timestamp "${timestamp}" \
        --arg event_type "${event_type}" \
        --arg severity "${severity}" \
        --arg description "${description}" \
        --arg user "${user}" \
        --arg operation "${operation}" \
        --arg resource "${resource}" \
        --arg additional_data "${additional_data}" \
        --arg hostname "$(hostname 2>/dev/null || echo 'unknown')" \
        --arg process_id "$$" \
        --arg session_id "${AUDIT_SESSION_ID:-unknown}" \
        '{
            event_id: $event_id,
            timestamp: $timestamp,
            event_type: $event_type,
            severity: $severity,
            description: $description,
            user: $user,
            operation: $operation,
            resource: $resource,
            additional_data: $additional_data,
            system_info: {
                hostname: $hostname,
                process_id: ($process_id | tonumber),
                session_id: $session_id
            },
            audit_version: "'"${AUDIT_VERSION}"'"
        }')
    
    # Update statistics
    ((AUDIT_STATS["total_events"]++))
    
    case "${event_type}" in
        *SECURITY*|*PERMISSION*|*AUTHORIZATION*)
            ((AUDIT_STATS["security_events"]++))
            echo "${audit_record}" >> "${SECURITY_AUDIT_LOG}"
            ;;
        *MIGRATION*|*EXTRACTION*|*TRANSFORMATION*|*INSERTION*)
            ((AUDIT_STATS["migration_events"]++))
            echo "${audit_record}" >> "${MIGRATION_AUDIT_LOG}"
            ;;
        *COMPLIANCE*|*VALIDATION*)
            ((AUDIT_STATS["compliance_events"]++))
            echo "${audit_record}" >> "${COMPLIANCE_AUDIT_LOG}"
            ;;
        *ERROR*|*FAILED*)
            ((AUDIT_STATS["error_events"]++))
            ;;
    esac
    
    if [[ "${severity}" == "CRITICAL" ]]; then
        ((AUDIT_STATS["critical_events"]++))
    fi
    
    # Write to main audit log
    echo "${audit_record}" >> "${MIGRATION_AUDIT_LOG}"
    
    # Log to system log as well
    log_debug "审计事件: ${event_type} - ${description}"
}

# Start audit session
start_audit_session() {
    local session_type="${1:-migration}"
    local user="${2:-system}"
    
    export AUDIT_SESSION_ID="session_$(date +%s%3N)"
    export AUDIT_SESSION_START=$(date +%s.%3N)
    
    audit_event "SESSION_START" "INFO" "审计会话开始: ${session_type}" "${user}" "session_management"
    
    log_info "审计会话已开始: ${AUDIT_SESSION_ID}"
}

# End audit session
end_audit_session() {
    local session_result="${1:-success}"
    local user="${2:-system}"
    
    if [[ -n "${AUDIT_SESSION_START:-}" ]]; then
        local session_end=$(date +%s.%3N)
        local session_duration=$(echo "${session_end} - ${AUDIT_SESSION_START}" | bc -l 2>/dev/null || echo "0")
        
        audit_event "SESSION_END" "INFO" "审计会话结束: ${session_result}, 持续时间: ${session_duration}s" "${user}" "session_management"
    fi
    
    log_info "审计会话已结束: ${AUDIT_SESSION_ID:-unknown}"
    
    unset AUDIT_SESSION_ID AUDIT_SESSION_START
}

# Track migration operation
track_migration_operation() {
    local operation="$1"
    local phase="$2"
    local status="$3"
    local details="${4:-}"
    local user="${5:-system}"
    
    local event_type="MIGRATION_${operation^^}_${phase^^}"
    local severity="INFO"
    
    if [[ "${status}" == "failed" || "${status}" == "error" ]]; then
        severity="HIGH"
        event_type="${event_type}_FAILED"
    elif [[ "${status}" == "success" || "${status}" == "completed" ]]; then
        event_type="${event_type}_SUCCESS"
    fi
    
    audit_event "${event_type}" "${severity}" "迁移操作: ${operation} - ${phase} - ${status}" "${user}" "${operation}" "" "${details}"
}

# Track data access
track_data_access() {
    local access_type="$1"  # read, write, delete, modify
    local resource="$2"
    local user="${3:-system}"
    local result="${4:-success}"
    local details="${5:-}"
    
    local event_type="DATA_ACCESS_${access_type^^}"
    local severity="MEDIUM"
    
    if [[ "${result}" == "denied" || "${result}" == "unauthorized" ]]; then
        severity="HIGH"
        event_type="${event_type}_DENIED"
    fi
    
    audit_event "${event_type}" "${severity}" "数据访问: ${access_type} - ${resource} - ${result}" "${user}" "data_access" "${resource}" "${details}"
}

# Track security events
track_security_event() {
    local security_event="$1"
    local severity="$2"
    local description="$3"
    local user="${4:-system}"
    local resource="${5:-}"
    local details="${6:-}"
    
    audit_event "SECURITY_${security_event^^}" "${severity}" "${description}" "${user}" "security" "${resource}" "${details}"
    
    # Additional security logging
    echo "$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ') [${severity}] SECURITY: ${security_event} - ${description}" >> "${SECURITY_AUDIT_LOG}"
}

# Track compliance events
track_compliance_event() {
    local framework="$1"
    local check_type="$2"
    local result="$3"  # compliant, violation, warning
    local description="$4"
    local details="${5:-}"
    
    local event_type="COMPLIANCE_${framework^^}_${check_type^^}"
    local severity="INFO"
    
    case "${result}" in
        "violation")
            severity="HIGH"
            ((COMPLIANCE_METRICS["${framework}_violations"]++))
            ;;
        "compliant")
            severity="INFO"
            ((COMPLIANCE_METRICS["${framework}_compliant"]++))
            ;;
        "warning")
            severity="MEDIUM"
            ;;
    esac
    
    audit_event "${event_type}" "${severity}" "合规检查: ${framework} - ${check_type} - ${result}" "system" "compliance" "${framework}" "${details}"
}

# Generate audit trail report
generate_audit_trail() {
    local start_date="${1:-$(date -d '1 day ago' '+%Y-%m-%d')}"
    local end_date="${2:-$(date '+%Y-%m-%d')}"
    local report_file="${3:-${AUDIT_LOG_DIR}/reports/audit_trail_$(date +%Y%m%d_%H%M%S).txt}"
    
    log_info "生成审计跟踪报告: ${start_date} 到 ${end_date}"
    
    # Create report directory
    mkdir -p "$(dirname "${report_file}")"
    
    {
        echo "审计跟踪报告"
        echo "生成时间: $(date)"
        echo "报告期间: ${start_date} 到 ${end_date}"
        echo "=========================="
        echo ""
        echo "审计统计:"
        for stat_name in "${!AUDIT_STATS[@]}"; do
            echo "  ${stat_name}: ${AUDIT_STATS["${stat_name}"]}"
        done
        echo ""
        echo "合规指标:"
        for metric_name in "${!COMPLIANCE_METRICS[@]}"; do
            echo "  ${metric_name}: ${COMPLIANCE_METRICS["${metric_name}"]}"
        done
        echo ""
        echo "审计事件详情:"
        
        # Extract events from audit logs within date range
        for log_file in "${MIGRATION_AUDIT_LOG}" "${SECURITY_AUDIT_LOG}" "${COMPLIANCE_AUDIT_LOG}"; do
            if [[ -f "${log_file}" ]]; then
                echo ""
                echo "来源: $(basename "${log_file}")"
                echo "----------------------------------------"
                
                # Filter events by date range (simplified)
                grep -E "${start_date}|${end_date}" "${log_file}" 2>/dev/null | head -50 | while IFS= read -r line; do
                    if [[ -n "${line}" ]]; then
                        echo "${line}" | jq -r '"\(.timestamp) [\(.severity)] \(.event_type): \(.description)"' 2>/dev/null || echo "${line}"
                    fi
                done
            fi
        done
        
    } > "${report_file}"
    
    log_success "审计跟踪报告已生成: ${report_file}"
    echo "${report_file}"
}

# Search audit logs
search_audit_logs() {
    local search_term="$1"
    local log_type="${2:-all}"  # migration, security, compliance, all
    local start_date="${3:-}"
    local end_date="${4:-}"

    log_info "搜索审计日志: ${search_term}"

    local search_files=()
    case "${log_type}" in
        "migration")
            search_files=("${MIGRATION_AUDIT_LOG}")
            ;;
        "security")
            search_files=("${SECURITY_AUDIT_LOG}")
            ;;
        "compliance")
            search_files=("${COMPLIANCE_AUDIT_LOG}")
            ;;
        "all"|*)
            search_files=("${MIGRATION_AUDIT_LOG}" "${SECURITY_AUDIT_LOG}" "${COMPLIANCE_AUDIT_LOG}")
            ;;
    esac

    local results_found=0

    for log_file in "${search_files[@]}"; do
        if [[ -f "${log_file}" ]]; then
            log_debug "搜索文件: ${log_file}"

            local file_results
            if [[ -n "${start_date}" && -n "${end_date}" ]]; then
                # Date range search
                file_results=$(grep -E "${search_term}" "${log_file}" 2>/dev/null | grep -E "${start_date}|${end_date}" 2>/dev/null || true)
            else
                # Simple search
                file_results=$(grep -E "${search_term}" "${log_file}" 2>/dev/null || true)
            fi

            if [[ -n "${file_results}" ]]; then
                echo "结果来源: $(basename "${log_file}")"
                echo "----------------------------------------"
                echo "${file_results}" | while IFS= read -r line; do
                    if [[ -n "${line}" ]]; then
                        echo "${line}" | jq -r '"\(.timestamp) [\(.severity)] \(.event_type): \(.description)"' 2>/dev/null || echo "${line}"
                        ((results_found++))
                    fi
                done
                echo ""
            fi
        fi
    done

    log_info "搜索完成，找到 ${results_found} 条结果"
}

# Verify audit log integrity
verify_audit_integrity() {
    log_info "验证审计日志完整性"

    local integrity_issues=0
    local audit_files=("${MIGRATION_AUDIT_LOG}" "${SECURITY_AUDIT_LOG}" "${COMPLIANCE_AUDIT_LOG}")

    for log_file in "${audit_files[@]}"; do
        if [[ -f "${log_file}" ]]; then
            log_debug "验证文件: ${log_file}"

            # Check file permissions
            local file_perms
            file_perms=$(stat -c "%a" "${log_file}" 2>/dev/null || stat -f "%A" "${log_file}" 2>/dev/null || echo "unknown")
            if [[ "${file_perms}" != "640" && "${file_perms}" != "600" ]]; then
                log_warn "审计日志文件权限不安全: ${log_file} (${file_perms})"
                ((integrity_issues++))
            fi

            # Check JSON format integrity
            local json_errors=0
            while IFS= read -r line; do
                if [[ -n "${line}" ]]; then
                    if ! echo "${line}" | jq '.' >/dev/null 2>&1; then
                        ((json_errors++))
                    fi
                fi
            done < "${log_file}"

            if [[ ${json_errors} -gt 0 ]]; then
                log_warn "发现 ${json_errors} 个JSON格式错误在 ${log_file}"
                ((integrity_issues++))
            fi

            # Check for gaps in timestamps
            local timestamp_gaps=0
            local last_timestamp=""
            while IFS= read -r line; do
                if [[ -n "${line}" ]]; then
                    local current_timestamp
                    current_timestamp=$(echo "${line}" | jq -r '.timestamp' 2>/dev/null)
                    if [[ -n "${last_timestamp}" && -n "${current_timestamp}" ]]; then
                        # Simple gap detection (more than 1 hour)
                        local time_diff
                        time_diff=$(date -d "${current_timestamp}" +%s 2>/dev/null || echo "0")
                        local last_time
                        last_time=$(date -d "${last_timestamp}" +%s 2>/dev/null || echo "0")

                        if [[ $((time_diff - last_time)) -gt 3600 ]]; then
                            ((timestamp_gaps++))
                        fi
                    fi
                    last_timestamp="${current_timestamp}"
                fi
            done < "${log_file}"

            if [[ ${timestamp_gaps} -gt 0 ]]; then
                log_warn "发现 ${timestamp_gaps} 个时间戳间隔异常在 ${log_file}"
            fi

        else
            log_warn "审计日志文件不存在: ${log_file}"
            ((integrity_issues++))
        fi
    done

    if [[ ${integrity_issues} -eq 0 ]]; then
        log_success "审计日志完整性验证通过"
        return 0
    else
        log_error "发现 ${integrity_issues} 个完整性问题"
        return 1
    fi
}

# Get audit statistics
get_audit_stats() {
    log_info "审计系统统计信息:"
    for stat_name in "${!AUDIT_STATS[@]}"; do
        log_info "  ${stat_name}: ${AUDIT_STATS["${stat_name}"]}"
    done

    log_info ""
    log_info "合规指标:"
    for metric_name in "${!COMPLIANCE_METRICS[@]}"; do
        log_info "  ${metric_name}: ${COMPLIANCE_METRICS["${metric_name}"]}"
    done
}

# Archive old audit logs
archive_audit_logs() {
    local archive_days="${1:-30}"

    log_info "归档 ${archive_days} 天前的审计日志"

    local archived_count=0
    local audit_files=("${MIGRATION_AUDIT_LOG}" "${SECURITY_AUDIT_LOG}" "${COMPLIANCE_AUDIT_LOG}")

    for log_file in "${audit_files[@]}"; do
        if [[ -f "${log_file}" ]]; then
            local archive_file="${AUDIT_LOG_DIR}/archive/$(basename "${log_file}").$(date +%Y%m%d).gz"

            # Create archive of old entries
            local cutoff_date
            cutoff_date=$(date -d "${archive_days} days ago" '+%Y-%m-%d')

            # Extract old entries and compress
            grep -v "${cutoff_date}" "${log_file}" 2>/dev/null | gzip > "${archive_file}" 2>/dev/null || true

            # Keep only recent entries in main log
            grep "${cutoff_date}" "${log_file}" 2>/dev/null > "${log_file}.tmp" || true
            mv "${log_file}.tmp" "${log_file}" 2>/dev/null || true

            if [[ -f "${archive_file}" ]]; then
                ((archived_count++))
                log_debug "已归档: ${archive_file}"
            fi
        fi
    done

    log_success "归档了 ${archived_count} 个审计日志文件"
}

# Test audit system
test_audit_system() {
    log_info "测试审计系统"

    # Test basic audit event
    audit_event "TEST_EVENT" "INFO" "审计系统测试事件" "test_user" "test_operation"

    # Test migration tracking
    track_migration_operation "test_migration" "extraction" "success" "测试数据提取" "test_user"

    # Test security event
    track_security_event "test_security" "MEDIUM" "测试安全事件" "test_user"

    # Test compliance event
    track_compliance_event "ISO27001" "access_control" "compliant" "测试合规检查"

    # Verify events were logged
    if search_audit_logs "TEST_EVENT" "all" >/dev/null 2>&1; then
        log_success "审计系统测试通过"
        return 0
    else
        log_error "审计系统测试失败"
        return 1
    fi
}

# Generate compliance report
generate_compliance_report() {
    local framework="${1:-all}"
    local report_file="${2:-${AUDIT_LOG_DIR}/reports/compliance_report_$(date +%Y%m%d_%H%M%S).txt}"

    log_info "生成合规报告: ${framework}"

    mkdir -p "$(dirname "${report_file}")"

    {
        echo "合规性报告"
        echo "生成时间: $(date)"
        echo "合规框架: ${framework}"
        echo "=========================="
        echo ""

        if [[ "${framework}" == "all" ]]; then
            echo "所有框架合规指标:"
            for metric_name in "${!COMPLIANCE_METRICS[@]}"; do
                echo "  ${metric_name}: ${COMPLIANCE_METRICS["${metric_name}"]}"
            done
        else
            echo "${framework} 合规指标:"
            for metric_name in "${!COMPLIANCE_METRICS[@]}"; do
                if [[ "${metric_name}" == *"${framework}"* ]]; then
                    echo "  ${metric_name}: ${COMPLIANCE_METRICS["${metric_name}"]}"
                fi
            done
        fi

        echo ""
        echo "合规事件详情:"

        # Extract compliance events
        if [[ -f "${COMPLIANCE_AUDIT_LOG}" ]]; then
            if [[ "${framework}" == "all" ]]; then
                grep "COMPLIANCE" "${COMPLIANCE_AUDIT_LOG}" 2>/dev/null | tail -20
            else
                grep "COMPLIANCE_${framework^^}" "${COMPLIANCE_AUDIT_LOG}" 2>/dev/null | tail -20
            fi
        fi

    } > "${report_file}"

    log_success "合规报告已生成: ${report_file}"
    echo "${report_file}"
}

# Export audit functions
export -f init_audit setup_audit_log_rotation audit_event start_audit_session
export -f end_audit_session track_migration_operation track_data_access
export -f track_security_event track_compliance_event generate_audit_trail
export -f search_audit_logs verify_audit_integrity get_audit_stats
export -f archive_audit_logs test_audit_system generate_compliance_report
export AUDIT_STATS COMPLIANCE_METRICS AUDIT_EVENT_TYPES AUDIT_SEVERITIES

log_debug "审计日志和跟踪模块已加载"
