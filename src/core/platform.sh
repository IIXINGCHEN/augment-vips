#!/bin/bash
# platform.sh
#
# Auto-fixed for readonly variable conflicts

# Prevent multiple loading
if [[ "${PLATFORM_SH_LOADED:-}" == "true" ]]; then
    return 0
fi
if [[ -z "${PLATFORM_SH_LOADED:-}" ]]; then
    readonly PLATFORM_SH_LOADED="true"
fi

# core/platform.sh
#
# Enterprise-grade platform detection and adaptation module
# Zero-redundancy cross-platform compatibility layer
# Production-ready with comprehensive platform support

set -euo pipefail

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Platform constants
if [[ -z "${PLATFORM_WINDOWS:-}" ]]; then
    readonly PLATFORM_WINDOWS="windows"
fi
if [[ -z "${PLATFORM_LINUX:-}" ]]; then
    readonly PLATFORM_LINUX="linux"
fi
if [[ -z "${PLATFORM_MACOS:-}" ]]; then
    readonly PLATFORM_MACOS="macos"
fi
if [[ -z "${PLATFORM_UNKNOWN:-}" ]]; then
    readonly PLATFORM_UNKNOWN="unknown"
fi

# Global platform variables
DETECTED_PLATFORM=""
PLATFORM_VERSION=""
ARCHITECTURE=""
PACKAGE_MANAGER=""
SHELL_TYPE=""

# Platform detection
detect_platform() {
    log_info "Detecting platform..."
    
    # Detect operating system
    case "$(uname -s)" in
        Linux*)
            DETECTED_PLATFORM="${PLATFORM_LINUX}"
            detect_linux_distribution
            ;;
        Darwin*)
            DETECTED_PLATFORM="${PLATFORM_MACOS}"
            detect_macos_version
            ;;
        CYGWIN*|MINGW*|MSYS*)
            DETECTED_PLATFORM="${PLATFORM_WINDOWS}"
            detect_windows_version
            ;;
        *)
            DETECTED_PLATFORM="${PLATFORM_UNKNOWN}"
            log_error "Unsupported platform: $(uname -s)"
            return 1
            ;;
    esac
    
    # Detect architecture
    ARCHITECTURE="$(uname -m)"
    
    # Detect shell type
    detect_shell_type
    
    # Detect package manager
    detect_package_manager
    
    audit_log "PLATFORM_DETECT" "Platform: ${DETECTED_PLATFORM}, Version: ${PLATFORM_VERSION}, Arch: ${ARCHITECTURE}"
    log_success "Platform detected: ${DETECTED_PLATFORM} ${PLATFORM_VERSION} (${ARCHITECTURE})"
    
    return 0
}

# Linux distribution detection
detect_linux_distribution() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        PLATFORM_VERSION="${NAME} ${VERSION_ID}"
    elif [[ -f /etc/redhat-release ]]; then
        PLATFORM_VERSION="$(cat /etc/redhat-release)"
    elif [[ -f /etc/debian_version ]]; then
        PLATFORM_VERSION="Debian $(cat /etc/debian_version)"
    else
        PLATFORM_VERSION="Unknown Linux"
    fi
}

# macOS version detection
detect_macos_version() {
    PLATFORM_VERSION="$(sw_vers -productName) $(sw_vers -productVersion)"
}

# Windows version detection (for Git Bash/MSYS2/Cygwin)
detect_windows_version() {
    if is_command_available wmic; then
        PLATFORM_VERSION="$(wmic os get Caption /value | grep Caption | cut -d= -f2 | tr -d '\r')"
    else
        PLATFORM_VERSION="Windows (version unknown)"
    fi
}

# Shell type detection
detect_shell_type() {
    if [[ -n "${BASH_VERSION:-}" ]]; then
        SHELL_TYPE="bash"
    elif [[ -n "${ZSH_VERSION:-}" ]]; then
        SHELL_TYPE="zsh"
    elif [[ -n "${FISH_VERSION:-}" ]]; then
        SHELL_TYPE="fish"
    else
        SHELL_TYPE="unknown"
    fi
    
    log_debug "Shell type detected: ${SHELL_TYPE}"
}

# Package manager detection
detect_package_manager() {
    case "${DETECTED_PLATFORM}" in
        "${PLATFORM_LINUX}")
            if is_command_available apt; then
                PACKAGE_MANAGER="apt"
            elif is_command_available dnf; then
                PACKAGE_MANAGER="dnf"
            elif is_command_available yum; then
                PACKAGE_MANAGER="yum"
            elif is_command_available pacman; then
                PACKAGE_MANAGER="pacman"
            elif is_command_available zypper; then
                PACKAGE_MANAGER="zypper"
            else
                PACKAGE_MANAGER="unknown"
            fi
            ;;
        "${PLATFORM_MACOS}")
            if is_command_available brew; then
                PACKAGE_MANAGER="brew"
            elif is_command_available port; then
                PACKAGE_MANAGER="port"
            else
                PACKAGE_MANAGER="unknown"
            fi
            ;;
        "${PLATFORM_WINDOWS}")
            if is_command_available choco; then
                PACKAGE_MANAGER="choco"
            elif is_command_available winget; then
                PACKAGE_MANAGER="winget"
            else
                PACKAGE_MANAGER="unknown"
            fi
            ;;
        *)
            PACKAGE_MANAGER="unknown"
            ;;
    esac
    
    log_debug "Package manager detected: ${PACKAGE_MANAGER}"
}

