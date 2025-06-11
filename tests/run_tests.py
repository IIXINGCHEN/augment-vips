#!/usr/bin/env python3
"""
Test runner for Augment VIP Cleaner
Runs all tests and generates coverage reports
"""

import sys
import os
import unittest
import argparse
from pathlib import Path

# Add project paths to sys.path
project_root = Path(__file__).parent.parent
sys.path.append(str(project_root / "scripts" / "cross-platform"))
sys.path.append(str(project_root / "scripts" / "common"))

def discover_and_run_tests(test_pattern="test_*.py", verbosity=2):
    """
    Discover and run all tests
    
    Args:
        test_pattern: Pattern to match test files
        verbosity: Test output verbosity level
        
    Returns:
        TestResult object
    """
    # Discover tests
    loader = unittest.TestLoader()
    start_dir = Path(__file__).parent
    suite = loader.discover(start_dir, pattern=test_pattern)
    
    # Run tests
    runner = unittest.TextTestRunner(verbosity=verbosity, buffer=True)
    result = runner.run(suite)
    
    return result


def run_security_tests():
    """Run security-specific tests"""
    print("=" * 60)
    print("RUNNING SECURITY TESTS")
    print("=" * 60)
    
    try:
        from test_security import (
            TestInputValidation, TestSecureIDGeneration, 
            TestConfigValidation, TestDatabaseSecurity
        )
        
        # Create test suite
        suite = unittest.TestSuite()
        
        # Add security test cases
        suite.addTest(unittest.makeSuite(TestInputValidation))
        suite.addTest(unittest.makeSuite(TestSecureIDGeneration))
        suite.addTest(unittest.makeSuite(TestConfigValidation))
        suite.addTest(unittest.makeSuite(TestDatabaseSecurity))
        
        # Run tests
        runner = unittest.TextTestRunner(verbosity=2, buffer=True)
        result = runner.run(suite)
        
        return result
        
    except ImportError as e:
        print(f"Warning: Could not import security tests: {e}")
        return None


def run_integration_tests():
    """Run integration tests"""
    print("=" * 60)
    print("RUNNING INTEGRATION TESTS")
    print("=" * 60)
    
    try:
        from test_integration import (
            TestConfigIntegration, TestTransactionIntegration,
            TestDatabaseIntegration, TestSecurityIntegration,
            TestEndToEndWorkflow
        )
        
        # Create test suite
        suite = unittest.TestSuite()
        
        # Add integration test cases
        suite.addTest(unittest.makeSuite(TestConfigIntegration))
        suite.addTest(unittest.makeSuite(TestTransactionIntegration))
        suite.addTest(unittest.makeSuite(TestDatabaseIntegration))
        suite.addTest(unittest.makeSuite(TestSecurityIntegration))
        suite.addTest(unittest.makeSuite(TestEndToEndWorkflow))
        
        # Run tests
        runner = unittest.TextTestRunner(verbosity=2, buffer=True)
        result = runner.run(suite)
        
        return result
        
    except ImportError as e:
        print(f"Warning: Could not import integration tests: {e}")
        return None


def check_dependencies():
    """Check if required dependencies are available"""
    print("Checking test dependencies...")
    
    required_modules = [
        'sqlite3',
        'json',
        'pathlib',
        'tempfile',
        'unittest'
    ]
    
    optional_modules = [
        'jsonschema',
        'psutil',
        'colorama'
    ]
    
    missing_required = []
    missing_optional = []
    
    for module in required_modules:
        try:
            __import__(module)
            print(f"✓ {module}")
        except ImportError:
            missing_required.append(module)
            print(f"✗ {module} (REQUIRED)")
    
    for module in optional_modules:
        try:
            __import__(module)
            print(f"✓ {module}")
        except ImportError:
            missing_optional.append(module)
            print(f"? {module} (optional)")
    
    if missing_required:
        print(f"\nERROR: Missing required modules: {', '.join(missing_required)}")
        return False
    
    if missing_optional:
        print(f"\nWarning: Missing optional modules: {', '.join(missing_optional)}")
        print("Some tests may be skipped.")
    
    print("\nDependency check completed.")
    return True


def generate_test_report(results):
    """Generate test report"""
    print("\n" + "=" * 60)
    print("TEST REPORT")
    print("=" * 60)
    
    total_tests = 0
    total_failures = 0
    total_errors = 0
    total_skipped = 0
    
    for result in results:
        if result:
            total_tests += result.testsRun
            total_failures += len(result.failures)
            total_errors += len(result.errors)
            total_skipped += len(result.skipped)
    
    print(f"Total Tests Run: {total_tests}")
    print(f"Failures: {total_failures}")
    print(f"Errors: {total_errors}")
    print(f"Skipped: {total_skipped}")
    print(f"Success Rate: {((total_tests - total_failures - total_errors) / max(total_tests, 1)) * 100:.1f}%")
    
    if total_failures > 0 or total_errors > 0:
        print("\n❌ SOME TESTS FAILED")
        return False
    else:
        print("\n✅ ALL TESTS PASSED")
        return True


def main():
    """Main test runner function"""
    parser = argparse.ArgumentParser(description="Run Augment VIP Cleaner tests")
    parser.add_argument("--security", action="store_true", help="Run only security tests")
    parser.add_argument("--integration", action="store_true", help="Run only integration tests")
    parser.add_argument("--all", action="store_true", help="Run all tests (default)")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    parser.add_argument("--check-deps", action="store_true", help="Check dependencies only")
    
    args = parser.parse_args()
    
    # Check dependencies first
    if not check_dependencies():
        return 1
    
    if args.check_deps:
        return 0
    
    print("\n" + "=" * 60)
    print("AUGMENT VIP CLEANER - TEST SUITE")
    print("=" * 60)
    
    results = []
    
    try:
        if args.security or args.all or (not args.security and not args.integration):
            security_result = run_security_tests()
            if security_result:
                results.append(security_result)
        
        if args.integration or args.all or (not args.security and not args.integration):
            integration_result = run_integration_tests()
            if integration_result:
                results.append(integration_result)
        
        # Generate final report
        success = generate_test_report(results)
        
        return 0 if success else 1
        
    except KeyboardInterrupt:
        print("\n\nTests interrupted by user")
        return 130
    except Exception as e:
        print(f"\n\nUnexpected error running tests: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
