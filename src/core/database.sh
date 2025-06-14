#!/bin/bash
# database.sh
#
# Auto-fixed for readonly variable conflicts

# Prevent multiple loading
if [[ "${DATABASE_SH_LOADED:-}" == "true" ]]; then
    return 0
fi
if [[ -z "${DATABASE_SH_LOADED:-}" ]]; then
    readonly DATABASE_SH_LOADED="true"
fi

# core/database.sh
#
# Enterprise-grade SQLite database operations module
# Production-ready with comprehensive safety and validation
# Zero-redundancy database cleaning with audit trails

set -euo pipefail

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/security.sh"
source "$(dirname "${BASH_SOURCE[0]}")/validation.sh"
source "$(dirname "${BASH_SOURCE[0]}")/backup.sh"
source "$(dirname "${BASH_SOURCE[0]}")/config_loader.sh"

# Database operation constants
if [[ -z "${DB_TIMEOUT:-}" ]]; then
    readonly DB_TIMEOUT=30
fi
if [[ -z "${MAX_DB_SIZE:-}" ]]; then
    readonly MAX_DB_SIZE=1073741824  # 1GB
fi
if [[ -z "${BACKUP_BEFORE_CLEAN:-}" ]]; then
    readonly BACKUP_BEFORE_CLEAN=true
fi

# Augment-related patterns loaded from unified configuration
# Note: AUGMENT_PATTERNS will be loaded by config_loader.sh

# Global database operation statistics
declare -A DB_STATS=()

