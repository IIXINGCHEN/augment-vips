"""
Transaction manager for Augment VIP Cleaner
Provides rollback capabilities and error recovery for database operations
"""

import os
import json
import shutil
from pathlib import Path
from typing import List, Dict, Any, Optional, Callable
from datetime import datetime
import sqlite3


class TransactionOperation:
    """Represents a single operation that can be rolled back"""
    
    def __init__(self, operation_type: str, target_path: str, backup_path: Optional[str] = None, 
                 metadata: Optional[Dict[str, Any]] = None):
        """
        Initialize transaction operation
        
        Args:
            operation_type: Type of operation (file_modify, file_delete, db_modify)
            target_path: Path to the target file/database
            backup_path: Path to backup file (if applicable)
            metadata: Additional operation metadata
        """
        self.operation_type = operation_type
        self.target_path = target_path
        self.backup_path = backup_path
        self.metadata = metadata or {}
        self.timestamp = datetime.utcnow().isoformat()
        self.completed = False
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert operation to dictionary for serialization"""
        return {
            "operation_type": self.operation_type,
            "target_path": self.target_path,
            "backup_path": self.backup_path,
            "metadata": self.metadata,
            "timestamp": self.timestamp,
            "completed": self.completed
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'TransactionOperation':
        """Create operation from dictionary"""
        op = cls(
            operation_type=data["operation_type"],
            target_path=data["target_path"],
            backup_path=data.get("backup_path"),
            metadata=data.get("metadata", {})
        )
        op.timestamp = data.get("timestamp", datetime.utcnow().isoformat())
        op.completed = data.get("completed", False)
        return op


class TransactionManager:
    """Manages transactions with rollback capabilities"""
    
    def __init__(self, transaction_log_dir: str = "./logs/transactions"):
        """
        Initialize transaction manager
        
        Args:
            transaction_log_dir: Directory to store transaction logs
        """
        self.transaction_log_dir = Path(transaction_log_dir)
        self.transaction_log_dir.mkdir(parents=True, exist_ok=True)
        self.current_transaction_id = None
        self.operations: List[TransactionOperation] = []
    
    def begin_transaction(self, transaction_id: Optional[str] = None) -> str:
        """
        Begin a new transaction
        
        Args:
            transaction_id: Optional transaction ID
            
        Returns:
            Transaction ID
        """
        if self.current_transaction_id:
            raise RuntimeError("Transaction already in progress")
        
        if not transaction_id:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
            transaction_id = f"tx_{timestamp}"
        
        self.current_transaction_id = transaction_id
        self.operations = []
        
        # Create transaction log file
        self._save_transaction_log()
        
        return transaction_id
    
    def add_operation(self, operation: TransactionOperation) -> None:
        """
        Add operation to current transaction
        
        Args:
            operation: Operation to add
        """
        if not self.current_transaction_id:
            raise RuntimeError("No transaction in progress")
        
        self.operations.append(operation)
        self._save_transaction_log()
    
    def commit_transaction(self) -> bool:
        """
        Commit current transaction
        
        Returns:
            True if successful, False otherwise
        """
        if not self.current_transaction_id:
            raise RuntimeError("No transaction in progress")
        
        try:
            # Mark all operations as completed
            for operation in self.operations:
                operation.completed = True
            
            self._save_transaction_log()
            
            # Clean up transaction log after successful commit
            log_file = self._get_transaction_log_path()
            if log_file.exists():
                log_file.unlink()
            
            self.current_transaction_id = None
            self.operations = []
            
            return True
        except Exception:
            return False
    
    def rollback_transaction(self) -> bool:
        """
        Rollback current transaction
        
        Returns:
            True if successful, False otherwise
        """
        if not self.current_transaction_id:
            raise RuntimeError("No transaction in progress")
        
        success = True
        
        # Rollback operations in reverse order
        for operation in reversed(self.operations):
            if not self._rollback_operation(operation):
                success = False
        
        # Clean up transaction log
        log_file = self._get_transaction_log_path()
        if log_file.exists():
            log_file.unlink()
        
        self.current_transaction_id = None
        self.operations = []
        
        return success
    
    def _rollback_operation(self, operation: TransactionOperation) -> bool:
        """
        Rollback a single operation
        
        Args:
            operation: Operation to rollback
            
        Returns:
            True if successful, False otherwise
        """
        try:
            if operation.operation_type == "file_modify" and operation.backup_path:
                # Restore from backup
                if Path(operation.backup_path).exists():
                    shutil.copy2(operation.backup_path, operation.target_path)
                    return True
            
            elif operation.operation_type == "file_delete" and operation.backup_path:
                # Restore deleted file
                if Path(operation.backup_path).exists():
                    shutil.copy2(operation.backup_path, operation.target_path)
                    return True
            
            elif operation.operation_type == "db_modify" and operation.backup_path:
                # Restore database from backup
                if Path(operation.backup_path).exists():
                    shutil.copy2(operation.backup_path, operation.target_path)
                    return True
            
            return False
        except Exception:
            return False
    
    def _save_transaction_log(self) -> None:
        """Save current transaction to log file"""
        if not self.current_transaction_id:
            return
        
        log_data = {
            "transaction_id": self.current_transaction_id,
            "start_time": datetime.utcnow().isoformat(),
            "operations": [op.to_dict() for op in self.operations]
        }
        
        log_file = self._get_transaction_log_path()
        with open(log_file, 'w', encoding='utf-8') as f:
            json.dump(log_data, f, indent=2)
    
    def _get_transaction_log_path(self) -> Path:
        """Get path to current transaction log file"""
        return self.transaction_log_dir / f"{self.current_transaction_id}.json"
    
    def recover_incomplete_transactions(self) -> List[str]:
        """
        Recover from incomplete transactions
        
        Returns:
            List of recovered transaction IDs
        """
        recovered = []
        
        for log_file in self.transaction_log_dir.glob("*.json"):
            try:
                with open(log_file, 'r', encoding='utf-8') as f:
                    log_data = json.load(f)
                
                transaction_id = log_data["transaction_id"]
                operations = [TransactionOperation.from_dict(op_data) 
                             for op_data in log_data["operations"]]
                
                # Check if any operations are incomplete
                incomplete_ops = [op for op in operations if not op.completed]
                
                if incomplete_ops:
                    # Rollback incomplete operations
                    for operation in reversed(incomplete_ops):
                        self._rollback_operation(operation)
                    
                    recovered.append(transaction_id)
                
                # Clean up log file
                log_file.unlink()
                
            except Exception:
                # If we can't process the log file, leave it for manual inspection
                continue
        
        return recovered


# Global transaction manager instance
_transaction_manager = None


def get_transaction_manager() -> TransactionManager:
    """
    Get global transaction manager instance
    
    Returns:
        TransactionManager instance
    """
    global _transaction_manager
    if _transaction_manager is None:
        _transaction_manager = TransactionManager()
    return _transaction_manager


def with_transaction(func: Callable) -> Callable:
    """
    Decorator to wrap function in transaction
    
    Args:
        func: Function to wrap
        
    Returns:
        Wrapped function
    """
    def wrapper(*args, **kwargs):
        tm = get_transaction_manager()
        transaction_id = tm.begin_transaction()
        
        try:
            result = func(*args, **kwargs)
            tm.commit_transaction()
            return result
        except Exception as e:
            tm.rollback_transaction()
            raise e
    
    return wrapper


def begin_transaction(transaction_id: Optional[str] = None) -> str:
    """Convenience function to begin transaction"""
    return get_transaction_manager().begin_transaction(transaction_id)


def add_file_operation(operation_type: str, target_path: str, 
                      backup_path: Optional[str] = None) -> None:
    """Convenience function to add file operation"""
    operation = TransactionOperation(operation_type, target_path, backup_path)
    get_transaction_manager().add_operation(operation)


def commit_transaction() -> bool:
    """Convenience function to commit transaction"""
    return get_transaction_manager().commit_transaction()


def rollback_transaction() -> bool:
    """Convenience function to rollback transaction"""
    return get_transaction_manager().rollback_transaction()


def recover_transactions() -> List[str]:
    """Convenience function to recover incomplete transactions"""
    return get_transaction_manager().recover_incomplete_transactions()
