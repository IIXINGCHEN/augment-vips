#!/bin/bash
# logging.sh
#
# Auto-fixed for readonly variable conflicts

# Prevent multiple loading
if [[ "${LOGGING_SH_LOADED:-}" == "true" ]]; then
    return 0
fi
if [[ -z "${LOGGING_SH_LOADED:-}" ]]; then
    readonly LOGGING_SH_LOADED="true"
fi

# core/logging.sh
#
# Enterprise-grade logging and audit system
# Production-ready with structured logging and compliance features
# Centralized logging with rotation and retention policies

set -euo pipefail

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Logging constants
if [[ -z "${LOG_FORMAT_SIMPLE:-}" ]]; then
    readonly LOG_FORMAT_SIMPLE="simple"
fi
if [[ -z "${LOG_FORMAT_JSON:-}" ]]; then
    readonly LOG_FORMAT_JSON="json"
fi
if [[ -z "${LOG_FORMAT_SYSLOG:-}" ]]; then
    readonly LOG_FORMAT_SYSLOG="syslog"
fi

if [[ -z "${LOG_ROTATION_SIZE:-}" ]]; then
    readonly LOG_ROTATION_SIZE=10485760  # 10MB
fi
if [[ -z "${LOG_RETENTION_DAYS:-}" ]]; then
    readonly LOG_RETENTION_DAYS=30
fi
if [[ -z "${MAX_LOG_FILES:-}" ]]; then
    readonly MAX_LOG_FILES=10
fi

# Global logging variables
LOG_FORMAT="${LOG_FORMAT_SIMPLE}"
LOG_ROTATION_ENABLED=true
STRUCTURED_LOGGING=false
REMOTE_LOGGING_ENABLED=false
REMOTE_LOG_SERVER=""

# Initialize advanced logging system
init_logging() {
    local config_file="${1:-config/logging.json}"
    
    log_info "Initializing advanced logging system..."
    
    # Load logging configuration if available
    if [[ -f "${config_file}" ]]; then
        load_logging_config "${config_file}"
    else
        log_warn "Logging config not found, using defaults: ${config_file}"
        set_default_logging_config
    fi
    
    # Setup log rotation if enabled
    if [[ "${LOG_ROTATION_ENABLED}" == "true" ]]; then
        setup_log_rotation
    fi
    
    # Initialize structured logging if enabled
    if [[ "${STRUCTURED_LOGGING}" == "true" ]]; then
        init_structured_logging
    fi
    
    audit_log "LOGGING_INIT" "Advanced logging system initialized"
    log_success "Advanced logging system initialized"
}

# Load logging configuration
load_logging_config() {
    local config_file="$1"
    
    if ! is_command_available jq; then
        log_warn "jq not available, using default logging config"
        return 0
    fi
    
    # Validate JSON format
    if ! jq empty "${config_file}" 2>/dev/null; then
        log_error "Invalid JSON format in logging config"
        return 1
    fi
    
    # Load configuration values
    LOG_FORMAT=$(jq -r '.format // "simple"' "${config_file}")
    LOG_ROTATION_ENABLED=$(jq -r '.rotation.enabled // true' "${config_file}")
    STRUCTURED_LOGGING=$(jq -r '.structured // false' "${config_file}")
    REMOTE_LOGGING_ENABLED=$(jq -r '.remote.enabled // false' "${config_file}")
    REMOTE_LOG_SERVER=$(jq -r '.remote.server // ""' "${config_file}")
    
    log_debug "Logging configuration loaded from: ${config_file}"
}

# Set default logging configuration
set_default_logging_config() {
    LOG_FORMAT="${LOG_FORMAT_SIMPLE}"
    LOG_ROTATION_ENABLED=true
    STRUCTURED_LOGGING=false
    REMOTE_LOGGING_ENABLED=false
    REMOTE_LOG_SERVER=""
    
    log_debug "Default logging configuration applied"
}

