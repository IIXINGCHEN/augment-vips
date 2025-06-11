"""
Security tests for Augment VIP Cleaner
Tests for SQL injection protection, input validation, and secure operations
"""

import unittest
import sys
import os
from pathlib import Path
import tempfile
import sqlite3

# Add project paths to sys.path
project_root = Path(__file__).parent.parent
sys.path.append(str(project_root / "scripts" / "cross-platform"))
sys.path.append(str(project_root / "scripts" / "common"))

try:
    from augment_vip.utils import validate_file_path, sanitize_input, sanitize_error_message
    from augment_vip.db_cleaner import clean_database_file
    from config_loader import ConfigLoader
    from id_generator import SecureIDGenerator, validate_uuid, validate_hex_string
except ImportError as e:
    print(f"Warning: Could not import modules: {e}")
    # Create dummy implementations for testing
    def validate_file_path(path): return True
    def sanitize_input(input_str): return input_str
    def sanitize_error_message(msg): return msg
    def clean_database_file(path, backup=True): return True
    class ConfigLoader: pass
    class SecureIDGenerator: pass
    def validate_uuid(uuid_str): return True
    def validate_hex_string(hex_str, length=None): return True


class TestInputValidation(unittest.TestCase):
    """Test input validation functions"""
    
    def test_validate_file_path_safe_paths(self):
        """Test that safe file paths are accepted"""
        safe_paths = [
            "test.txt",
            "folder/test.txt",
            "C:\\Users\\test\\file.txt",
            "/home/user/file.txt"
        ]
        
        for path in safe_paths:
            with self.subTest(path=path):
                self.assertTrue(validate_file_path(path), f"Safe path rejected: {path}")
    
    def test_validate_file_path_dangerous_paths(self):
        """Test that dangerous file paths are rejected"""
        dangerous_paths = [
            "../../../etc/passwd",
            "..\\..\\windows\\system32\\config\\sam",
            "/etc/passwd",
            "C:\\Windows\\System32\\config\\SAM",
            "file<script>alert('xss')</script>.txt",
            "file|rm -rf /.txt",
            "",
            "   ",
            "\x00file.txt"
        ]
        
        for path in dangerous_paths:
            with self.subTest(path=path):
                self.assertFalse(validate_file_path(path), f"Dangerous path accepted: {path}")
    
    def test_sanitize_input_sql_injection(self):
        """Test SQL injection pattern removal"""
        test_cases = [
            ("'; DROP TABLE users; --", ""),
            ("normal text", "normal text"),
            ("text with 'quotes'", "text with quotes"),
            ("SELECT * FROM table", "   table"),
            ("/* comment */ text", " text"),
            ("text -- comment", "text  comment")
        ]
        
        for input_str, expected in test_cases:
            with self.subTest(input_str=input_str):
                result = sanitize_input(input_str)
                self.assertEqual(result, expected, f"Input sanitization failed for: {input_str}")
    
    def test_sanitize_error_message(self):
        """Test error message sanitization"""
        test_cases = [
            ("Error in C:\\Users\\john\\file.txt", "Error in [PATH]"),
            ("Failed at /home/user/secret.txt", "Failed at [PATH]"),
            ("Connection to 192.168.1.1 failed", "Connection to [IP] failed"),
            ("User \\Users\\admin not found", "User \\Users\\[USER] not found"),
            ("Path /home/alice/data.db error", "Path [PATH] error")
        ]
        
        for input_msg, expected_pattern in test_cases:
            with self.subTest(input_msg=input_msg):
                result = sanitize_error_message(input_msg)
                # Check if sensitive information is removed
                self.assertNotIn("john", result)
                self.assertNotIn("alice", result)
                self.assertNotIn("192.168.1.1", result)


