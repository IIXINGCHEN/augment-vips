#!/usr/bin/env bash
#
# Augment VIP Universal Installer
# Cross-platform installation script for Windows, macOS, and Linux
#
# Based on: https://github.com/azrilaiman2003/augment-vip
# Enhanced for enterprise use with PowerShell integration on Windows
#
# Usage: ./install.sh [options]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect operating system
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        OS="windows"
    else
        log_error "Unsupported operating system: $OSTYPE"
        exit 1
    fi
    
    log_info "Detected OS: $OS"
}

# Show help
show_help() {
    cat << EOF
Augment VIP Universal Installer
==============================

Cross-platform installation script for Augment VIP.

Usage: $0 [options]

Options:
  --help         Show this help message
  --clean        Run database cleaning after installation
  --modify-ids   Run telemetry ID modification after installation
  --all          Run all operations after installation
  --preview      Preview operations without making changes
  --python-only  Force Python implementation (cross-platform)
  --windows-only Force Windows PowerShell implementation (Windows only)

Examples:
  $0 --all                    # Install and run all operations
  $0 --clean                  # Install and clean databases
  $0 --preview                # Install and preview operations
  $0 --python-only --all      # Force Python implementation

Platform Support:
  - Linux: Python cross-platform implementation
  - macOS: Python cross-platform implementation  
  - Windows: PowerShell implementation (with Python fallback)

EOF
}

# Install for Linux/macOS
install_unix() {
    log_info "Installing Augment VIP for $OS..."
    
    # Check if we're forcing Python implementation
    if [[ "$FORCE_PYTHON" == "true" ]] || [[ "$OS" != "windows" ]]; then
        log_info "Using Python cross-platform implementation"
        
        # Run Linux installer
        if [[ -f "scripts/linux/install.sh" ]]; then
            chmod +x scripts/linux/install.sh
            ./scripts/linux/install.sh "$@"
        else
            log_error "Linux installer not found at scripts/linux/install.sh"
            exit 1
        fi
    else
        log_error "Windows PowerShell implementation not available on $OS"
        log_info "Use --python-only flag to force Python implementation"
        exit 1
    fi
}

# Install for Windows
install_windows() {
    log_info "Installing Augment VIP for Windows..."
    
    if [[ "$FORCE_PYTHON" == "true" ]]; then
        log_info "Forcing Python cross-platform implementation"
        install_unix "$@"
        return
    fi
    
    # Check if PowerShell is available
    if command -v powershell &> /dev/null || command -v pwsh &> /dev/null; then
        log_info "Using Windows PowerShell implementation"
        
        # Determine PowerShell command
        if command -v pwsh &> /dev/null; then
            PS_CMD="pwsh"
        else
            PS_CMD="powershell"
        fi
        
        # Run Windows launcher
        if [[ -f "scripts/augment-vip-launcher.ps1" ]]; then
            # Map bash arguments to PowerShell parameters
            PS_ARGS=""
            
            for arg in "$@"; do
                case $arg in
                    --clean)
                        PS_ARGS="$PS_ARGS -Operation Clean"
                        ;;
                    --modify-ids)
                        PS_ARGS="$PS_ARGS -Operation ModifyTelemetry"
                        ;;
                    --all)
                        PS_ARGS="$PS_ARGS -Operation All"
                        ;;
                    --preview)
                        PS_ARGS="$PS_ARGS -Operation Preview"
                        ;;
                esac
            done
            
            # Default to All if no operation specified
            if [[ -z "$PS_ARGS" ]]; then
                PS_ARGS="-Operation All"
            fi
            
            $PS_CMD -ExecutionPolicy Bypass -File "scripts/augment-vip-launcher.ps1" $PS_ARGS
        else
            log_error "Windows launcher not found at scripts/augment-vip-launcher.ps1"
            exit 1
        fi
    else
        log_warning "PowerShell not available, falling back to Python implementation"
        install_unix "$@"
    fi
}

# Parse command line arguments
FORCE_PYTHON=false
FORCE_WINDOWS=false

for arg in "$@"; do
    case $arg in
        --help)
            show_help
            exit 0
            ;;
        --python-only)
            FORCE_PYTHON=true
            ;;
        --windows-only)
            FORCE_WINDOWS=true
            ;;
    esac
done

# Main installation
main() {
    log_info "Augment VIP Universal Installer"
    log_info "==============================="
    
    # Detect OS
    detect_os
    
    # Validate conflicting flags
    if [[ "$FORCE_PYTHON" == "true" ]] && [[ "$FORCE_WINDOWS" == "true" ]]; then
        log_error "Cannot use both --python-only and --windows-only flags"
        exit 1
    fi
    
    # Check for Windows-only flag on non-Windows systems
    if [[ "$FORCE_WINDOWS" == "true" ]] && [[ "$OS" != "windows" ]]; then
        log_error "--windows-only flag is only valid on Windows systems"
        exit 1
    fi
    
    # Install based on OS
    case $OS in
        linux|macos)
            install_unix "$@"
            ;;
        windows)
            install_windows "$@"
            ;;
        *)
            log_error "Unsupported OS: $OS"
            exit 1
            ;;
    esac
    
    log_success "Installation completed!"
    log_info ""
    log_info "Next steps:"
    log_info "  - For Windows: Use scripts/augment-vip-launcher.ps1"
    log_info "  - For Linux/macOS: Use scripts/cross-platform/.venv/bin/augment-vip"
    log_info "  - Or use this universal installer with operation flags"
}

# Run main function
main "$@"