# Setup log rotation
setup_log_rotation() {
    log_debug "Setting up log rotation..."
    
    # Check current log file size
    if [[ -f "${LOG_FILE}" ]]; then
        local file_size
        file_size=$(stat -f%z "${LOG_FILE}" 2>/dev/null || stat -c%s "${LOG_FILE}" 2>/dev/null)
        
        if [[ ${file_size} -gt ${LOG_ROTATION_SIZE} ]]; then
            rotate_log_file "${LOG_FILE}"
        fi
    fi
    
    # Check audit log file size
    if [[ -f "${AUDIT_LOG_FILE}" ]]; then
        local file_size
        file_size=$(stat -f%z "${AUDIT_LOG_FILE}" 2>/dev/null || stat -c%s "${AUDIT_LOG_FILE}" 2>/dev/null)
        
        if [[ ${file_size} -gt ${LOG_ROTATION_SIZE} ]]; then
            rotate_log_file "${AUDIT_LOG_FILE}"
        fi
    fi
}

# Rotate log file
rotate_log_file() {
    local log_file="$1"
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local rotated_file="${log_file}.${timestamp}"
    
    log_info "Rotating log file: ${log_file} -> ${rotated_file}"
    
    # Move current log to rotated file
    mv "${log_file}" "${rotated_file}"
    
    # Compress rotated file
    if is_command_available gzip; then
        gzip "${rotated_file}"
        rotated_file="${rotated_file}.gz"
    fi
    
    # Create new log file
    touch "${log_file}"
    chmod 644 "${log_file}"
    
    # Clean up old log files
    cleanup_old_logs "$(dirname "${log_file}")" "$(basename "${log_file}")"
    
    audit_log "LOG_ROTATION" "Log file rotated: ${log_file} -> ${rotated_file}"
}