# Platform-specific path functions
get_vscode_config_path() {
    case "${DETECTED_PLATFORM}" in
        "${PLATFORM_WINDOWS}")
            echo "${APPDATA}/Code"
            ;;
        "${PLATFORM_LINUX}")
            echo "${HOME}/.config/Code"
            ;;
        "${PLATFORM_MACOS}")
            echo "${HOME}/Library/Application Support/Code"
            ;;
        *)
            log_error "Unsupported platform for VS Code path: ${DETECTED_PLATFORM}"
            return 1
            ;;
    esac
}

get_vscode_data_path() {
    case "${DETECTED_PLATFORM}" in
        "${PLATFORM_WINDOWS}")
            echo "${LOCALAPPDATA}/Code"
            ;;
        "${PLATFORM_LINUX}")
            echo "${HOME}/.vscode"
            ;;
        "${PLATFORM_MACOS}")
            echo "${HOME}/.vscode"
            ;;
        *)
            log_error "Unsupported platform for VS Code data path: ${DETECTED_PLATFORM}"
            return 1
            ;;
    esac
}

# Platform-specific command execution
execute_platform_command() {
    local command_type="$1"
    shift
    local args=("$@")
    
    case "${DETECTED_PLATFORM}" in
        "${PLATFORM_WINDOWS}")
            execute_windows_command "${command_type}" "${args[@]}"
            ;;
        "${PLATFORM_LINUX}")
            execute_linux_command "${command_type}" "${args[@]}"
            ;;
        "${PLATFORM_MACOS}")
            execute_macos_command "${command_type}" "${args[@]}"
            ;;
        *)
            log_error "Unsupported platform for command execution: ${DETECTED_PLATFORM}"
            return 1
            ;;
    esac
}

execute_windows_command() {
    local command_type="$1"
    shift
    local args=("$@")
    
    case "${command_type}" in
        "install_deps")
            if [[ "${PACKAGE_MANAGER}" == "choco" ]]; then
                choco install "${args[@]}" -y
            else
                log_error "No supported package manager found for Windows"
                return 1
            fi
            ;;
        *)
            log_error "Unknown Windows command type: ${command_type}"
            return 1
            ;;
    esac
}

execute_linux_command() {
    local command_type="$1"
    shift
    local args=("$@")
    
    case "${command_type}" in
        "install_deps")
            case "${PACKAGE_MANAGER}" in
                "apt")
                    sudo apt update && sudo apt install -y "${args[@]}"
                    ;;
                "dnf")
                    sudo dnf install -y "${args[@]}"
                    ;;
                "yum")
                    sudo yum install -y "${args[@]}"
                    ;;
                *)
                    log_error "Unsupported package manager for Linux: ${PACKAGE_MANAGER}"
                    return 1
                    ;;
            esac
            ;;
        *)
            log_error "Unknown Linux command type: ${command_type}"
            return 1
            ;;
    esac
}

execute_macos_command() {
    local command_type="$1"
    shift
    local args=("$@")
    
    case "${command_type}" in
        "install_deps")
            if [[ "${PACKAGE_MANAGER}" == "brew" ]]; then
                brew install "${args[@]}"
            else
                log_error "Homebrew not found. Please install Homebrew first."
                return 1
            fi
            ;;
        *)
            log_error "Unknown macOS command type: ${command_type}"
            return 1
            ;;
    esac
}

# Platform capability checks
check_platform_capabilities() {
    log_info "Checking platform capabilities..."
    
    local capabilities=()
    
    # Check for required commands
    local required_commands=("sqlite3" "curl" "jq")
    for cmd in "${required_commands[@]}"; do
        if is_command_available "${cmd}"; then
            capabilities+=("${cmd}:available")
        else
            capabilities+=("${cmd}:missing")
        fi
    done
    
    # Check for package manager
    if [[ "${PACKAGE_MANAGER}" != "unknown" ]]; then
        capabilities+=("package_manager:${PACKAGE_MANAGER}")
    else
        capabilities+=("package_manager:none")
    fi
    
    # Check for admin/root privileges
    if is_root || [[ "${DETECTED_PLATFORM}" == "${PLATFORM_WINDOWS}" ]]; then
        capabilities+=("admin:available")
    else
        capabilities+=("admin:check_required")
    fi
    
    # Log capabilities
    for capability in "${capabilities[@]}"; do
        log_debug "Capability: ${capability}"
    done
    
    audit_log "CAPABILITY_CHECK" "Platform capabilities checked: ${capabilities[*]}"
    
    return 0
}

# Initialize platform detection
init_platform() {
    log_info "Initializing platform detection..."
    
    if ! detect_platform; then
        log_error "Platform detection failed"
        return 1
    fi
    
    if ! check_platform_capabilities; then
        log_error "Platform capability check failed"
        return 1
    fi
    
    log_success "Platform initialization completed"
    return 0
}

# Export platform variables and functions
export DETECTED_PLATFORM PLATFORM_VERSION ARCHITECTURE PACKAGE_MANAGER SHELL_TYPE
export -f detect_platform get_vscode_config_path get_vscode_data_path
export -f execute_platform_command check_platform_capabilities init_platform

log_debug "Platform module loaded"
