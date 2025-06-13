#!/bin/bash
# paths.sh
#
# Auto-fixed for readonly variable conflicts

# Prevent multiple loading
if [[ "${PATHS_SH_LOADED:-}" == "true" ]]; then
    return 0
fi
if [[ -z "${PATHS_SH_LOADED:-}" ]]; then
    readonly PATHS_SH_LOADED="true"
fi

# core/paths.sh
#
# Enterprise-grade cross-platform path resolution module
# Production-ready with comprehensive path validation and security
# Zero-redundancy path handling for all supported platforms

set -euo pipefail

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/platform.sh"
source "$(dirname "${BASH_SOURCE[0]}")/security.sh"
source "$(dirname "${BASH_SOURCE[0]}")/validation.sh"

# Path constants
if [[ -z "${VSCODE_APP_NAME:-}" ]]; then
    readonly VSCODE_APP_NAME="Code"
fi
if [[ -z "${VSCODE_INSIDERS_APP_NAME:-}" ]]; then
    readonly VSCODE_INSIDERS_APP_NAME="Code - Insiders"
fi
if [[ -z "${VSCODE_PORTABLE_DATA_DIR:-}" ]]; then
    readonly VSCODE_PORTABLE_DATA_DIR="data"
fi

# VS Code file patterns
if [[ -z "${VSCODE_DB_PATTERN:-}" ]]; then
    readonly VSCODE_DB_PATTERN="*.vscdb"
fi
if [[ -z "${VSCODE_STORAGE_FILE:-}" ]]; then
    readonly VSCODE_STORAGE_FILE="storage.json"
fi
if [[ -z "${VSCODE_BACKUP_SUFFIX:-}" ]]; then
    readonly VSCODE_BACKUP_SUFFIX=".backup"
fi

# Global path variables
declare -A VSCODE_PATHS=()
declare -A DISCOVERED_FILES=()

# Initialize path resolution
init_paths() {
    log_info "Initializing cross-platform path resolution..."
    
    # Ensure platform is detected
    if [[ -z "${DETECTED_PLATFORM:-}" ]]; then
        if ! init_platform; then
            log_error "Platform detection required for path resolution"
            return 1
        fi
    fi
    
    # Discover VS Code installations
    discover_vscode_installations
    
    # Discover VS Code data files
    discover_vscode_files
    
    audit_log "PATHS_INIT" "Path resolution initialized for platform: ${DETECTED_PLATFORM}"
    log_success "Path resolution initialized"
}

# Discover VS Code installations
discover_vscode_installations() {
    log_info "Discovering VS Code installations..."
    
    case "${DETECTED_PLATFORM}" in
        "windows")
            discover_windows_vscode_paths
            ;;
        "linux")
            discover_linux_vscode_paths
            ;;
        "macos")
            discover_macos_vscode_paths
            ;;
        *)
            log_error "Unsupported platform for VS Code discovery: ${DETECTED_PLATFORM}"
            return 1
            ;;
    esac
    
    # Log discovered paths
    for path_type in "${!VSCODE_PATHS[@]}"; do
        log_debug "VS Code path discovered: ${path_type} -> ${VSCODE_PATHS["${path_type}"]}"
    done
    
    audit_log "VSCODE_DISCOVERY" "VS Code installations discovered: ${#VSCODE_PATHS[@]} paths"
}

