#!/bin/bash
# tests/run_tests.sh
#
# Enterprise-grade test runner for Augment VIP
# Production-ready comprehensive testing framework
# Supports unit, integration, security, and performance testing

set -euo pipefail

# Test framework metadata
readonly TEST_VERSION="1.0.0"
readonly TEST_NAME="augment-vip-test-runner"

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Test configuration
TEST_TYPES=("unit" "integration" "security" "performance")
SELECTED_TESTS=()
VERBOSE=false
PARALLEL=false
GENERATE_REPORT=true
STOP_ON_FAILURE=false

# Test results
declare -A TEST_RESULTS=()
declare -A TEST_TIMES=()
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Color codes
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_RESET='\033[0m'

# Logging functions
log_info() {
    echo -e "${COLOR_CYAN}[TEST-INFO]${COLOR_RESET} $1"
}

log_success() {
    echo -e "${COLOR_GREEN}[TEST-PASS]${COLOR_RESET} $1"
}

log_warn() {
    echo -e "${COLOR_YELLOW}[TEST-WARN]${COLOR_RESET} $1"
}

log_error() {
    echo -e "${COLOR_RED}[TEST-FAIL]${COLOR_RESET} $1" >&2
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --type|-t)
                IFS=',' read -ra SELECTED_TESTS <<< "$2"
                shift 2
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --parallel|-p)
                PARALLEL=true
                shift
                ;;
            --no-report)
                GENERATE_REPORT=false
                shift
                ;;
            --stop-on-failure|-s)
                STOP_ON_FAILURE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown argument: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Use all test types if none specified
    if [[ ${#SELECTED_TESTS[@]} -eq 0 ]]; then
        SELECTED_TESTS=("${TEST_TYPES[@]}")
    fi
}

# Validate test environment
validate_test_environment() {
    log_info "Validating test environment..."
    
    # Check project structure
    if [[ ! -d "${PROJECT_ROOT}/core" ]]; then
        log_error "Core modules directory not found"
        return 1
    fi
    
    # Check test directories
    for test_type in "${TEST_TYPES[@]}"; do
        local test_dir="${SCRIPT_DIR}/${test_type}"
        if [[ ! -d "${test_dir}" ]]; then
            log_warn "Test directory not found: ${test_dir}"
            mkdir -p "${test_dir}"
        fi
    done
    
    # Check dependencies
    local required_commands=("bash" "sqlite3" "jq")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            log_error "Required command not found: ${cmd}"
            return 1
        fi
    done
    
    log_success "Test environment validated"
    return 0
}

# Run unit tests
run_unit_tests() {
    log_info "Running unit tests..."
    
    local test_dir="${SCRIPT_DIR}/unit"
    local test_files=()
    
    # Find test files
    if [[ -d "${test_dir}" ]]; then
        mapfile -t test_files < <(find "${test_dir}" -name "test_*.sh" -type f)
    fi
    
    if [[ ${#test_files[@]} -eq 0 ]]; then
        log_warn "No unit test files found"
        return 0
    fi
    
    local unit_passed=0
    local unit_failed=0
    
    for test_file in "${test_files[@]}"; do
        local test_name=$(basename "${test_file}" .sh)
        log_info "Running unit test: ${test_name}"
        
        local start_time=$(date +%s.%3N)
        
        if run_single_test "${test_file}"; then
            ((unit_passed++))
            log_success "Unit test passed: ${test_name}"
        else
            ((unit_failed++))
            log_error "Unit test failed: ${test_name}"
            
            if [[ "${STOP_ON_FAILURE}" == "true" ]]; then
                return 1
            fi
        fi
        
        local end_time=$(date +%s.%3N)
        local duration=$(echo "${end_time} - ${start_time}" | bc -l 2>/dev/null || echo "0")
        TEST_TIMES["unit_${test_name}"]="${duration}"
    done
    
    TEST_RESULTS["unit"]="${unit_passed}/${unit_failed}"
    log_info "Unit tests completed: ${unit_passed} passed, ${unit_failed} failed"
    
    return 0
}

# Run integration tests
run_integration_tests() {
    log_info "Running integration tests..."
    
    local test_dir="${SCRIPT_DIR}/integration"
    local test_files=()
    
    # Find test files
    if [[ -d "${test_dir}" ]]; then
        mapfile -t test_files < <(find "${test_dir}" -name "test_*.sh" -type f)
    fi
    
    if [[ ${#test_files[@]} -eq 0 ]]; then
        log_warn "No integration test files found"
        return 0
    fi
    
    local integration_passed=0
    local integration_failed=0
    
    for test_file in "${test_files[@]}"; do
        local test_name=$(basename "${test_file}" .sh)
        log_info "Running integration test: ${test_name}"
        
        local start_time=$(date +%s.%3N)
        
        if run_single_test "${test_file}"; then
            ((integration_passed++))
            log_success "Integration test passed: ${test_name}"
        else
            ((integration_failed++))
            log_error "Integration test failed: ${test_name}"
            
            if [[ "${STOP_ON_FAILURE}" == "true" ]]; then
                return 1
            fi
        fi
        
        local end_time=$(date +%s.%3N)
        local duration=$(echo "${end_time} - ${start_time}" | bc -l 2>/dev/null || echo "0")
        TEST_TIMES["integration_${test_name}"]="${duration}"
    done
    
    TEST_RESULTS["integration"]="${integration_passed}/${integration_failed}"
    log_info "Integration tests completed: ${integration_passed} passed, ${integration_failed} failed"
    
    return 0
}

# Run security tests
run_security_tests() {
    log_info "Running security tests..."
    
    local test_dir="${SCRIPT_DIR}/security"
    local test_files=()
    
    # Find test files
    if [[ -d "${test_dir}" ]]; then
        mapfile -t test_files < <(find "${test_dir}" -name "test_*.sh" -type f)
    fi
    
    if [[ ${#test_files[@]} -eq 0 ]]; then
        log_warn "No security test files found"
        return 0
    fi
    
    local security_passed=0
    local security_failed=0
    
    for test_file in "${test_files[@]}"; do
        local test_name=$(basename "${test_file}" .sh)
        log_info "Running security test: ${test_name}"
        
        local start_time=$(date +%s.%3N)
        
        if run_single_test "${test_file}"; then
            ((security_passed++))
            log_success "Security test passed: ${test_name}"
        else
            ((security_failed++))
            log_error "Security test failed: ${test_name}"
            
            if [[ "${STOP_ON_FAILURE}" == "true" ]]; then
                return 1
            fi
        fi
        
        local end_time=$(date +%s.%3N)
        local duration=$(echo "${end_time} - ${start_time}" | bc -l 2>/dev/null || echo "0")
        TEST_TIMES["security_${test_name}"]="${duration}"
    done
    
    TEST_RESULTS["security"]="${security_passed}/${security_failed}"
    log_info "Security tests completed: ${security_passed} passed, ${security_failed} failed"
    
    return 0
}

# Run performance tests
run_performance_tests() {
    log_info "Running performance tests..."
    
    local test_dir="${SCRIPT_DIR}/performance"
    local test_files=()
    
    # Find test files
    if [[ -d "${test_dir}" ]]; then
        mapfile -t test_files < <(find "${test_dir}" -name "test_*.sh" -type f)
    fi
    
    if [[ ${#test_files[@]} -eq 0 ]]; then
        log_warn "No performance test files found"
        return 0
    fi
    
    local performance_passed=0
    local performance_failed=0
    
    for test_file in "${test_files[@]}"; do
        local test_name=$(basename "${test_file}" .sh)
        log_info "Running performance test: ${test_name}"
        
        local start_time=$(date +%s.%3N)
        
        if run_single_test "${test_file}"; then
            ((performance_passed++))
            log_success "Performance test passed: ${test_name}"
        else
            ((performance_failed++))
            log_error "Performance test failed: ${test_name}"
            
            if [[ "${STOP_ON_FAILURE}" == "true" ]]; then
                return 1
            fi
        fi
        
        local end_time=$(date +%s.%3N)
        local duration=$(echo "${end_time} - ${start_time}" | bc -l 2>/dev/null || echo "0")
        TEST_TIMES["performance_${test_name}"]="${duration}"
    done
    
    TEST_RESULTS["performance"]="${performance_passed}/${performance_failed}"
    log_info "Performance tests completed: ${performance_passed} passed, ${performance_failed} failed"
    
    return 0
}

# Run single test file
run_single_test() {
    local test_file="$1"
    
    # Set up test environment
    export PROJECT_ROOT
    export TEST_MODE=true
    export VERBOSE
    
    # Run test in subshell to isolate environment
    (
        cd "${PROJECT_ROOT}"
        
        if [[ "${VERBOSE}" == "true" ]]; then
            bash "${test_file}"
        else
            bash "${test_file}" >/dev/null 2>&1
        fi
    )
    
    return $?
}

# Generate test report
generate_test_report() {
    if [[ "${GENERATE_REPORT}" != "true" ]]; then
        return 0
    fi
    
    local report_file="${SCRIPT_DIR}/test_report_$(date +%Y%m%d_%H%M%S).txt"
    
    log_info "Generating test report: ${report_file}"
    
    {
        echo "=== Augment VIP Test Report ==="
        echo "Generated: $(date)"
        echo "Test Runner Version: ${TEST_VERSION}"
        echo "Project Root: ${PROJECT_ROOT}"
        echo ""
        
        echo "Test Configuration:"
        echo "  Selected Tests: ${SELECTED_TESTS[*]}"
        echo "  Verbose Mode: ${VERBOSE}"
        echo "  Parallel Mode: ${PARALLEL}"
        echo "  Stop on Failure: ${STOP_ON_FAILURE}"
        echo ""
        
        echo "Test Results Summary:"
        echo "  Total Tests: ${TOTAL_TESTS}"
        echo "  Passed: ${PASSED_TESTS}"
        echo "  Failed: ${FAILED_TESTS}"
        echo "  Skipped: ${SKIPPED_TESTS}"
        echo ""
        
        echo "Results by Type:"
        for test_type in "${SELECTED_TESTS[@]}"; do
            if [[ -n "${TEST_RESULTS["${test_type}"]:-}" ]]; then
                echo "  ${test_type}: ${TEST_RESULTS["${test_type}"]}"
            fi
        done
        echo ""
        
        echo "Test Execution Times:"
        for test_name in "${!TEST_TIMES[@]}"; do
            echo "  ${test_name}: ${TEST_TIMES["${test_name}"]}s"
        done
        echo ""
        
        echo "Environment Information:"
        echo "  OS: $(uname -s)"
        echo "  Kernel: $(uname -r)"
        echo "  Architecture: $(uname -m)"
        echo "  Shell: ${BASH_VERSION}"
        echo "  User: ${USER:-unknown}"
        
    } > "${report_file}"
    
    log_success "Test report generated: ${report_file}"
}

# Main test execution
main() {
    log_info "Starting Augment VIP test suite v${TEST_VERSION}"
    
    # Validate environment
    if ! validate_test_environment; then
        log_error "Test environment validation failed"
        return 1
    fi
    
    # Run selected test types
    for test_type in "${SELECTED_TESTS[@]}"; do
        case "${test_type}" in
            "unit")
                run_unit_tests
                ;;
            "integration")
                run_integration_tests
                ;;
            "security")
                run_security_tests
                ;;
            "performance")
                run_performance_tests
                ;;
            *)
                log_error "Unknown test type: ${test_type}"
                return 1
                ;;
        esac
    done
    
    # Calculate totals
    for test_type in "${SELECTED_TESTS[@]}"; do
        if [[ -n "${TEST_RESULTS["${test_type}"]:-}" ]]; then
            local passed=$(echo "${TEST_RESULTS["${test_type}"]}" | cut -d'/' -f1)
            local failed=$(echo "${TEST_RESULTS["${test_type}"]}" | cut -d'/' -f2)
            ((PASSED_TESTS += passed))
            ((FAILED_TESTS += failed))
            ((TOTAL_TESTS += passed + failed))
        fi
    done
    
    # Generate report
    generate_test_report
    
    # Print summary
    log_info "Test execution completed"
    log_info "Total: ${TOTAL_TESTS}, Passed: ${PASSED_TESTS}, Failed: ${FAILED_TESTS}"
    
    if [[ ${FAILED_TESTS} -eq 0 ]]; then
        log_success "All tests passed!"
        return 0
    else
        log_error "${FAILED_TESTS} test(s) failed"
        return 1
    fi
}

# Show help information
show_help() {
    cat << EOF
Augment VIP Test Runner v${TEST_VERSION}

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -t, --type TYPES           Comma-separated list of test types to run
    -v, --verbose              Enable verbose output
    -p, --parallel             Run tests in parallel (not implemented)
    --no-report               Skip test report generation
    -s, --stop-on-failure     Stop execution on first test failure
    -h, --help                Show this help message

TEST TYPES:
    unit                      Unit tests for individual modules
    integration               Integration tests for cross-module functionality
    security                  Security and vulnerability tests
    performance               Performance and benchmark tests

EXAMPLES:
    $0                        Run all test types
    $0 --type unit,security   Run only unit and security tests
    $0 --verbose --stop-on-failure  Run with verbose output, stop on failure

NOTES:
    - Test files should be named test_*.sh
    - Tests should exit with 0 for success, non-zero for failure
    - Test environment variables: PROJECT_ROOT, TEST_MODE, VERBOSE

EOF
}

# Main script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_arguments "$@"
    
    if main; then
        exit 0
    else
        exit 1
    fi
fi