# Clean up old log files
cleanup_old_logs() {
    local log_dir="$1"
    local log_basename="$2"
    
    # Find and remove old log files beyond retention period
    find "${log_dir}" -name "${log_basename}.*" -type f -mtime +${LOG_RETENTION_DAYS} -delete 2>/dev/null || true
    
    # Limit number of log files
    local log_files
    mapfile -t log_files < <(find "${log_dir}" -name "${log_basename}.*" -type f | sort -r)
    
    if [[ ${#log_files[@]} -gt ${MAX_LOG_FILES} ]]; then
        local files_to_remove=("${log_files[@]:${MAX_LOG_FILES}}")
        for file in "${files_to_remove[@]}"; do
            rm -f "${file}"
            log_debug "Removed old log file: ${file}"
        done
    fi
}

# Initialize structured logging
init_structured_logging() {
    log_debug "Initializing structured logging..."
    
    # Create structured log file
    local structured_log_file="${LOG_FILE%.log}_structured.log"
    touch "${structured_log_file}"
    chmod 644 "${structured_log_file}"
    
    # Initialize with metadata
    local metadata=$(create_log_metadata)
    echo "${metadata}" >> "${structured_log_file}"
    
    log_debug "Structured logging initialized: ${structured_log_file}"
}

# Create log metadata
create_log_metadata() {
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')
    local hostname=$(hostname)
    local user="${USER:-unknown}"
    local pid=$$
    
    if [[ "${LOG_FORMAT}" == "${LOG_FORMAT_JSON}" ]]; then
        jq -n \
            --arg timestamp "${timestamp}" \
            --arg hostname "${hostname}" \
            --arg user "${user}" \
            --arg pid "${pid}" \
            --arg version "${SCRIPT_VERSION}" \
            '{
                "@timestamp": $timestamp,
                "hostname": $hostname,
                "user": $user,
                "pid": ($pid | tonumber),
                "version": $version,
                "event_type": "session_start"
            }'
    else
        echo "${timestamp} [SESSION_START] hostname=${hostname} user=${user} pid=${pid} version=${SCRIPT_VERSION}"
    fi
}

# Enhanced logging functions with structured support
log_structured() {
    local level="$1"
    local message="$2"
    local component="${3:-main}"
    local action="${4:-}"
    local resource="${5:-}"
    
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')
    local hostname=$(hostname)
    local user="${USER:-unknown}"
    local pid=$$
    local caller="${BASH_SOURCE[3]##*/}:${BASH_LINENO[2]}"
    
    # Create structured log entry
    local log_entry
    if [[ "${LOG_FORMAT}" == "${LOG_FORMAT_JSON}" ]]; then
        log_entry=$(jq -n \
            --arg timestamp "${timestamp}" \
            --arg level "${level}" \
            --arg message "${message}" \
            --arg component "${component}" \
            --arg action "${action}" \
            --arg resource "${resource}" \
            --arg hostname "${hostname}" \
            --arg user "${user}" \
            --arg pid "${pid}" \
            --arg caller "${caller}" \
            '{
                "@timestamp": $timestamp,
                "level": $level,
                "message": $message,
                "component": $component,
                "action": $action,
                "resource": $resource,
                "hostname": $hostname,
                "user": $user,
                "pid": ($pid | tonumber),
                "caller": $caller
            }')
    else
        log_entry="${timestamp} [${level}] [${component}] ${message}"
        if [[ -n "${action}" ]]; then
            log_entry="${log_entry} action=${action}"
        fi
        if [[ -n "${resource}" ]]; then
            log_entry="${log_entry} resource=${resource}"
        fi
        log_entry="${log_entry} caller=${caller}"
    fi
    
    # Write to structured log file if enabled
    if [[ "${STRUCTURED_LOGGING}" == "true" ]]; then
        local structured_log_file="${LOG_FILE%.log}_structured.log"
        echo "${log_entry}" >> "${structured_log_file}"
    fi
    
    # Send to remote logging if enabled
    if [[ "${REMOTE_LOGGING_ENABLED}" == "true" && -n "${REMOTE_LOG_SERVER}" ]]; then
        send_remote_log "${log_entry}"
    fi
    
    # Also use standard logging
    log_message "${level}" "${message}"
}

# Send log to remote server
send_remote_log() {
    local log_entry="$1"
    
    if is_command_available curl; then
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "${log_entry}" \
            "${REMOTE_LOG_SERVER}/logs" \
            >/dev/null 2>&1 || log_debug "Failed to send remote log"
    fi
}

# Performance logging
log_performance() {
    local operation="$1"
    local start_time="$2"
    local end_time="${3:-$(date +%s.%3N)}"
    local resource="${4:-}"
    
    local duration
    duration=$(echo "${end_time} - ${start_time}" | bc -l 2>/dev/null || echo "0")
    
    local message="Operation completed in ${duration}s"
    
    if [[ "${STRUCTURED_LOGGING}" == "true" ]]; then
        log_structured "INFO" "${message}" "performance" "${operation}" "${resource}"
    else
        log_info "${message} (operation: ${operation})"
    fi
    
    audit_log "PERFORMANCE" "operation=${operation} duration=${duration}s resource=${resource}"
}

# Security event logging
log_security_event() {
    local event_type="$1"
    local severity="$2"
    local description="$3"
    local user="${4:-${USER:-unknown}}"
    local resource="${5:-}"
    
    local message="Security event: ${event_type} - ${description}"
    
    if [[ "${STRUCTURED_LOGGING}" == "true" ]]; then
        log_structured "${severity}" "${message}" "security" "${event_type}" "${resource}"
    else
        log_message "${severity}" "${message}"
    fi
    
    # Always audit security events
    audit_log "SECURITY_EVENT" "type=${event_type} severity=${severity} user=${user} resource=${resource} description=${description}"
    
    # Send immediate alert for critical security events
    if [[ "${severity}" == "ERROR" ]]; then
        send_security_alert "${event_type}" "${description}" "${user}"
    fi
}

# Send security alert
send_security_alert() {
    local event_type="$1"
    local description="$2"
    local user="$3"
    
    local alert_message="SECURITY ALERT: ${event_type} by ${user} - ${description}"
    
    # Log to system log if available
    if is_command_available logger; then
        logger -p auth.crit "${alert_message}"
    fi
    
    # Send to remote monitoring if configured
    if [[ "${REMOTE_LOGGING_ENABLED}" == "true" && -n "${REMOTE_LOG_SERVER}" ]]; then
        local alert_payload
        alert_payload=$(jq -n \
            --arg timestamp "$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')" \
            --arg event_type "${event_type}" \
            --arg description "${description}" \
            --arg user "${user}" \
            --arg severity "critical" \
            '{
                "@timestamp": $timestamp,
                "alert_type": "security",
                "event_type": $event_type,
                "description": $description,
                "user": $user,
                "severity": $severity
            }')
        
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "${alert_payload}" \
            "${REMOTE_LOG_SERVER}/alerts" \
            >/dev/null 2>&1 || true
    fi
}

# Log analysis functions
analyze_logs() {
    local log_file="${1:-${LOG_FILE}}"
    local analysis_type="${2:-summary}"
    
    log_info "Analyzing logs: ${log_file} (type: ${analysis_type})"
    
    if [[ ! -f "${log_file}" ]]; then
        log_error "Log file not found: ${log_file}"
        return 1
    fi
    
    case "${analysis_type}" in
        "summary")
            generate_log_summary "${log_file}"
            ;;
        "errors")
            extract_error_logs "${log_file}"
            ;;
        "security")
            extract_security_events "${log_file}"
            ;;
        "performance")
            analyze_performance_logs "${log_file}"
            ;;
        *)
            log_error "Unknown analysis type: ${analysis_type}"
            return 1
            ;;
    esac
}

