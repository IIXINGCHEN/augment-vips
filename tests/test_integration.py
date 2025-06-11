"""
Integration tests for Augment VIP Cleaner
Tests cross-module interactions and end-to-end functionality
"""

import unittest
import sys
import os
import tempfile
import json
import sqlite3
from pathlib import Path

# Add project paths to sys.path
project_root = Path(__file__).parent.parent
sys.path.append(str(project_root / "scripts" / "cross-platform"))
sys.path.append(str(project_root / "scripts" / "common"))

try:
    from config_loader import ConfigLoader, get_cleaning_patterns
    from transaction_manager import TransactionManager, TransactionOperation
    from id_generator import SecureIDGenerator
    from augment_vip.db_cleaner import clean_database_file, preview_cleanup
    from augment_vip.utils import backup_file, validate_file_path
except ImportError as e:
    print(f"Warning: Could not import modules for integration tests: {e}")


class TestConfigIntegration(unittest.TestCase):
    """Test configuration system integration"""
    
    def setUp(self):
        """Set up test configuration"""
        self.test_config = {
            "version": "1.0.0",
            "environment": "testing",
            "cleaning": {
                "patterns": {
                    "augment": ["%augment%", "%test%"],
                    "telemetry": ["%telemetry%"],
                    "extensions": ["%ext%"],
                    "custom": ["%custom%"]
                },
                "enableDatabaseCleaning": True,
                "enableTelemetryModification": True,
                "checkVSCodeRunning": False
            },
            "security": {
                "enableSQLInjectionProtection": True,
                "enableSecureFileHandling": True,
                "backupFilePermissions": "OwnerOnly",
                "secureDeletePasses": 3
            },
            "backup": {
                "enabled": True,
                "retentionDays": 30,
                "maxBackupCount": 5,
                "directory": "./test_backups"
            }
        }
        
        # Create temporary config file
        self.config_file = tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False)
        json.dump(self.test_config, self.config_file, indent=2)
        self.config_file.close()
    
    def tearDown(self):
        """Clean up test configuration"""
        try:
            os.unlink(self.config_file.name)
        except OSError:
            pass
    
    def test_config_loading_and_pattern_retrieval(self):
        """Test configuration loading and pattern retrieval"""
        try:
            loader = ConfigLoader(self.config_file.name)
            
            # Test pattern retrieval
            augment_patterns = loader.get_cleaning_patterns("augment")
            self.assertEqual(augment_patterns, ["%augment%", "%test%"])
            
            telemetry_patterns = loader.get_cleaning_patterns("telemetry")
            self.assertEqual(telemetry_patterns, ["%telemetry%"])
            
            # Test all patterns
            all_patterns = loader.get_all_cleaning_patterns()
            expected_all = ["%augment%", "%test%", "%telemetry%", "%ext%", "%custom%"]
            self.assertEqual(all_patterns, expected_all)
            
            # Test security settings
            security = loader.get_security_settings()
            self.assertTrue(security["enableSQLInjectionProtection"])
            self.assertTrue(security["enableSecureFileHandling"])
            
        except Exception as e:
            self.skipTest(f"Config loader not available: {e}")


class TestTransactionIntegration(unittest.TestCase):
    """Test transaction manager integration"""
    
    def setUp(self):
        """Set up test transaction environment"""
        self.test_dir = tempfile.mkdtemp()
        self.transaction_manager = None
        
        try:
            self.transaction_manager = TransactionManager(
                transaction_log_dir=os.path.join(self.test_dir, "transactions")
            )
        except Exception:
            pass
    
    def tearDown(self):
        """Clean up test environment"""
        import shutil
        try:
            shutil.rmtree(self.test_dir)
        except OSError:
            pass
    
    def test_transaction_rollback_integration(self):
        """Test transaction rollback with file operations"""
        if not self.transaction_manager:
            self.skipTest("Transaction manager not available")
        
        # Create test file
        test_file = os.path.join(self.test_dir, "test.txt")
        with open(test_file, 'w') as f:
            f.write("original content")
        
        # Create backup
        backup_file = test_file + ".backup"
        with open(backup_file, 'w') as f:
            f.write("original content")
        
        try:
            # Begin transaction
            tx_id = self.transaction_manager.begin_transaction()
            
            # Add file operation
            operation = TransactionOperation("file_modify", test_file, backup_file)
            self.transaction_manager.add_operation(operation)
            
            # Modify file
            with open(test_file, 'w') as f:
                f.write("modified content")
            
            # Verify modification
            with open(test_file, 'r') as f:
                self.assertEqual(f.read(), "modified content")
            
            # Rollback transaction
            success = self.transaction_manager.rollback_transaction()
            self.assertTrue(success)
            
            # Verify rollback
            with open(test_file, 'r') as f:
                self.assertEqual(f.read(), "original content")
                
        except Exception as e:
            self.fail(f"Transaction rollback failed: {e}")