# Windows VS Code path discovery
discover_windows_vscode_paths() {
    log_debug "Discovering Windows VS Code paths..."
    
    # Standard installation paths
    local appdata="${APPDATA:-}"
    local localappdata="${LOCALAPPDATA:-}"
    local programfiles="${PROGRAMFILES:-}"
    local programfiles_x86="${PROGRAMFILES(X86):-}"
    
    # User data directories
    if [[ -n "${appdata}" ]]; then
        local user_data_dir="${appdata}/${VSCODE_APP_NAME}"
        if [[ -d "${user_data_dir}" ]]; then
            VSCODE_PATHS["user_data"]="${user_data_dir}"
        fi
        
        local insiders_data_dir="${appdata}/${VSCODE_INSIDERS_APP_NAME}"
        if [[ -d "${insiders_data_dir}" ]]; then
            VSCODE_PATHS["insiders_user_data"]="${insiders_data_dir}"
        fi
    fi
    
    # Local data directories
    if [[ -n "${localappdata}" ]]; then
        local local_data_dir="${localappdata}/${VSCODE_APP_NAME}"
        if [[ -d "${local_data_dir}" ]]; then
            VSCODE_PATHS["local_data"]="${local_data_dir}"
        fi
        
        local insiders_local_dir="${localappdata}/${VSCODE_INSIDERS_APP_NAME}"
        if [[ -d "${insiders_local_dir}" ]]; then
            VSCODE_PATHS["insiders_local_data"]="${insiders_local_dir}"
        fi
    fi
    
    # Installation directories
    local install_paths=(
        "${programfiles}/Microsoft VS Code"
        "${programfiles_x86}/Microsoft VS Code"
        "${localappdata}/Programs/Microsoft VS Code"
    )
    
    for install_path in "${install_paths[@]}"; do
        if [[ -d "${install_path}" ]]; then
            VSCODE_PATHS["installation"]="${install_path}"
            break
        fi
    done
    
    # Portable installation check
    discover_portable_vscode "."
}

# Linux VS Code path discovery
discover_linux_vscode_paths() {
    log_debug "Discovering Linux VS Code paths..."
    
    local home="${HOME:-}"
    
    if [[ -z "${home}" ]]; then
        log_error "HOME environment variable not set"
        return 1
    fi
    
    # User configuration directory
    local config_dir="${home}/.config/${VSCODE_APP_NAME}"
    if [[ -d "${config_dir}" ]]; then
        VSCODE_PATHS["user_config"]="${config_dir}"
    fi
    
    # Insiders configuration directory
    local insiders_config_dir="${home}/.config/${VSCODE_INSIDERS_APP_NAME}"
    if [[ -d "${insiders_config_dir}" ]]; then
        VSCODE_PATHS["insiders_config"]="${insiders_config_dir}"
    fi
    
    # User data directory
    local data_dir="${home}/.vscode"
    if [[ -d "${data_dir}" ]]; then
        VSCODE_PATHS["user_data"]="${data_dir}"
    fi
    
    # Insiders data directory
    local insiders_data_dir="${home}/.vscode-insiders"
    if [[ -d "${insiders_data_dir}" ]]; then
        VSCODE_PATHS["insiders_data"]="${insiders_data_dir}"
    fi
    
    # System installation paths
    local system_paths=(
        "/usr/share/code"
        "/opt/visual-studio-code"
        "/snap/code/current"
        "/var/lib/flatpak/app/com.visualstudio.code"
    )
    
    for system_path in "${system_paths[@]}"; do
        if [[ -d "${system_path}" ]]; then
            VSCODE_PATHS["system_installation"]="${system_path}"
            break
        fi
    done
    
    # Portable installation check
    discover_portable_vscode "${home}"
}

# macOS VS Code path discovery
discover_macos_vscode_paths() {
    log_debug "Discovering macOS VS Code paths..."
    
    local home="${HOME:-}"
    
    if [[ -z "${home}" ]]; then
        log_error "HOME environment variable not set"
        return 1
    fi
    
    # User Library directory
    local library_dir="${home}/Library"
    
    # Application Support directory
    local app_support_dir="${library_dir}/Application Support/${VSCODE_APP_NAME}"
    if [[ -d "${app_support_dir}" ]]; then
        VSCODE_PATHS["user_data"]="${app_support_dir}"
    fi
    
    # Insiders Application Support directory
    local insiders_app_support_dir="${library_dir}/Application Support/${VSCODE_INSIDERS_APP_NAME}"
    if [[ -d "${insiders_app_support_dir}" ]]; then
        VSCODE_PATHS["insiders_user_data"]="${insiders_app_support_dir}"
    fi
    
    # User data directory
    local vscode_dir="${home}/.vscode"
    if [[ -d "${vscode_dir}" ]]; then
        VSCODE_PATHS["user_config"]="${vscode_dir}"
    fi
    
    # Insiders user data directory
    local insiders_vscode_dir="${home}/.vscode-insiders"
    if [[ -d "${insiders_vscode_dir}" ]]; then
        VSCODE_PATHS["insiders_config"]="${insiders_vscode_dir}"
    fi
    
    # Application installation paths
    local app_paths=(
        "/Applications/Visual Studio Code.app"
        "${home}/Applications/Visual Studio Code.app"
        "/Applications/Visual Studio Code - Insiders.app"
        "${home}/Applications/Visual Studio Code - Insiders.app"
    )
    
    for app_path in "${app_paths[@]}"; do
        if [[ -d "${app_path}" ]]; then
            VSCODE_PATHS["application"]="${app_path}"
            break
        fi
    done
    
    # Portable installation check
    discover_portable_vscode "${home}"
}

