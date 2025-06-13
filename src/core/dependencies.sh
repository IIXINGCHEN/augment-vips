#!/bin/bash
# dependencies.sh
#
# Auto-fixed for readonly variable conflicts

# Prevent multiple loading
if [[ "${DEPENDENCIES_SH_LOADED:-}" == "true" ]]; then
    return 0
fi
if [[ -z "${DEPENDENCIES_SH_LOADED:-}" ]]; then
    readonly DEPENDENCIES_SH_LOADED="true"
fi

# core/dependencies.sh
#
# Enterprise-grade dependency management and verification module
# Production-ready with comprehensive dependency validation
# Cross-platform package management with security verification

set -euo pipefail

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/platform.sh"
source "$(dirname "${BASH_SOURCE[0]}")/security.sh"

# Dependency constants
if [[ -z "${REQUIRED_DEPENDENCIES:-}" ]]; then
    readonly REQUIRED_DEPENDENCIES=("sqlite3" "curl" "jq")
fi
if [[ -z "${OPTIONAL_DEPENDENCIES:-}" ]]; then
    readonly OPTIONAL_DEPENDENCIES=("git" "wget" "openssl")
fi

# Dependency information structure
declare -A DEPENDENCY_INFO=(
    ["sqlite3"]="SQLite database engine for VS Code database operations"
    ["curl"]="HTTP client for downloading files and remote operations"
    ["jq"]="JSON processor for configuration and data manipulation"
    ["git"]="Version control system for repository operations"
    ["wget"]="Alternative HTTP client for file downloads"
    ["openssl"]="Cryptographic library for security operations"
)

# Package manager mappings
declare -A PACKAGE_MAPPINGS=(
    # Windows (Chocolatey)
    ["windows:sqlite3"]="sqlite"
    ["windows:curl"]="curl"
    ["windows:jq"]="jq"
    ["windows:git"]="git"
    ["windows:wget"]="wget"
    ["windows:openssl"]="openssl"
    
    # Linux (APT)
    ["linux:apt:sqlite3"]="sqlite3"
    ["linux:apt:curl"]="curl"
    ["linux:apt:jq"]="jq"
    ["linux:apt:git"]="git"
    ["linux:apt:wget"]="wget"
    ["linux:apt:openssl"]="openssl"
    
    # Linux (DNF/YUM)
    ["linux:dnf:sqlite3"]="sqlite"
    ["linux:dnf:curl"]="curl"
    ["linux:dnf:jq"]="jq"
    ["linux:dnf:git"]="git"
    ["linux:dnf:wget"]="wget"
    ["linux:dnf:openssl"]="openssl"
    
    # macOS (Homebrew)
    ["macos:brew:sqlite3"]="sqlite3"
    ["macos:brew:curl"]="curl"
    ["macos:brew:jq"]="jq"
    ["macos:brew:git"]="git"
    ["macos:brew:wget"]="wget"
    ["macos:brew:openssl"]="openssl"
)

# Global dependency status
declare -A DEPENDENCY_STATUS=()
declare -A DEPENDENCY_VERSIONS=()
DEPENDENCIES_SATISFIED=false

# Initialize dependency management
init_dependencies() {
    log_info "Initializing dependency management..."
    
    # Ensure platform is detected
    if [[ -z "${DETECTED_PLATFORM:-}" ]]; then
        if ! init_platform; then
            log_error "Platform detection required for dependency management"
            return 1
        fi
    fi
    
    # Check all dependencies
    check_all_dependencies
    
    audit_log "DEPENDENCIES_INIT" "Dependency management initialized"
    log_success "Dependency management initialized"
}