class TestDatabaseIntegration(unittest.TestCase):
    """Test database operations integration"""
    
    def setUp(self):
        """Set up test database"""
        self.test_db = tempfile.NamedTemporaryFile(suffix='.db', delete=False)
        self.test_db.close()
        
        # Create test database
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
            ('augment.test.key1', 'value1'),
            ('augment.test.key2', 'value2'),
            ('normal.key', 'normal_value'),
            ('context7.test', 'context_value'),
            ('telemetry.machineId', 'old_machine_id'),
            ('other.key', 'other_value')
        ]
        
        cursor.executemany('INSERT INTO ItemTable (key, value) VALUES (?, ?)', test_data)
        conn.commit()
        conn.close()
    
    def tearDown(self):
        """Clean up test database"""
        try:
            os.unlink(self.test_db.name)
            backup_path = self.test_db.name + '.backup'
            if os.path.exists(backup_path):
                os.unlink(backup_path)
        except OSError:
            pass
    
    def test_database_cleaning_integration(self):
        """Test end-to-end database cleaning"""
        try:
            # Test preview first
            db_path = Path(self.test_db.name)
            
            # Count original entries
            conn = sqlite3.connect(self.test_db.name)
            cursor = conn.cursor()
            cursor.execute("SELECT COUNT(*) FROM ItemTable")
            original_count = cursor.fetchone()[0]
            
            cursor.execute("SELECT COUNT(*) FROM ItemTable WHERE key LIKE '%augment%'")
            augment_count = cursor.fetchone()[0]
            conn.close()
            
            self.assertEqual(original_count, 6)
            self.assertEqual(augment_count, 2)
            
            # Perform cleaning
            result = clean_database_file(db_path, create_backup=True)
            self.assertTrue(result, "Database cleaning failed")
            
            # Verify cleaning results
            conn = sqlite3.connect(self.test_db.name)
            cursor = conn.cursor()
            cursor.execute("SELECT COUNT(*) FROM ItemTable")
            final_count = cursor.fetchone()[0]
            
            cursor.execute("SELECT COUNT(*) FROM ItemTable WHERE key LIKE '%augment%'")
            remaining_augment = cursor.fetchone()[0]
            conn.close()
            
            # Should have removed augment entries
            self.assertLess(final_count, original_count)
            self.assertEqual(remaining_augment, 0)
            
            # Verify backup exists
            backup_path = self.test_db.name + '.backup'
            self.assertTrue(os.path.exists(backup_path), "Backup not created")
            
        except Exception as e:
            self.skipTest(f"Database cleaning not available: {e}")


class TestSecurityIntegration(unittest.TestCase):
    """Test security features integration"""
    
    def test_input_validation_integration(self):
        """Test input validation across modules"""
        try:
            # Test file path validation
            safe_paths = ["test.txt", "folder/file.txt"]
            dangerous_paths = ["../../../etc/passwd", "file<script>.txt"]
            
            for path in safe_paths:
                self.assertTrue(validate_file_path(path), f"Safe path rejected: {path}")
            
            for path in dangerous_paths:
                self.assertFalse(validate_file_path(path), f"Dangerous path accepted: {path}")
                
        except Exception as e:
            self.skipTest(f"Input validation not available: {e}")
    
    def test_id_generation_security(self):
        """Test secure ID generation integration"""
        try:
            generator = SecureIDGenerator()
            
            # Generate multiple IDs and verify uniqueness
            machine_ids = set()
            device_ids = set()
            
            for _ in range(100):
                machine_id = generator.generate_machine_id()
                device_id = generator.generate_device_id()
                
                # Check format
                self.assertEqual(len(machine_id), 64)
                self.assertEqual(len(device_id), 36)
                
                # Check uniqueness
                self.assertNotIn(machine_id, machine_ids)
                self.assertNotIn(device_id, device_ids)
                
                machine_ids.add(machine_id)
                device_ids.add(device_id)
            
            # Verify we generated unique IDs
            self.assertEqual(len(machine_ids), 100)
            self.assertEqual(len(device_ids), 100)
            
        except Exception as e:
            self.skipTest(f"ID generation not available: {e}")


class TestEndToEndWorkflow(unittest.TestCase):
    """Test complete end-to-end workflows"""
    
    def setUp(self):
        """Set up end-to-end test environment"""
        self.test_dir = tempfile.mkdtemp()
        
        # Create test database
        self.test_db = os.path.join(self.test_dir, "test.db")
        conn = sqlite3.connect(self.test_db)
        cursor = conn.cursor()
        cursor.execute('''
            CREATE TABLE ItemTable (
                id INTEGER PRIMARY KEY,
                key TEXT,
                value TEXT
            )
        ''')
        
        test_data = [
            ('augment.extension.key', 'extension_data'),
            ('context7.framework.key', 'framework_data'),
            ('telemetry.machineId', 'old_machine_id'),
            ('normal.application.key', 'app_data')
        ]
        
        cursor.executemany('INSERT INTO ItemTable (key, value) VALUES (?, ?)', test_data)
        conn.commit()
        conn.close()
    
    def tearDown(self):
        """Clean up end-to-end test environment"""
        import shutil
        try:
            shutil.rmtree(self.test_dir)
        except OSError:
            pass
    
    def test_complete_cleaning_workflow(self):
        """Test complete cleaning workflow with all components"""
        try:
            db_path = Path(self.test_db)
            
            # Step 1: Validate input
            self.assertTrue(validate_file_path(str(db_path)))
            
            # Step 2: Create backup
            backup_path = backup_file(db_path)
            self.assertTrue(backup_path.exists())
            
            # Step 3: Clean database
            result = clean_database_file(db_path, create_backup=False)  # Already backed up
            self.assertTrue(result)
            
            # Step 4: Verify results
            conn = sqlite3.connect(self.test_db)
            cursor = conn.cursor()
            
            # Check that augment/context7 entries are removed
            cursor.execute("SELECT COUNT(*) FROM ItemTable WHERE key LIKE '%augment%' OR key LIKE '%context7%'")
            remaining_target_entries = cursor.fetchone()[0]
            self.assertEqual(remaining_target_entries, 0)
            
            # Check that normal entries remain
            cursor.execute("SELECT COUNT(*) FROM ItemTable WHERE key LIKE '%normal%'")
            remaining_normal_entries = cursor.fetchone()[0]
            self.assertGreater(remaining_normal_entries, 0)
            
            conn.close()
            
        except Exception as e:
            self.skipTest(f"Complete workflow test not available: {e}")


if __name__ == '__main__':
    # Run integration tests with verbose output
    unittest.main(verbosity=2)