# Discover portable VS Code installations
discover_portable_vscode() {
    local search_dir="$1"
    
    log_debug "Checking for portable VS Code in: ${search_dir}"
    
    # Common portable directory names
    local portable_dirs=(
        "VSCode-Portable"
        "vscode-portable"
        "code-portable"
        "VSCode"
        "vscode"
    )
    
    for portable_dir in "${portable_dirs[@]}"; do
        local portable_path="${search_dir}/${portable_dir}"
        
        if [[ -d "${portable_path}" ]]; then
            # Check for portable data directory
            local portable_data_dir="${portable_path}/${VSCODE_PORTABLE_DATA_DIR}"
            
            if [[ -d "${portable_data_dir}" ]]; then
                VSCODE_PATHS["portable"]="${portable_path}"
                VSCODE_PATHS["portable_data"]="${portable_data_dir}"
                log_debug "Portable VS Code found: ${portable_path}"
                break
            fi
        fi
    done
}

# Discover VS Code data files
discover_vscode_files() {
    log_info "Discovering VS Code data files..."
    
    # Clear previous discoveries
    DISCOVERED_FILES=()
    
    # Search for database files
    discover_database_files
    
    # Search for storage files
    discover_storage_files
    
    # Log discovery results
    log_info "Discovered ${#DISCOVERED_FILES[@]} VS Code data files"
    
    for file_type in "${!DISCOVERED_FILES[@]}"; do
        log_debug "Discovered file: ${file_type} -> ${DISCOVERED_FILES["${file_type}"]}"
    done
    
    audit_log "FILE_DISCOVERY" "VS Code data files discovered: ${#DISCOVERED_FILES[@]} files"
}

# Discover database files
discover_database_files() {
    log_debug "Discovering VS Code database files..."
    
    local db_search_paths=(
        "User/workspaceStorage"
        "User/globalStorage"
        "Cache"
        "CachedData"
        "logs"
    )
    
    for path_type in "${!VSCODE_PATHS[@]}"; do
        local base_path="${VSCODE_PATHS["${path_type}"]}"
        
        for search_path in "${db_search_paths[@]}"; do
            local full_search_path="${base_path}/${search_path}"
            
            if [[ -d "${full_search_path}" ]]; then
                # Find database files
                while IFS= read -r -d '' db_file; do
                    if validate_path "${db_file}" "read"; then
                        local file_key="${path_type}_db_$(basename "${db_file}")"
                        DISCOVERED_FILES["${file_key}"]="${db_file}"
                    fi
                done < <(find "${full_search_path}" -name "${VSCODE_DB_PATTERN}" -type f -print0 2>/dev/null || true)
            fi
        done
    done
}

# Discover storage files
discover_storage_files() {
    log_debug "Discovering VS Code storage files..."
    
    local storage_search_paths=(
        "User"
        "User/globalStorage"
        "User/workspaceStorage"
    )
    
    for path_type in "${!VSCODE_PATHS[@]}"; do
        local base_path="${VSCODE_PATHS["${path_type}"]}"
        
        for search_path in "${storage_search_paths[@]}"; do
            local storage_file="${base_path}/${search_path}/${VSCODE_STORAGE_FILE}"
            
            if [[ -f "${storage_file}" ]] && validate_path "${storage_file}" "read"; then
                local file_key="${path_type}_storage"
                DISCOVERED_FILES["${file_key}"]="${storage_file}"
            fi
        done
        
        # Also check for storage files in subdirectories
        local storage_dir="${base_path}/User/workspaceStorage"
        if [[ -d "${storage_dir}" ]]; then
            while IFS= read -r -d '' storage_file; do
                if validate_path "${storage_file}" "read"; then
                    local file_key="${path_type}_workspace_storage_$(basename "$(dirname "${storage_file}")")"
                    DISCOVERED_FILES["${file_key}"]="${storage_file}"
                fi
            done < <(find "${storage_dir}" -name "${VSCODE_STORAGE_FILE}" -type f -print0 2>/dev/null || true)
        fi
    done
}

