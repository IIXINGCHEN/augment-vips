#!/usr/bin/env bash
#
# install.sh - Linux installation script for Augment VIP
#
# Description: Installation script for the Augment VIP project (Linux version)
# Based on: https://github.com/azrilaiman2003/augment-vip
# Enhanced for cross-platform compatibility
#
# Usage: ./install.sh [options]
# Options:
#   --help         Show this help message
#   --clean        Run database cleaning script after installation
#   --modify-ids   Run telemetry ID modification script after installation
#   --all          Run all scripts (clean and modify IDs)
#   --preview      Preview operations without making changes

set -e  # Exit immediately if a command exits with a non-zero status
set -u  # Treat unset variables as an error

# Text formatting
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

# Log functions
log_info() {
    echo -e "${BLUE}[INFO]${RESET} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${RESET} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${RESET} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${RESET} $1"
}

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Check for Python
check_python() {
    log_info "Checking for Python..."
    
    # Try python3 first, then python as fallback
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
        log_success "Found Python 3: $(python3 --version)"
    elif command -v python &> /dev/null; then
        # Check if python is Python 3
        PYTHON_VERSION=$(python --version 2>&1)
        if [[ $PYTHON_VERSION == *"Python 3"* ]]; then
            PYTHON_CMD="python"
            log_success "Found Python 3: $PYTHON_VERSION"
        else
            log_error "Python 3 is required but found: $PYTHON_VERSION"
            log_info "Please install Python 3.6 or higher:"
            log_info "  Ubuntu/Debian: sudo apt install python3 python3-venv python3-pip"
            log_info "  Fedora/RHEL: sudo dnf install python3 python3-venv python3-pip"
            log_info "  Arch: sudo pacman -S python python-pip"
            exit 1
        fi
    else
        log_error "Python 3 is not installed or not in PATH"
        log_info "Please install Python 3.6 or higher:"
        log_info "  Ubuntu/Debian: sudo apt install python3 python3-venv python3-pip"
        log_info "  Fedora/RHEL: sudo dnf install python3 python3-venv python3-pip"
        log_info "  Arch: sudo pacman -S python python-pip"
        exit 1
    fi
}

# Check for required system packages
check_system_dependencies() {
    log_info "Checking system dependencies..."
    
    # Check for venv module
    if ! $PYTHON_CMD -c "import venv" 2>/dev/null; then
        log_error "Python venv module not found"
        log_info "Please install python3-venv:"
        log_info "  Ubuntu/Debian: sudo apt install python3-venv"
        log_info "  Fedora/RHEL: sudo dnf install python3-venv"
        exit 1
    fi
    
    log_success "All system dependencies are available"
}

# Run Python installer
run_python_installer() {
    log_info "Running Python installer..."
    
    # Change to the cross-platform directory
    CROSS_PLATFORM_DIR="$PROJECT_ROOT/scripts/cross-platform"
    
    if [ ! -d "$CROSS_PLATFORM_DIR" ]; then
        log_error "Cross-platform directory not found: $CROSS_PLATFORM_DIR"
        exit 1
    fi
    
    cd "$CROSS_PLATFORM_DIR"
    
    # Run the Python installer
    if "$PYTHON_CMD" install.py; then
        log_success "Python installation completed successfully"
    else
        log_error "Python installation failed"
        exit 1
    fi
    
    # Return to the original directory
    cd - > /dev/null
}

# Get the path to the augment-vip command
get_augment_command() {
    CROSS_PLATFORM_DIR="$PROJECT_ROOT/scripts/cross-platform"
    AUGMENT_CMD="$CROSS_PLATFORM_DIR/.venv/bin/augment-vip"
    
    if [ ! -f "$AUGMENT_CMD" ]; then
        log_error "Augment VIP command not found at: $AUGMENT_CMD"
        exit 1
    fi
    
    echo "$AUGMENT_CMD"
}

# Display help message
show_help() {
    echo "Augment VIP Installation Script (Linux Version)"
    echo
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --help         Show this help message"
    echo "  --clean        Run database cleaning script after installation"
    echo "  --modify-ids   Run telemetry ID modification script after installation"
    echo "  --all          Run all scripts (clean and modify IDs)"
    echo "  --preview      Preview operations without making changes"
    echo
    echo "Examples:"
    echo "  $0 --all"
    echo "  $0 --clean"
    echo "  $0 --preview"
}

# Parse command line arguments
CLEAN_DB=false
MODIFY_IDS=false
RUN_ALL=false
PREVIEW_MODE=false

for arg in "$@"; do
    case $arg in
        --help)
            show_help
            exit 0
            ;;
        --clean)
            CLEAN_DB=true
            ;;
        --modify-ids)
            MODIFY_IDS=true
            ;;
        --all)
            RUN_ALL=true
            ;;
        --preview)
            PREVIEW_MODE=true
            ;;
        *)
            log_error "Unknown option: $arg"
            show_help
            exit 1
            ;;
    esac
done

# Main installation function
main() {
    log_info "Starting installation process for Augment VIP (Linux Version)"
    log_info "Project root: $PROJECT_ROOT"
    
    # Check for Python
    check_python
    
    # Check system dependencies
    check_system_dependencies
    
    # Run Python installer
    run_python_installer
    
    # Get the augment-vip command path
    AUGMENT_CMD=$(get_augment_command)
    
    # Run operations based on arguments
    if [ "$PREVIEW_MODE" = true ]; then
        log_info "Running preview mode..."
        "$AUGMENT_CMD" preview
    elif [ "$RUN_ALL" = true ]; then
        log_info "Running all operations..."
        "$AUGMENT_CMD" all
    else
        # Run individual operations
        if [ "$CLEAN_DB" = true ]; then
            log_info "Running database cleaning..."
            "$AUGMENT_CMD" clean
        fi
        
        if [ "$MODIFY_IDS" = true ]; then
            log_info "Running telemetry ID modification..."
            "$AUGMENT_CMD" modify-ids
        fi
        
        # If no specific operations requested, prompt user
        if [ "$CLEAN_DB" = false ] && [ "$MODIFY_IDS" = false ]; then
            echo
            read -p "Would you like to clean VS Code databases now? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log_info "Running database cleaning..."
                "$AUGMENT_CMD" clean
            fi
            
            echo
            read -p "Would you like to modify VS Code telemetry IDs now? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log_info "Running telemetry ID modification..."
                "$AUGMENT_CMD" modify-ids
            fi
        fi
    fi
    
    log_success "Installation and setup completed!"
    log_info "You can now use Augment VIP with the following commands:"
    log_info "  $AUGMENT_CMD clean        # Clean VS Code databases"
    log_info "  $AUGMENT_CMD modify-ids   # Modify telemetry IDs"
    log_info "  $AUGMENT_CMD all          # Run all operations"
    log_info "  $AUGMENT_CMD preview      # Preview operations"
}

# Execute main function
main "$@"