# Generate log summary
generate_log_summary() {
    local log_file="$1"
    
    local total_lines
    total_lines=$(wc -l < "${log_file}")
    
    local error_count
    error_count=$(grep -c "\[ERROR\]" "${log_file}" || echo "0")
    
    local warn_count
    warn_count=$(grep -c "\[WARN\]" "${log_file}" || echo "0")
    
    local info_count
    info_count=$(grep -c "\[INFO\]" "${log_file}" || echo "0")
    
    log_info "Log Summary for ${log_file}:"
    log_info "  Total lines: ${total_lines}"
    log_info "  Errors: ${error_count}"
    log_info "  Warnings: ${warn_count}"
    log_info "  Info: ${info_count}"
}

# Extract error logs
extract_error_logs() {
    local log_file="$1"
    local error_log="${log_file%.log}_errors.log"
    
    grep "\[ERROR\]" "${log_file}" > "${error_log}" || true
    
    local error_count
    error_count=$(wc -l < "${error_log}")
    
    log_info "Extracted ${error_count} error entries to: ${error_log}"
}

# Extract security events
extract_security_events() {
    local log_file="$1"
    local security_log="${log_file%.log}_security.log"
    
    grep -E "(SECURITY|AUTH|VIOLATION)" "${log_file}" > "${security_log}" || true
    
    local event_count
    event_count=$(wc -l < "${security_log}")
    
    log_info "Extracted ${event_count} security events to: ${security_log}"
}

# Analyze performance logs
analyze_performance_logs() {
    local log_file="$1"
    
    # Extract performance entries
    local perf_entries
    perf_entries=$(grep "PERFORMANCE" "${log_file}" || echo "")
    
    if [[ -z "${perf_entries}" ]]; then
        log_info "No performance entries found"
        return 0
    fi
    
    # Basic performance analysis
    local operation_count
    operation_count=$(echo "${perf_entries}" | wc -l)
    
    log_info "Performance Analysis:"
    log_info "  Total operations: ${operation_count}"
    
    # Extract unique operations
    local unique_operations
    unique_operations=$(echo "${perf_entries}" | grep -o "operation=[^ ]*" | sort | uniq -c | sort -nr)
    
    log_info "  Operations by frequency:"
    while IFS= read -r line; do
        log_info "    ${line}"
    done <<< "${unique_operations}"
}

# Export logging functions
export -f init_logging log_structured log_performance log_security_event analyze_logs
export LOG_FORMAT LOG_ROTATION_ENABLED STRUCTURED_LOGGING

log_debug "Advanced logging module loaded"