# Initialize database module
init_database() {
    log_info "Initializing database operations module..."

    # Load unified configuration
    if ! load_augment_config; then
        log_error "Failed to load unified configuration"
        return 1
    fi

    # Validate that patterns were loaded
    if [[ ${#AUGMENT_PATTERNS[@]} -eq 0 ]]; then
        log_error "No Augment patterns loaded from configuration"
        return 1
    fi

    log_info "Loaded ${#AUGMENT_PATTERNS[@]} cleaning patterns from unified configuration"

    # Check SQLite availability
    if ! is_command_available sqlite3; then
        log_error "SQLite3 is required but not available"
        return 1
    fi

    # Verify SQLite functionality
    if ! verify_sqlite_functionality; then
        log_error "SQLite functionality verification failed"
        return 1
    fi

    # Initialize statistics
    DB_STATS["databases_processed"]=0
    DB_STATS["entries_removed"]=0
    DB_STATS["errors_encountered"]=0
    DB_STATS["backups_created"]=0

    audit_log "DATABASE_INIT" "Database operations module initialized with ${#AUGMENT_PATTERNS[@]} patterns"
    log_success "Database operations module initialized"
}

# Verify SQLite functionality
verify_sqlite_functionality() {
    log_debug "Verifying SQLite functionality..."
    
    # Test basic SQLite operations
    local test_db=":memory:"
    
    # Test table creation
    if ! sqlite3 "${test_db}" "CREATE TABLE test (id INTEGER PRIMARY KEY, data TEXT);" 2>/dev/null; then
        log_error "SQLite table creation test failed"
        return 1
    fi
    
    # Test data insertion
    if ! sqlite3 "${test_db}" "INSERT INTO test (data) VALUES ('test');" 2>/dev/null; then
        log_error "SQLite data insertion test failed"
        return 1
    fi
    
    # Test data selection
    if ! sqlite3 "${test_db}" "SELECT * FROM test;" >/dev/null 2>&1; then
        log_error "SQLite data selection test failed"
        return 1
    fi
    
    log_debug "SQLite functionality verification passed"
    return 0
}

# Clean VS Code database
clean_vscode_database() {
    local db_file="$1"
    local dry_run="${2:-false}"
    
    log_info "Cleaning VS Code database: ${db_file}"
    
    # Validate database file
    if ! validate_database_file "${db_file}"; then
        log_error "Database validation failed: ${db_file}"
        return 1
    fi
    
    # Authorize operation
    if ! authorize_operation "database_clean" "${db_file}"; then
        log_error "Database cleaning operation not authorized"
        return 1
    fi
    
    # Create backup if enabled
    local backup_file=""
    if [[ "${BACKUP_BEFORE_CLEAN}" == "true" && "${dry_run}" != "true" ]]; then
        backup_file=$(create_database_backup "${db_file}")
        if [[ -z "${backup_file}" ]]; then
            log_error "Failed to create backup for: ${db_file}"
            return 1
        fi
        ((DB_STATS["backups_created"]++))
    fi
    
    # Perform database cleaning with enhanced error handling
    local start_time=$(date +%s.%3N)
    local entries_removed=0

    if [[ "${dry_run}" == "true" ]]; then
        entries_removed=$(count_augment_entries "${db_file}")
        log_info "DRY RUN: Would remove ${entries_removed} entries from ${db_file}"
    else
        # Attempt database cleaning with retry mechanism
        local max_retries=3
        local retry_count=0
        local cleaning_success=false

        while [[ ${retry_count} -lt ${max_retries} && "${cleaning_success}" == "false" ]]; do
            if [[ ${retry_count} -gt 0 ]]; then
                log_info "Retry attempt ${retry_count}/${max_retries} for database cleaning"
                sleep $((retry_count * 2))  # Progressive delay
            fi

            entries_removed=$(remove_augment_entries "${db_file}")
            local remove_exit_code=$?

            if [[ ${remove_exit_code} -eq 0 && ${entries_removed} -ge 0 ]]; then
                log_success "Removed ${entries_removed} entries from ${db_file}"
                ((DB_STATS["databases_processed"]++))
                ((DB_STATS["entries_removed"] += entries_removed))
                cleaning_success=true
            else
                log_warn "Database cleaning attempt ${retry_count} failed"
                ((retry_count++))
            fi
        done

        if [[ "${cleaning_success}" == "false" ]]; then
            log_error "Failed to clean database after ${max_retries} attempts: ${db_file}"
            ((DB_STATS["errors_encountered"]++))

            # Restore from backup if cleaning failed
            if [[ -n "${backup_file}" && -f "${backup_file}" ]]; then
                log_info "Restoring database from backup due to cleaning failure"
                restore_database_backup "${backup_file}" "${db_file}"
            fi
            return 1
        fi
    fi
    
    local end_time=$(date +%s.%3N)
    log_performance "database_clean" "${start_time}" "${end_time}" "${db_file}"
    
    audit_log "DATABASE_CLEAN" "Database cleaned: ${db_file}, entries_removed=${entries_removed}, backup=${backup_file}"
    
    return 0
}

# Validate database file
validate_database_file() {
    local db_file="$1"
    
    log_debug "Validating database file: ${db_file}"
    
    # Check file existence and readability
    if [[ ! -f "${db_file}" ]]; then
        log_error "Database file does not exist: ${db_file}"
        return 1
    fi
    
    if [[ ! -r "${db_file}" ]]; then
        log_error "Database file not readable: ${db_file}"
        return 1
    fi
    
    # Check file size
    local file_size
    file_size=$(stat -f%z "${db_file}" 2>/dev/null || stat -c%s "${db_file}" 2>/dev/null)
    
    if [[ ${file_size} -eq 0 ]]; then
        log_error "Database file is empty: ${db_file}"
        return 1
    fi
    
    if [[ ${file_size} -gt ${MAX_DB_SIZE} ]]; then
        log_error "Database file too large (${file_size} > ${MAX_DB_SIZE}): ${db_file}"
        return 1
    fi
    
    # Validate SQLite file format
    if ! sqlite3 "${db_file}" "PRAGMA integrity_check;" >/dev/null 2>&1; then
        log_error "Database integrity check failed: ${db_file}"
        return 1
    fi
    
    # Check if database has expected VS Code structure
    if ! check_vscode_database_structure "${db_file}"; then
        log_warn "Database does not appear to be a VS Code database: ${db_file}"
        # Don't fail here, just warn
    fi
    
    log_debug "Database validation passed: ${db_file}"
    return 0
}

# Check VS Code database structure
check_vscode_database_structure() {
    local db_file="$1"
    
    # Check for common VS Code database tables
    local expected_tables=("ItemTable")
    
    for table in "${expected_tables[@]}"; do
        if ! sqlite3 "${db_file}" "SELECT name FROM sqlite_master WHERE type='table' AND name='${table}';" | grep -q "${table}"; then
            log_debug "Expected table not found: ${table}"
            return 1
        fi
    done
    
    return 0
}

# Count Augment-related entries
count_augment_entries() {
    local db_file="$1"
    local total_count=0
    
    log_debug "Counting Augment entries in: ${db_file}"
    
    # Count entries for each pattern
    for pattern in "${AUGMENT_PATTERNS[@]}"; do
        local count
        count=$(sqlite3 "${db_file}" "SELECT COUNT(*) FROM ItemTable WHERE key LIKE '${pattern}';" 2>/dev/null || echo "0")
        
        if [[ "${count}" =~ ^[0-9]+$ ]]; then
            ((total_count += count))
            if [[ ${count} -gt 0 ]]; then
                log_debug "Pattern '${pattern}': ${count} entries"
            fi
        fi
    done
    
    log_debug "Total Augment entries found: ${total_count}"
    echo "${total_count}"
}

# Database lock management
acquire_database_lock() {
    local db_file="$1"
    local lock_file="${db_file}.lock"
    local timeout="${2:-30}"
    local wait_time=0

    log_debug "Acquiring database lock: ${lock_file}"

    while [[ ${wait_time} -lt ${timeout} ]]; do
        if (set -C; echo $$ > "${lock_file}") 2>/dev/null; then
            log_debug "Database lock acquired successfully"
            echo "${lock_file}"
            return 0
        fi

        # Check if lock is stale (process no longer exists)
        if [[ -f "${lock_file}" ]]; then
            local lock_pid
            lock_pid=$(cat "${lock_file}" 2>/dev/null)
            if [[ -n "${lock_pid}" ]] && ! kill -0 "${lock_pid}" 2>/dev/null; then
                log_warn "Removing stale lock file: ${lock_file}"
                rm -f "${lock_file}"
                continue
            fi
        fi

        log_debug "Waiting for database lock... (${wait_time}/${timeout}s)"
        sleep 1
        ((wait_time++))
    done

    log_error "Failed to acquire database lock within ${timeout} seconds"
    return 1
}

# Release database lock
release_database_lock() {
    local lock_file="$1"

    if [[ -f "${lock_file}" ]]; then
        rm -f "${lock_file}"
        log_debug "Database lock released: ${lock_file}"
        audit_log "DATABASE_LOCK_RELEASE" "Lock released: ${lock_file}"
    fi
}

# Enhanced remove Augment-related entries with proper transaction management
remove_augment_entries() {
    local db_file="$1"
    local total_removed=0
    local lock_file=""

    log_debug "Removing Augment entries from: ${db_file}"

    # Acquire database lock to prevent concurrent access
    lock_file=$(acquire_database_lock "${db_file}" 30)
    if [[ $? -ne 0 ]]; then
        log_error "Failed to acquire database lock for: ${db_file}"
        return 1
    fi

    # Ensure lock is released on exit
    trap "release_database_lock '${lock_file}'" EXIT

    # Count entries before deletion for accurate reporting
    local entries_before
    entries_before=$(count_augment_entries "${db_file}")
    log_debug "Entries before deletion: ${entries_before}"

    if [[ ${entries_before} -eq 0 ]]; then
        log_info "No Augment entries found to remove"
        release_database_lock "${lock_file}"
        echo "0"
        return 0
    fi

    # Generate SQL using configuration-driven approach
    local delete_sql="BEGIN ${SQL_TRANSACTION_MODE} TRANSACTION;"

    # Build WHERE clause based on configuration
    local where_conditions=()
    for pattern in "${AUGMENT_PATTERNS[@]}"; do
        if [[ -n "${pattern}" ]]; then
            if [[ "${SQL_USE_LOWER_FUNCTION}" == "true" && "${SQL_CASE_SENSITIVE}" == "false" ]]; then
                where_conditions+=("LOWER(key) LIKE LOWER('${pattern}')")
            else
                where_conditions+=("key LIKE '${pattern}'")
            fi
        fi
    done

    # Combine conditions with OR
    local where_clause
    where_clause=$(IFS=' OR '; echo "${where_conditions[*]}")

    delete_sql="${delete_sql} DELETE FROM ItemTable WHERE ${where_clause}; COMMIT;"

    # Execute deletion with detailed error handling
    local delete_result
    delete_result=$(sqlite3 -cmd ".timeout ${DB_TIMEOUT}" "${db_file}" "${delete_sql}" 2>&1)
    local delete_exit_code=$?

    if [[ ${delete_exit_code} -eq 0 ]]; then
        # Verify deletion success
        local entries_after
        entries_after=$(count_augment_entries "${db_file}")
        total_removed=$((entries_before - entries_after))

        log_success "Successfully deleted ${total_removed} entries from ${db_file}"

        # Execute VACUUM separately to reclaim space (non-critical)
        log_debug "Executing VACUUM to reclaim space..."
        local vacuum_result
        vacuum_result=$(sqlite3 -cmd ".timeout ${DB_TIMEOUT}" "${db_file}" "VACUUM;" 2>&1)
        if [[ $? -eq 0 ]]; then
            log_debug "VACUUM completed successfully"
        else
            log_warn "VACUUM failed but deletion was successful: ${vacuum_result}"
        fi

        release_database_lock "${lock_file}"
        echo "${total_removed}"
        return 0
    else
        log_error "Database deletion failed: ${delete_result}"

        # Attempt retry for certain error types
        if [[ "${delete_result}" == *"database is locked"* ]]; then
            log_info "Retrying deletion after lock timeout..."
            sleep 2

            # Retry once
            delete_result=$(sqlite3 -cmd ".timeout $((DB_TIMEOUT * 2))" "${db_file}" "${delete_sql}" 2>&1)
            delete_exit_code=$?

            if [[ ${delete_exit_code} -eq 0 ]]; then
                local entries_after
                entries_after=$(count_augment_entries "${db_file}")
                total_removed=$((entries_before - entries_after))
                log_success "Retry successful: deleted ${total_removed} entries"
                release_database_lock "${lock_file}"
                echo "${total_removed}"
                return 0
            fi
        fi

        log_error "All deletion attempts failed for: ${db_file}"
        release_database_lock "${lock_file}"
        echo "0"
        return 1
    fi
}

# Create database backup
create_database_backup() {
    local db_file="$1"
    local timestamp=$(get_timestamp)
    local backup_file="${db_file}.backup_${timestamp}"
    
    log_debug "Creating database backup: ${db_file} -> ${backup_file}"
    
    # Use SQLite backup command for consistency
    if sqlite3 "${db_file}" ".backup '${backup_file}'" 2>/dev/null; then
        log_success "Database backup created: ${backup_file}"
        audit_log "DATABASE_BACKUP" "Backup created: ${db_file} -> ${backup_file}"
        echo "${backup_file}"
        return 0
    else
        log_error "Failed to create database backup: ${db_file}"
        return 1
    fi
}

# Restore database backup
restore_database_backup() {
    local backup_file="$1"
    local target_file="$2"
    
    log_info "Restoring database from backup: ${backup_file} -> ${target_file}"
    
    if [[ ! -f "${backup_file}" ]]; then
        log_error "Backup file does not exist: ${backup_file}"
        return 1
    fi
    
    # Validate backup file
    if ! validate_database_file "${backup_file}"; then
        log_error "Backup file validation failed: ${backup_file}"
        return 1
    fi
    
    # Create a backup of current file before restore
    local current_backup="${target_file}.pre_restore_$(get_timestamp)"
    if [[ -f "${target_file}" ]]; then
        cp "${target_file}" "${current_backup}" || log_warn "Failed to backup current file before restore"
    fi
    
    # Restore from backup
    if cp "${backup_file}" "${target_file}"; then
        log_success "Database restored from backup: ${target_file}"
        audit_log "DATABASE_RESTORE" "Database restored: ${backup_file} -> ${target_file}"
        return 0
    else
        log_error "Failed to restore database from backup"
        return 1
    fi
}

# Analyze database content
analyze_database() {
    local db_file="$1"
    local analysis_type="${2:-summary}"
    
    log_info "Analyzing database: ${db_file} (type: ${analysis_type})"
    
    if ! validate_database_file "${db_file}"; then
        log_error "Database validation failed for analysis: ${db_file}"
        return 1
    fi
    
    case "${analysis_type}" in
        "summary")
            generate_database_summary "${db_file}"
            ;;
        "augment")
            analyze_augment_entries "${db_file}"
            ;;
        "size")
            analyze_database_size "${db_file}"
            ;;
        "structure")
            analyze_database_structure "${db_file}"
            ;;
        *)
            log_error "Unknown analysis type: ${analysis_type}"
            return 1
            ;;
    esac
}