# Check all dependencies
check_all_dependencies() {
    log_info "Checking all dependencies..."
    
    local all_satisfied=true
    
    # Check required dependencies
    for dep in "${REQUIRED_DEPENDENCIES[@]}"; do
        if check_dependency "${dep}"; then
            DEPENDENCY_STATUS["${dep}"]="available"
            log_success "Required dependency available: ${dep} (${DEPENDENCY_VERSIONS["${dep}"]})"
        else
            DEPENDENCY_STATUS["${dep}"]="missing"
            log_error "Required dependency missing: ${dep}"
            all_satisfied=false
        fi
    done
    
    # Check optional dependencies
    for dep in "${OPTIONAL_DEPENDENCIES[@]}"; do
        if check_dependency "${dep}"; then
            DEPENDENCY_STATUS["${dep}"]="available"
            log_info "Optional dependency available: ${dep} (${DEPENDENCY_VERSIONS["${dep}"]})"
        else
            DEPENDENCY_STATUS["${dep}"]="missing"
            log_warn "Optional dependency missing: ${dep}"
        fi
    done
    
    DEPENDENCIES_SATISFIED="${all_satisfied}"
    
    if [[ "${all_satisfied}" == "true" ]]; then
        log_success "All required dependencies are satisfied"
    else
        log_error "Some required dependencies are missing"
    fi
    
    audit_log "DEPENDENCIES_CHECK" "Dependencies checked: satisfied=${all_satisfied}"
    return 0
}

# Check individual dependency
check_dependency() {
    local dep="$1"
    
    log_debug "Checking dependency: ${dep}"
    
    # Check if command is available
    if ! is_command_available "${dep}"; then
        log_debug "Dependency not found in PATH: ${dep}"
        return 1
    fi
    
    # Get version information
    local version
    version=$(get_dependency_version "${dep}")
    DEPENDENCY_VERSIONS["${dep}"]="${version}"
    
    # Verify dependency integrity
    if ! verify_dependency_integrity "${dep}"; then
        log_warn "Dependency integrity check failed: ${dep}"
        return 1
    fi
    
    log_debug "Dependency check passed: ${dep} (${version})"
    return 0
}

# Get dependency version
get_dependency_version() {
    local dep="$1"
    local version="unknown"
    
    case "${dep}" in
        "sqlite3")
            version=$(sqlite3 -version 2>/dev/null | cut -d' ' -f1 || echo "unknown")
            ;;
        "curl")
            version=$(curl --version 2>/dev/null | head -n1 | cut -d' ' -f2 || echo "unknown")
            ;;
        "jq")
            version=$(jq --version 2>/dev/null | cut -d'-' -f2 || echo "unknown")
            ;;
        "git")
            version=$(git --version 2>/dev/null | cut -d' ' -f3 || echo "unknown")
            ;;
        "wget")
            version=$(wget --version 2>/dev/null | head -n1 | cut -d' ' -f3 || echo "unknown")
            ;;
        "openssl")
            version=$(openssl version 2>/dev/null | cut -d' ' -f2 || echo "unknown")
            ;;
        *)
            version="unknown"
            ;;
    esac
    
    echo "${version}"
}

# Verify dependency integrity
verify_dependency_integrity() {
    local dep="$1"
    
    # Basic integrity checks
    case "${dep}" in
        "sqlite3")
            # Test SQLite functionality
            if ! echo "SELECT 1;" | sqlite3 ":memory:" >/dev/null 2>&1; then
                log_error "SQLite3 functionality test failed"
                return 1
            fi
            ;;
        "curl")
            # Test curl basic functionality
            if ! curl --help >/dev/null 2>&1; then
                log_error "curl functionality test failed"
                return 1
            fi
            ;;
        "jq")
            # Test jq basic functionality
            if ! echo '{"test": true}' | jq '.test' >/dev/null 2>&1; then
                log_error "jq functionality test failed"
                return 1
            fi
            ;;
        *)
            # Generic test - just check if command runs
            if ! "${dep}" --help >/dev/null 2>&1 && ! "${dep}" -h >/dev/null 2>&1; then
                log_debug "Basic help test failed for: ${dep}"
                # Don't fail for this, as some commands might not support --help
            fi
            ;;
    esac
    
    return 0
}

