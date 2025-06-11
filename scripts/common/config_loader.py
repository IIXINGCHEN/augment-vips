"""
Unified configuration loader for Augment VIP Cleaner
Provides centralized configuration management across platforms
"""

import json
import os
from pathlib import Path
from typing import Dict, Any, List, Optional
import jsonschema
from jsonschema import validate, ValidationError


class ConfigLoader:
    """Centralized configuration management"""
    
    def __init__(self, config_path: Optional[str] = None):
        """
        Initialize configuration loader
        
        Args:
            config_path: Optional path to config file
        """
        self._config = None
        self._config_path = config_path or self._find_config_file()
        self._schema = self._load_schema()
    
    def _find_config_file(self) -> str:
        """Find the configuration file"""
        # Look for config in common locations
        possible_paths = [
            "config/config.json",
            "../config/config.json",
            "../../config/config.json",
            os.path.join(os.path.dirname(__file__), "../../config/config.json")
        ]
        
        for path in possible_paths:
            if os.path.exists(path):
                return path
        
        raise FileNotFoundError("Configuration file not found")
    
    def _load_schema(self) -> Dict[str, Any]:
        """Load JSON schema for validation"""
        schema = {
            "type": "object",
            "properties": {
                "version": {"type": "string"},
                "environment": {"type": "string"},
                "cleaning": {
                    "type": "object",
                    "properties": {
                        "patterns": {
                            "type": "object",
                            "properties": {
                                "augment": {"type": "array", "items": {"type": "string"}},
                                "telemetry": {"type": "array", "items": {"type": "string"}},
                                "extensions": {"type": "array", "items": {"type": "string"}},
                                "custom": {"type": "array", "items": {"type": "string"}}
                            },
                            "required": ["augment", "telemetry", "extensions", "custom"]
                        },
                        "enableDatabaseCleaning": {"type": "boolean"},
                        "enableTelemetryModification": {"type": "boolean"},
                        "checkVSCodeRunning": {"type": "boolean"}
                    },
                    "required": ["patterns"]
                },
                "security": {
                    "type": "object",
                    "properties": {
                        "enableSQLInjectionProtection": {"type": "boolean"},
                        "enableSecureFileHandling": {"type": "boolean"}
                    }
                }
            },
            "required": ["version", "cleaning", "security"]
        }
        return schema
    
    def load_config(self) -> Dict[str, Any]:
        """
        Load and validate configuration
        
        Returns:
            Configuration dictionary
        """
        if self._config is None:
            try:
                with open(self._config_path, 'r', encoding='utf-8') as f:
                    self._config = json.load(f)
                
                # Validate configuration
                validate(instance=self._config, schema=self._schema)
                
            except FileNotFoundError:
                raise FileNotFoundError(f"Configuration file not found: {self._config_path}")
            except json.JSONDecodeError as e:
                raise ValueError(f"Invalid JSON in configuration file: {e}")
            except ValidationError as e:
                raise ValueError(f"Configuration validation failed: {e.message}")
        
        return self._config
    
    def get_cleaning_patterns(self, pattern_type: str) -> List[str]:
        """
        Get cleaning patterns by type
        
        Args:
            pattern_type: Type of patterns (augment, telemetry, extensions, custom)
            
        Returns:
            List of patterns
        """
        config = self.load_config()
        patterns = config.get("cleaning", {}).get("patterns", {})
        return patterns.get(pattern_type, [])
    
    def get_all_cleaning_patterns(self) -> List[str]:
        """
        Get all cleaning patterns combined
        
        Returns:
            List of all patterns
        """
        all_patterns = []
        for pattern_type in ["augment", "telemetry", "extensions", "custom"]:
            all_patterns.extend(self.get_cleaning_patterns(pattern_type))
        return all_patterns
    
    def get_security_settings(self) -> Dict[str, Any]:
        """
        Get security configuration
        
        Returns:
            Security settings dictionary
        """
        config = self.load_config()
        return config.get("security", {})
    
    def is_feature_enabled(self, feature: str) -> bool:
        """
        Check if a feature is enabled
        
        Args:
            feature: Feature name
            
        Returns:
            True if enabled, False otherwise
        """
        config = self.load_config()
        
        # Check in cleaning section
        cleaning = config.get("cleaning", {})
        if feature in cleaning:
            return cleaning[feature]
        
        # Check in security section
        security = config.get("security", {})
        if feature in security:
            return security[feature]
        
        # Check in features section
        features = config.get("features", {})
        if feature in features:
            return features[feature]
        
        return False
    
    def get_telemetry_id_types(self) -> List[str]:
        """
        Get telemetry ID types to modify
        
        Returns:
            List of telemetry ID types
        """
        config = self.load_config()
        telemetry = config.get("telemetry", {})
        return telemetry.get("idTypes", [])
    
    def get_backup_settings(self) -> Dict[str, Any]:
        """
        Get backup configuration
        
        Returns:
            Backup settings dictionary
        """
        config = self.load_config()
        return config.get("backup", {})


# Global configuration instance
_config_loader = None


def get_config_loader() -> ConfigLoader:
    """
    Get global configuration loader instance
    
    Returns:
        ConfigLoader instance
    """
    global _config_loader
    if _config_loader is None:
        _config_loader = ConfigLoader()
    return _config_loader


def get_cleaning_patterns(pattern_type: str) -> List[str]:
    """
    Convenience function to get cleaning patterns
    
    Args:
        pattern_type: Type of patterns
        
    Returns:
        List of patterns
    """
    return get_config_loader().get_cleaning_patterns(pattern_type)


def get_all_cleaning_patterns() -> List[str]:
    """
    Convenience function to get all cleaning patterns
    
    Returns:
        List of all patterns
    """
    return get_config_loader().get_all_cleaning_patterns()


def is_security_feature_enabled(feature: str) -> bool:
    """
    Convenience function to check security features
    
    Args:
        feature: Security feature name
        
    Returns:
        True if enabled, False otherwise
    """
    return get_config_loader().is_feature_enabled(feature)