# Generate database summary
generate_database_summary() {
    local db_file="$1"
    
    log_info "Database Summary for: ${db_file}"
    
    # Get file size
    local file_size
    file_size=$(stat -f%z "${db_file}" 2>/dev/null || stat -c%s "${db_file}" 2>/dev/null)
    log_info "  File size: ${file_size} bytes"
    
    # Get table count
    local table_count
    table_count=$(sqlite3 "${db_file}" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" 2>/dev/null || echo "0")
    log_info "  Tables: ${table_count}"
    
    # Get total entries in ItemTable
    local total_entries
    total_entries=$(sqlite3 "${db_file}" "SELECT COUNT(*) FROM ItemTable;" 2>/dev/null || echo "0")
    log_info "  Total entries: ${total_entries}"
    
    # Get Augment entries count
    local augment_entries
    augment_entries=$(count_augment_entries "${db_file}")
    log_info "  Augment entries: ${augment_entries}"
}

# Analyze Augment entries
analyze_augment_entries() {
    local db_file="$1"
    
    log_info "Augment Entries Analysis for: ${db_file}"
    
    for pattern in "${AUGMENT_PATTERNS[@]}"; do
        local count
        count=$(sqlite3 "${db_file}" "SELECT COUNT(*) FROM ItemTable WHERE key LIKE '${pattern}';" 2>/dev/null || echo "0")
        
        if [[ ${count} -gt 0 ]]; then
            log_info "  Pattern '${pattern}': ${count} entries"
        fi
    done
}

# Analyze database size
analyze_database_size() {
    local db_file="$1"
    
    log_info "Database Size Analysis for: ${db_file}"
    
    # Get page count and page size
    local page_count
    page_count=$(sqlite3 "${db_file}" "PRAGMA page_count;" 2>/dev/null || echo "0")
    
    local page_size
    page_size=$(sqlite3 "${db_file}" "PRAGMA page_size;" 2>/dev/null || echo "0")
    
    local calculated_size=$((page_count * page_size))
    
    log_info "  Page count: ${page_count}"
    log_info "  Page size: ${page_size} bytes"
    log_info "  Calculated size: ${calculated_size} bytes"
    
    # Check for fragmentation
    local freelist_count
    freelist_count=$(sqlite3 "${db_file}" "PRAGMA freelist_count;" 2>/dev/null || echo "0")
    log_info "  Free pages: ${freelist_count}"
    
    if [[ ${freelist_count} -gt 0 ]]; then
        log_info "  Fragmentation detected: ${freelist_count} free pages"
        log_info "  Consider running VACUUM to reclaim space"
    fi
}

# Analyze database structure
analyze_database_structure() {
    local db_file="$1"
    
    log_info "Database Structure Analysis for: ${db_file}"
    
    # List all tables
    log_info "  Tables:"
    sqlite3 "${db_file}" "SELECT name FROM sqlite_master WHERE type='table';" 2>/dev/null | while read -r table; do
        log_info "    - ${table}"
    done
    
    # List all indexes
    log_info "  Indexes:"
    sqlite3 "${db_file}" "SELECT name FROM sqlite_master WHERE type='index';" 2>/dev/null | while read -r index; do
        log_info "    - ${index}"
    done
}

# Generate database operations report
generate_database_report() {
    local report_file="${1:-logs/database_report.txt}"
    
    log_info "Generating database operations report: ${report_file}"
    
    {
        echo "=== Database Operations Report ==="
        echo "Generated: $(date)"
        echo ""
        
        echo "Operation Statistics:"
        echo "  Databases processed: ${DB_STATS["databases_processed"]}"
        echo "  Entries removed: ${DB_STATS["entries_removed"]}"
        echo "  Backups created: ${DB_STATS["backups_created"]}"
        echo "  Errors encountered: ${DB_STATS["errors_encountered"]}"
        echo ""
        
        echo "Cleaning Patterns:"
        for pattern in "${AUGMENT_PATTERNS[@]}"; do
            echo "  - ${pattern}"
        done
        echo ""
        
        echo "Configuration:"
        echo "  Database timeout: ${DB_TIMEOUT} seconds"
        echo "  Maximum database size: ${MAX_DB_SIZE} bytes"
        echo "  Backup before clean: ${BACKUP_BEFORE_CLEAN}"
        
    } > "${report_file}"
    
    log_success "Database operations report generated: ${report_file}"
}

# Enhanced transaction management for migration operations

# Transaction state tracking
declare -A TRANSACTION_STATE=()

# Begin migration transaction with savepoints
begin_migration_transaction() {
    local db_file="$1"
    local transaction_id="${2:-migration_$(date +%s%3N)}"

    log_debug "Starting migration transaction: ${transaction_id}"

    # Validate database file
    if ! validate_database_file "${db_file}"; then
        log_error "Database validation failed, cannot start transaction"
        return 1
    fi

    # Begin transaction
    if sqlite3 "${db_file}" "BEGIN IMMEDIATE TRANSACTION;" 2>/dev/null; then
        TRANSACTION_STATE["${transaction_id}"]="active:${db_file}"
        audit_log "TRANSACTION_BEGIN" "Migration transaction started: ${transaction_id} on ${db_file}"
        log_debug "Migration transaction started successfully: ${transaction_id}"
        echo "${transaction_id}"
        return 0
    else
        log_error "Failed to start migration transaction: ${transaction_id}"
        return 1
    fi
}

# Create savepoint within transaction
create_transaction_savepoint() {
    local transaction_id="$1"
    local savepoint_name="${2:-sp_$(date +%s%3N)}"

    log_debug "Creating transaction savepoint: ${savepoint_name}"

    # Get database file from transaction state
    local db_info="${TRANSACTION_STATE["${transaction_id}"]}"
    if [[ -z "${db_info}" ]]; then
        log_error "Transaction does not exist: ${transaction_id}"
        return 1
    fi

    local db_file="${db_info#*:}"

    # Create savepoint
    if sqlite3 "${db_file}" "SAVEPOINT ${savepoint_name};" 2>/dev/null; then
        TRANSACTION_STATE["${transaction_id}:${savepoint_name}"]="savepoint:${db_file}"
        log_debug "Savepoint created successfully: ${savepoint_name}"
        echo "${savepoint_name}"
        return 0
    else
        log_error "Failed to create savepoint: ${savepoint_name}"
        return 1
    fi
}

# Rollback to savepoint
rollback_to_savepoint() {
    local transaction_id="$1"
    local savepoint_name="$2"

    log_info "Rolling back to savepoint: ${savepoint_name}"

    # Get database file from transaction state
    local savepoint_key="${transaction_id}:${savepoint_name}"
    local db_info="${TRANSACTION_STATE["${savepoint_key}"]}"
    if [[ -z "${db_info}" ]]; then
        log_error "Savepoint does not exist: ${savepoint_name}"
        return 1
    fi

    local db_file="${db_info#*:}"

    # Rollback to savepoint
    if sqlite3 "${db_file}" "ROLLBACK TO SAVEPOINT ${savepoint_name};" 2>/dev/null; then
        audit_log "TRANSACTION_ROLLBACK" "Rolled back to savepoint: ${savepoint_name} in ${transaction_id}"
        log_success "Successfully rolled back to savepoint: ${savepoint_name}"
        return 0
    else
        log_error "Failed to rollback to savepoint: ${savepoint_name}"
        return 1
    fi
}

# Commit migration transaction
commit_migration_transaction() {
    local transaction_id="$1"

    log_info "Committing migration transaction: ${transaction_id}"

    # Get database file from transaction state
    local db_info="${TRANSACTION_STATE["${transaction_id}"]}"
    if [[ -z "${db_info}" ]]; then
        log_error "Transaction does not exist: ${transaction_id}"
        return 1
    fi

    local db_file="${db_info#*:}"

    # Commit transaction
    if sqlite3 "${db_file}" "COMMIT;" 2>/dev/null; then
        # Clean up transaction state
        for key in "${!TRANSACTION_STATE[@]}"; do
            if [[ "${key}" == "${transaction_id}"* ]]; then
                unset TRANSACTION_STATE["${key}"]
            fi
        done

        audit_log "TRANSACTION_COMMIT" "Migration transaction committed: ${transaction_id} on ${db_file}"
        log_success "Migration transaction committed successfully: ${transaction_id}"
        return 0
    else
        log_error "Failed to commit migration transaction: ${transaction_id}"
        return 1
    fi
}

# Rollback migration transaction
rollback_migration_transaction() {
    local transaction_id="$1"

    log_info "Rolling back migration transaction: ${transaction_id}"

    # Get database file from transaction state
    local db_info="${TRANSACTION_STATE["${transaction_id}"]}"
    if [[ -z "${db_info}" ]]; then
        log_error "Transaction does not exist: ${transaction_id}"
        return 1
    fi

    local db_file="${db_info#*:}"

    # Rollback transaction
    if sqlite3 "${db_file}" "ROLLBACK;" 2>/dev/null; then
        # Clean up transaction state
        for key in "${!TRANSACTION_STATE[@]}"; do
            if [[ "${key}" == "${transaction_id}"* ]]; then
                unset TRANSACTION_STATE["${key}"]
            fi
        done

        audit_log "TRANSACTION_ROLLBACK" "Migration transaction rolled back: ${transaction_id} on ${db_file}"
        log_success "Migration transaction rolled back successfully: ${transaction_id}"
        return 0
    else
        log_error "Failed to rollback migration transaction: ${transaction_id}"
        return 1
    fi
}

# Execute SQL within transaction with error handling
execute_transaction_sql() {
    local transaction_id="$1"
    local sql_command="$2"
    local error_action="${3:-rollback}"  # rollback, continue, savepoint

    log_debug "Executing SQL in transaction: ${transaction_id}"

    # Get database file from transaction state
    local db_info="${TRANSACTION_STATE["${transaction_id}"]}"
    if [[ -z "${db_info}" ]]; then
        log_error "Transaction does not exist: ${transaction_id}"
        return 1
    fi

    local db_file="${db_info#*:}"

    # Execute SQL command
    local sql_result
    sql_result=$(sqlite3 "${db_file}" "${sql_command}" 2>&1)
    local sql_exit_code=$?

    if [[ ${sql_exit_code} -eq 0 ]]; then
        log_debug "SQL executed successfully"
        echo "${sql_result}"
        return 0
    else
        log_error "SQL execution failed: ${sql_result}"

        # Handle error based on action
        case "${error_action}" in
            "rollback")
                rollback_migration_transaction "${transaction_id}"
                ;;
            "savepoint")
                local savepoint_name="error_recovery_$(date +%s%3N)"
                create_transaction_savepoint "${transaction_id}" "${savepoint_name}"
                ;;
            "continue")
                log_warn "Ignoring SQL error, continuing execution"
                ;;
        esac

        return 1
    fi
}