# Get specific file paths
get_database_files() {
    local files=()
    
    for file_key in "${!DISCOVERED_FILES[@]}"; do
        if [[ "${file_key}" == *"_db_"* ]]; then
            files+=("${DISCOVERED_FILES["${file_key}"]}")
        fi
    done
    
    printf '%s\n' "${files[@]}"
}

get_storage_files() {
    local files=()
    
    for file_key in "${!DISCOVERED_FILES[@]}"; do
        if [[ "${file_key}" == *"_storage"* ]]; then
            files+=("${DISCOVERED_FILES["${file_key}"]}")
        fi
    done
    
    printf '%s\n' "${files[@]}"
}

# Validate file access
validate_file_access() {
    local file_path="$1"
    local operation="${2:-read}"
    
    # Validate path security
    if ! validate_path "${file_path}" "${operation}"; then
        return 1
    fi
    
    # Check file existence for read operations
    if [[ "${operation}" == "read" && ! -f "${file_path}" ]]; then
        log_error "File does not exist: ${file_path}"
        return 1
    fi
    
    # Check file permissions
    case "${operation}" in
        "read")
            if [[ ! -r "${file_path}" ]]; then
                log_error "File not readable: ${file_path}"
                return 1
            fi
            ;;
        "write"|"modify")
            if [[ -f "${file_path}" && ! -w "${file_path}" ]]; then
                log_error "File not writable: ${file_path}"
                return 1
            fi
            
            # Check parent directory permissions
            local parent_dir
            parent_dir=$(dirname "${file_path}")
            if [[ ! -w "${parent_dir}" ]]; then
                log_error "Parent directory not writable: ${parent_dir}"
                return 1
            fi
            ;;
    esac
    
    return 0
}

# Create backup path
create_backup_path() {
    local original_path="$1"
    local timestamp="${2:-$(get_timestamp)}"
    
    echo "${original_path}${VSCODE_BACKUP_SUFFIX}_${timestamp}"
}

# Generate path report
generate_path_report() {
    local report_file="${1:-logs/path_report.txt}"
    
    log_info "Generating path discovery report: ${report_file}"
    
    {
        echo "=== VS Code Path Discovery Report ==="
        echo "Generated: $(date)"
        echo "Platform: ${DETECTED_PLATFORM} ${PLATFORM_VERSION}"
        echo ""
        
        echo "Discovered VS Code Installations:"
        for path_type in "${!VSCODE_PATHS[@]}"; do
            echo "  ${path_type}: ${VSCODE_PATHS["${path_type}"]}"
        done
        echo ""
        
        echo "Discovered Data Files:"
        for file_key in "${!DISCOVERED_FILES[@]}"; do
            echo "  ${file_key}: ${DISCOVERED_FILES["${file_key}"]}"
        done
        echo ""
        
        echo "Summary:"
        echo "  VS Code installations: ${#VSCODE_PATHS[@]}"
        echo "  Data files found: ${#DISCOVERED_FILES[@]}"
        
        # Count by type
        local db_count=0
        local storage_count=0
        
        for file_key in "${!DISCOVERED_FILES[@]}"; do
            if [[ "${file_key}" == *"_db_"* ]]; then
                ((db_count++))
            elif [[ "${file_key}" == *"_storage"* ]]; then
                ((storage_count++))
            fi
        done
        
        echo "  Database files: ${db_count}"
        echo "  Storage files: ${storage_count}"
        
    } > "${report_file}"
    
    log_success "Path discovery report generated: ${report_file}"
}

# Export path functions and variables
export -f init_paths discover_vscode_installations discover_vscode_files
export -f get_database_files get_storage_files validate_file_access
export -f create_backup_path generate_path_report
export VSCODE_PATHS DISCOVERED_FILES

log_debug "Cross-platform path resolution module loaded"