# Install missing dependencies
install_missing_dependencies() {
    local auto_install="${1:-false}"
    
    log_info "Installing missing dependencies..."
    
    # Check if we have permission to install
    if ! check_install_permissions; then
        log_error "Insufficient permissions to install dependencies"
        return 1
    fi
    
    local missing_deps=()
    
    # Collect missing required dependencies
    for dep in "${REQUIRED_DEPENDENCIES[@]}"; do
        if [[ "${DEPENDENCY_STATUS["${dep}"]:-missing}" == "missing" ]]; then
            missing_deps+=("${dep}")
        fi
    done
    
    if [[ ${#missing_deps[@]} -eq 0 ]]; then
        log_info "No missing dependencies to install"
        return 0
    fi
    
    # Confirm installation if not auto
    if [[ "${auto_install}" != "true" ]]; then
        log_info "Missing dependencies: ${missing_deps[*]}"
        read -p "Install missing dependencies? (y/N): " confirm
        if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
            log_info "Dependency installation cancelled"
            return 1
        fi
    fi
    
    # Install dependencies using platform-specific method
    for dep in "${missing_deps[@]}"; do
        if install_dependency "${dep}"; then
            log_success "Successfully installed: ${dep}"
            DEPENDENCY_STATUS["${dep}"]="available"
        else
            log_error "Failed to install: ${dep}"
            return 1
        fi
    done
    
    # Re-check dependencies after installation
    check_all_dependencies
    
    audit_log "DEPENDENCIES_INSTALL" "Dependencies installed: ${missing_deps[*]}"
    log_success "Dependency installation completed"
}

# Install individual dependency
install_dependency() {
    local dep="$1"
    
    log_info "Installing dependency: ${dep}"
    
    # Get package name for current platform and package manager
    local package_key="${DETECTED_PLATFORM}:${PACKAGE_MANAGER}:${dep}"
    local alt_package_key="${DETECTED_PLATFORM}:${dep}"
    local package_name=""
    
    if [[ -n "${PACKAGE_MAPPINGS["${package_key}"]:-}" ]]; then
        package_name="${PACKAGE_MAPPINGS["${package_key}"]}"
    elif [[ -n "${PACKAGE_MAPPINGS["${alt_package_key}"]:-}" ]]; then
        package_name="${PACKAGE_MAPPINGS["${alt_package_key}"]}"
    else
        package_name="${dep}"  # Fallback to dependency name
    fi
    
    log_debug "Installing package: ${package_name} (for ${dep})"
    
    # Install using platform-specific command
    if execute_platform_command "install_deps" "${package_name}"; then
        # Verify installation
        if check_dependency "${dep}"; then
            audit_log "DEPENDENCY_INSTALLED" "Successfully installed: ${dep} (package: ${package_name})"
            return 0
        else
            log_error "Installation verification failed for: ${dep}"
            return 1
        fi
    else
        log_error "Package installation failed for: ${dep}"
        return 1
    fi
}

# Check installation permissions
check_install_permissions() {
    case "${DETECTED_PLATFORM}" in
        "windows")
            # Check if running as administrator or if chocolatey is available
            if [[ "${PACKAGE_MANAGER}" == "choco" ]]; then
                return 0
            else
                log_error "Chocolatey package manager not available"
                return 1
            fi
            ;;
        "linux"|"macos")
            # Check if we can use sudo or if package manager is available
            if [[ "${PACKAGE_MANAGER}" != "unknown" ]]; then
                # Test sudo access for package managers that require it
                case "${PACKAGE_MANAGER}" in
                    "apt"|"dnf"|"yum")
                        if ! sudo -n true 2>/dev/null; then
                            log_error "sudo access required for package installation"
                            return 1
                        fi
                        ;;
                    "brew")
                        # Homebrew doesn't require sudo
                        return 0
                        ;;
                esac
                return 0
            else
                log_error "No supported package manager found"
                return 1
            fi
            ;;
        *)
            log_error "Unsupported platform for dependency installation"
            return 1
            ;;
    esac
}