# Check transaction status
check_transaction_status() {
    local transaction_id="$1"

    local db_info="${TRANSACTION_STATE["${transaction_id}"]}"
    if [[ -n "${db_info}" ]]; then
        local status="${db_info%%:*}"
        local db_file="${db_info#*:}"

        log_info "Transaction status: ${transaction_id} - ${status} on ${db_file}"
        echo "${status}"
        return 0
    else
        log_info "Transaction does not exist: ${transaction_id}"
        echo "not_found"
        return 1
    fi
}

# List active transactions
list_active_transactions() {
    log_info "Active transactions:"

    local transaction_count=0
    for key in "${!TRANSACTION_STATE[@]}"; do
        if [[ "${key}" != *":"* ]]; then  # Main transaction, not savepoint
            local db_info="${TRANSACTION_STATE["${key}"]}"
            local status="${db_info%%:*}"
            local db_file="${db_info#*:}"

            log_info "  ${key}: ${status} on ${db_file}"
            ((transaction_count++))
        fi
    done

    if [[ ${transaction_count} -eq 0 ]]; then
        log_info "  No active transactions"
    fi

    return 0
}

# Cleanup orphaned transactions
cleanup_orphaned_transactions() {
    log_info "Cleaning orphaned transactions"

    local cleaned_count=0
    for key in "${!TRANSACTION_STATE[@]}"; do
        if [[ "${key}" != *":"* ]]; then  # Main transaction
            local db_info="${TRANSACTION_STATE["${key}"]}"
            local db_file="${db_info#*:}"

            # Check if database file still exists and is accessible
            if [[ ! -f "${db_file}" ]] || ! validate_database_file "${db_file}"; then
                log_warn "Cleaning orphaned transaction: ${key}"

                # Remove transaction and its savepoints
                for cleanup_key in "${!TRANSACTION_STATE[@]}"; do
                    if [[ "${cleanup_key}" == "${key}"* ]]; then
                        unset TRANSACTION_STATE["${cleanup_key}"]
                    fi
                done

                ((cleaned_count++))
            fi
        fi
    done

    log_info "Cleaned ${cleaned_count} orphaned transactions"
    
    return 0
}

# Export enhanced database functions
export -f init_database clean_vscode_database validate_database_file
export -f count_augment_entries analyze_database generate_database_report
export -f create_database_backup restore_database_backup
export -f begin_migration_transaction create_transaction_savepoint rollback_to_savepoint
export -f commit_migration_transaction rollback_migration_transaction execute_transaction_sql
export -f check_transaction_status list_active_transactions cleanup_orphaned_transactions
export AUGMENT_PATTERNS DB_STATS TRANSACTION_STATE

log_debug "Database operations module loaded with enhanced transaction management"