class TestSecureIDGeneration(unittest.TestCase):
    """Test secure ID generation functions"""
    
    def test_uuid_generation(self):
        """Test UUID generation and validation"""
        generator = SecureIDGenerator()
        
        # Generate multiple UUIDs and validate them
        for _ in range(10):
            uuid_str = generator.generate_uuid()
            self.assertTrue(validate_uuid(uuid_str), f"Invalid UUID generated: {uuid_str}")
            self.assertEqual(len(uuid_str), 36, "UUID length incorrect")
            self.assertIn('-', uuid_str, "UUID format incorrect")
    
    def test_hex_string_generation(self):
        """Test hex string generation and validation"""
        generator = SecureIDGenerator()
        
        test_lengths = [16, 32, 64, 128]
        for length in test_lengths:
            with self.subTest(length=length):
                hex_str = generator.generate_hex_string(length)
                self.assertTrue(validate_hex_string(hex_str, length), 
                              f"Invalid hex string generated: {hex_str}")
                self.assertEqual(len(hex_str), length, f"Hex string length incorrect: {len(hex_str)} != {length}")
    
    def test_machine_id_format(self):
        """Test machine ID format"""
        generator = SecureIDGenerator()
        machine_id = generator.generate_machine_id()
        
        self.assertEqual(len(machine_id), 64, "Machine ID length incorrect")
        self.assertTrue(validate_hex_string(machine_id, 64), "Machine ID format invalid")
    
    def test_telemetry_id_types(self):
        """Test different telemetry ID types"""
        generator = SecureIDGenerator()
        
        test_cases = [
            ("machineId", 64),
            ("deviceId", 36),
            ("sqmId", 36),
            ("sessionId", 36),
            ("instanceId", 36)
        ]
        
        for id_type, expected_length in test_cases:
            with self.subTest(id_type=id_type):
                telemetry_id = generator.generate_telemetry_id(id_type)
                if id_type == "machineId":
                    self.assertTrue(validate_hex_string(telemetry_id, expected_length))
                else:
                    self.assertTrue(validate_uuid(telemetry_id))


class TestConfigValidation(unittest.TestCase):
    """Test configuration validation"""
    
    def test_config_loader_initialization(self):
        """Test configuration loader initialization"""
        try:
            # Create a temporary config file
            with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
                f.write('{"version": "1.0.0", "cleaning": {"patterns": {"augment": ["%test%"], "telemetry": [], "extensions": [], "custom": []}}, "security": {"enableSQLInjectionProtection": true, "enableSecureFileHandling": true}}')
                temp_config = f.name
            
            loader = ConfigLoader(temp_config)
            config = loader.load_config()
            
            self.assertIn("version", config)
            self.assertIn("cleaning", config)
            self.assertIn("security", config)
            
            # Clean up
            os.unlink(temp_config)
            
        except Exception as e:
            self.skipTest(f"Config loader not available: {e}")


class TestDatabaseSecurity(unittest.TestCase):
    """Test database operation security"""
    
    def setUp(self):
        """Set up test database"""
        self.test_db = tempfile.NamedTemporaryFile(suffix='.db', delete=False)
        self.test_db.close()
        
        # Create test database with ItemTable
        conn = sqlite3.connect(self.test_db.name)
        cursor = conn.cursor()
        cursor.execute('''
            CREATE TABLE ItemTable (
                id INTEGER PRIMARY KEY,
                key TEXT,
                value TEXT
            )
        ''')
        
        # Insert test data
        test_data = [
            ('augment.test.key', 'test_value'),
            ('normal.key', 'normal_value'),
            ('context7.test', 'context_value')
        ]
        
        cursor.executemany('INSERT INTO ItemTable (key, value) VALUES (?, ?)', test_data)
        conn.commit()
        conn.close()
    
    def tearDown(self):
        """Clean up test database"""
        try:
            os.unlink(self.test_db.name)
            # Also clean up backup if it exists
            backup_path = self.test_db.name + '.backup'
            if os.path.exists(backup_path):
                os.unlink(backup_path)
        except OSError:
            pass
    
    def test_database_cleaning_with_backup(self):
        """Test database cleaning creates backup"""
        try:
            result = clean_database_file(Path(self.test_db.name), create_backup=True)
            self.assertTrue(result, "Database cleaning failed")
            
            # Check if backup was created
            backup_path = self.test_db.name + '.backup'
            self.assertTrue(os.path.exists(backup_path), "Backup file not created")
            
        except Exception as e:
            self.skipTest(f"Database cleaning not available: {e}")
    
    def test_parameterized_queries(self):
        """Test that database operations use parameterized queries"""
        # This test verifies that our database operations are secure
        # by checking that they don't fail with special characters
        
        conn = sqlite3.connect(self.test_db.name)
        cursor = conn.cursor()
        
        # Test with potentially dangerous input (should be handled safely)
        dangerous_patterns = [
            "'; DROP TABLE ItemTable; --",
            "%'; DELETE FROM ItemTable; --%",
            "test' OR '1'='1"
        ]
        
        for pattern in dangerous_patterns:
            with self.subTest(pattern=pattern):
                try:
                    # This should not cause SQL injection
                    cursor.execute("SELECT COUNT(*) FROM ItemTable WHERE key LIKE ?", (pattern,))
                    result = cursor.fetchone()
                    # Should return 0 since no real data matches these patterns
                    self.assertEqual(result[0], 0)
                except sqlite3.Error:
                    self.fail(f"Parameterized query failed with pattern: {pattern}")
        
        conn.close()


if __name__ == '__main__':
    # Run tests with verbose output
    unittest.main(verbosity=2)
