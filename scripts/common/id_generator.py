"""
Unified ID generation service for Augment VIP Cleaner
Provides secure, cryptographically random ID generation across platforms
"""

import uuid
import secrets
import hashlib
from datetime import datetime
from typing import Optional


class SecureIDGenerator:
    """Secure ID generator using cryptographically strong random sources"""
    
    @staticmethod
    def generate_uuid() -> str:
        """
        Generate a secure UUID v4
        
        Returns:
            UUID v4 string
        """
        return str(uuid.uuid4())
    
    @staticmethod
    def generate_hex_string(length: int = 64) -> str:
        """
        Generate a secure hexadecimal string
        
        Args:
            length: Length of the hex string (must be even)
            
        Returns:
            Secure hex string
        """
        if length % 2 != 0:
            raise ValueError("Length must be even for hex string generation")
        
        # Generate random bytes and convert to hex
        random_bytes = secrets.token_bytes(length // 2)
        return random_bytes.hex()
    
    @staticmethod
    def generate_machine_id() -> str:
        """
        Generate a 64-character machine ID
        
        Returns:
            64-character hex string
        """
        return SecureIDGenerator.generate_hex_string(64)
    
    @staticmethod
    def generate_device_id() -> str:
        """
        Generate a device ID (UUID v4)
        
        Returns:
            UUID v4 string
        """
        return SecureIDGenerator.generate_uuid()
    
    @staticmethod
    def generate_sqm_id() -> str:
        """
        Generate an SQM ID (UUID v4)
        
        Returns:
            UUID v4 string
        """
        return SecureIDGenerator.generate_uuid()
    
    @staticmethod
    def generate_session_id() -> str:
        """
        Generate a session ID (UUID v4)
        
        Returns:
            UUID v4 string
        """
        return SecureIDGenerator.generate_uuid()
    
    @staticmethod
    def generate_instance_id() -> str:
        """
        Generate an instance ID (UUID v4)
        
        Returns:
            UUID v4 string
        """
        return SecureIDGenerator.generate_uuid()
    
    @staticmethod
    def generate_timestamp() -> str:
        """
        Generate a timestamp in ISO format
        
        Returns:
            ISO format timestamp string
        """
        return datetime.utcnow().isoformat() + "Z"
    
    @staticmethod
    def generate_secure_filename(prefix: str = "file", extension: str = ".tmp") -> str:
        """
        Generate a secure filename with random component
        
        Args:
            prefix: Filename prefix
            extension: File extension
            
        Returns:
            Secure filename
        """
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        random_part = SecureIDGenerator.generate_hex_string(16)
        return f"{prefix}_{timestamp}_{random_part}{extension}"
    
    @staticmethod
    def generate_telemetry_id(id_type: str, length: Optional[int] = None) -> str:
        """
        Generate telemetry ID based on type
        
        Args:
            id_type: Type of ID to generate
            length: Length for hex string types
            
        Returns:
            Generated ID string
        """
        id_type = id_type.lower()
        
        if id_type in ['machineid', 'machine_id', 'telemetry.machineid']:
            return SecureIDGenerator.generate_machine_id()
        elif id_type in ['deviceid', 'device_id', 'devdeviceid', 'telemetry.devdeviceid']:
            return SecureIDGenerator.generate_device_id()
        elif id_type in ['sqmid', 'sqm_id', 'telemetry.sqmid']:
            return SecureIDGenerator.generate_sqm_id()
        elif id_type in ['sessionid', 'session_id', 'telemetry.sessionid']:
            return SecureIDGenerator.generate_session_id()
        elif id_type in ['instanceid', 'instance_id', 'telemetry.instanceid']:
            return SecureIDGenerator.generate_instance_id()
        elif id_type in ['timestamp', 'date', 'sessiondate', 'firstsessiondate', 'lastsessiondate']:
            return SecureIDGenerator.generate_timestamp()
        elif id_type == 'uuid':
            return SecureIDGenerator.generate_uuid()
        elif id_type == 'hex' and length:
            return SecureIDGenerator.generate_hex_string(length)
        else:
            raise ValueError(f"Unknown ID type: {id_type}")


# Global generator instance
_generator = SecureIDGenerator()


def generate_uuid() -> str:
    """Convenience function for UUID generation"""
    return _generator.generate_uuid()


def generate_hex_string(length: int = 64) -> str:
    """Convenience function for hex string generation"""
    return _generator.generate_hex_string(length)


def generate_machine_id() -> str:
    """Convenience function for machine ID generation"""
    return _generator.generate_machine_id()


def generate_device_id() -> str:
    """Convenience function for device ID generation"""
    return _generator.generate_device_id()


def generate_sqm_id() -> str:
    """Convenience function for SQM ID generation"""
    return _generator.generate_sqm_id()


def generate_session_id() -> str:
    """Convenience function for session ID generation"""
    return _generator.generate_session_id()


def generate_instance_id() -> str:
    """Convenience function for instance ID generation"""
    return _generator.generate_instance_id()


def generate_timestamp() -> str:
    """Convenience function for timestamp generation"""
    return _generator.generate_timestamp()


def generate_secure_filename(prefix: str = "file", extension: str = ".tmp") -> str:
    """Convenience function for secure filename generation"""
    return _generator.generate_secure_filename(prefix, extension)


def generate_telemetry_id(id_type: str, length: Optional[int] = None) -> str:
    """Convenience function for telemetry ID generation"""
    return _generator.generate_telemetry_id(id_type, length)


# Compatibility functions for existing code
def generate_machine_id_legacy() -> str:
    """Legacy compatibility function"""
    return generate_machine_id()


def generate_device_id_legacy() -> str:
    """Legacy compatibility function"""
    return generate_device_id()


def generate_sqm_id_legacy() -> str:
    """Legacy compatibility function"""
    return generate_sqm_id()


# Validation functions
def validate_uuid(uuid_string: str) -> bool:
    """
    Validate UUID format
    
    Args:
        uuid_string: UUID string to validate
        
    Returns:
        True if valid UUID, False otherwise
    """
    try:
        uuid.UUID(uuid_string)
        return True
    except ValueError:
        return False


def validate_hex_string(hex_string: str, expected_length: Optional[int] = None) -> bool:
    """
    Validate hex string format
    
    Args:
        hex_string: Hex string to validate
        expected_length: Expected length (optional)
        
    Returns:
        True if valid hex string, False otherwise
    """
    try:
        # Check if it's valid hex
        int(hex_string, 16)
        
        # Check length if specified
        if expected_length and len(hex_string) != expected_length:
            return False
        
        return True
    except ValueError:
        return False


def validate_machine_id(machine_id: str) -> bool:
    """
    Validate machine ID format (64-character hex)
    
    Args:
        machine_id: Machine ID to validate
        
    Returns:
        True if valid machine ID, False otherwise
    """
    return validate_hex_string(machine_id, 64)