# Generate dependency report
generate_dependency_report() {
    local report_file="${1:-logs/dependency_report.txt}"
    
    log_info "Generating dependency report: ${report_file}"
    
    {
        echo "=== Dependency Report ==="
        echo "Generated: $(date)"
        echo "Platform: ${DETECTED_PLATFORM} ${PLATFORM_VERSION}"
        echo "Package Manager: ${PACKAGE_MANAGER}"
        echo "Architecture: ${ARCHITECTURE}"
        echo ""
        
        echo "Required Dependencies:"
        for dep in "${REQUIRED_DEPENDENCIES[@]}"; do
            local status="${DEPENDENCY_STATUS["${dep}"]:-unknown}"
            local version="${DEPENDENCY_VERSIONS["${dep}"]:-unknown}"
            echo "  ${dep}: ${status} (${version}) - ${DEPENDENCY_INFO["${dep}"]}"
        done
        echo ""
        
        echo "Optional Dependencies:"
        for dep in "${OPTIONAL_DEPENDENCIES[@]}"; do
            local status="${DEPENDENCY_STATUS["${dep}"]:-unknown}"
            local version="${DEPENDENCY_VERSIONS["${dep}"]:-unknown}"
            echo "  ${dep}: ${status} (${version}) - ${DEPENDENCY_INFO["${dep}"]}"
        done
        echo ""
        
        echo "Overall Status: $(if [[ "${DEPENDENCIES_SATISFIED}" == "true" ]]; then echo "SATISFIED"; else echo "UNSATISFIED"; fi)"
        
    } > "${report_file}"
    
    log_success "Dependency report generated: ${report_file}"
}

# Validate dependency versions
validate_dependency_versions() {
    log_info "Validating dependency versions..."
    
    local validation_passed=true
    
    # Define minimum required versions
    declare -A MIN_VERSIONS=(
        ["sqlite3"]="3.0.0"
        ["curl"]="7.0.0"
        ["jq"]="1.5"
    )
    
    for dep in "${!MIN_VERSIONS[@]}"; do
        if [[ "${DEPENDENCY_STATUS["${dep}"]:-missing}" == "available" ]]; then
            local current_version="${DEPENDENCY_VERSIONS["${dep}"]}"
            local min_version="${MIN_VERSIONS["${dep}"]}"
            
            if ! version_compare "${current_version}" "${min_version}"; then
                log_error "Dependency version too old: ${dep} ${current_version} < ${min_version}"
                validation_passed=false
            else
                log_debug "Dependency version OK: ${dep} ${current_version} >= ${min_version}"
            fi
        fi
    done
    
    if [[ "${validation_passed}" == "true" ]]; then
        log_success "All dependency versions are valid"
    else
        log_error "Some dependency versions are too old"
    fi
    
    audit_log "VERSION_VALIDATION" "Dependency version validation: ${validation_passed}"
    return $(if [[ "${validation_passed}" == "true" ]]; then echo 0; else echo 1; fi)
}

# Simple version comparison (major.minor.patch)
version_compare() {
    local version1="$1"
    local version2="$2"
    
    # Extract numeric parts only
    version1=$(echo "${version1}" | grep -oE '^[0-9]+(\.[0-9]+)*' || echo "0.0.0")
    version2=$(echo "${version2}" | grep -oE '^[0-9]+(\.[0-9]+)*' || echo "0.0.0")
    
    # Simple comparison using sort -V if available
    if command -v sort >/dev/null 2>&1; then
        local highest
        highest=$(printf '%s\n%s\n' "${version1}" "${version2}" | sort -V | tail -n1)
        [[ "${highest}" == "${version1}" ]]
    else
        # Fallback: basic string comparison (not perfect but better than nothing)
        [[ "${version1}" == "${version2}" ]] || [[ "${version1}" > "${version2}" ]]
    fi
}

# Clean up dependency cache
cleanup_dependency_cache() {
    log_info "Cleaning up dependency cache..."
    
    case "${PACKAGE_MANAGER}" in
        "apt")
            sudo apt autoremove -y >/dev/null 2>&1 || true
            sudo apt autoclean >/dev/null 2>&1 || true
            ;;
        "dnf")
            sudo dnf autoremove -y >/dev/null 2>&1 || true
            sudo dnf clean all >/dev/null 2>&1 || true
            ;;
        "brew")
            brew cleanup >/dev/null 2>&1 || true
            ;;
        "choco")
            # Chocolatey cleanup is automatic
            ;;
    esac
    
    log_success "Dependency cache cleaned up"
}

# Export dependency functions
export -f init_dependencies check_all_dependencies install_missing_dependencies
export -f generate_dependency_report validate_dependency_versions cleanup_dependency_cache
export REQUIRED_DEPENDENCIES OPTIONAL_DEPENDENCIES DEPENDENCIES_SATISFIED

log_debug "Dependency management module loaded"
