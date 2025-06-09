#!/usr/bin/env python3
"""
Installation script for Augment VIP (Python cross-platform version)
Supports Windows, macOS, and Linux
"""

import os
import sys
import subprocess
import platform
import venv
from pathlib import Path


def print_colored(message, color_code=None):
    """Print colored message if terminal supports it"""
    if color_code and hasattr(sys.stdout, 'isatty') and sys.stdout.isatty():
        print(f"\033[{color_code}m{message}\033[0m")
    else:
        print(message)


def info(message):
    print_colored(f"[INFO] {message}", "34")  # Blue


def success(message):
    print_colored(f"[SUCCESS] {message}", "32")  # Green


def warning(message):
    print_colored(f"[WARNING] {message}", "33")  # Yellow


def error(message):
    print_colored(f"[ERROR] {message}", "31")  # Red


def check_python_version():
    """Check if Python version is 3.6 or higher"""
    if sys.version_info < (3, 6):
        error(f"Python 3.6 or higher is required. Current version: {sys.version}")
        return False
    
    success(f"Python version check passed: {sys.version}")
    return True


def create_virtual_environment(venv_path):
    """Create a virtual environment"""
    info(f"Creating virtual environment at: {venv_path}")
    
    try:
        venv.create(venv_path, with_pip=True)
        success("Virtual environment created successfully")
        return True
    except Exception as e:
        error(f"Failed to create virtual environment: {e}")
        return False


def get_venv_python(venv_path):
    """Get the path to the Python executable in the virtual environment"""
    system = platform.system()
    
    if system == "Windows":
        return venv_path / "Scripts" / "python.exe"
    else:
        return venv_path / "bin" / "python"


def get_venv_pip(venv_path):
    """Get the path to the pip executable in the virtual environment"""
    system = platform.system()
    
    if system == "Windows":
        return venv_path / "Scripts" / "pip.exe"
    else:
        return venv_path / "bin" / "pip"


def install_dependencies(venv_path):
    """Install required dependencies in the virtual environment"""
    info("Installing dependencies...")
    
    pip_path = get_venv_pip(venv_path)
    
    # Required packages
    packages = [
        "colorama>=0.4.4",
        "psutil>=5.8.0"
    ]
    
    try:
        for package in packages:
            info(f"Installing {package}...")
            result = subprocess.run(
                [str(pip_path), "install", package],
                capture_output=True,
                text=True,
                check=True
            )
            
        success("All dependencies installed successfully")
        return True
        
    except subprocess.CalledProcessError as e:
        error(f"Failed to install dependencies: {e}")
        error(f"stdout: {e.stdout}")
        error(f"stderr: {e.stderr}")
        return False


def install_package(venv_path, package_path):
    """Install the augment_vip package in development mode"""
    info("Installing Augment VIP package...")
    
    pip_path = get_venv_pip(venv_path)
    
    try:
        # Install in development mode
        result = subprocess.run(
            [str(pip_path), "install", "-e", str(package_path)],
            capture_output=True,
            text=True,
            check=True
        )
        
        success("Augment VIP package installed successfully")
        return True
        
    except subprocess.CalledProcessError as e:
        error(f"Failed to install package: {e}")
        error(f"stdout: {e.stdout}")
        error(f"stderr: {e.stderr}")
        return False


def create_setup_py(package_path):
    """Create setup.py file for the package"""
    setup_content = '''#!/usr/bin/env python3
"""
Setup script for Augment VIP
"""

from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="augment-vip",
    version="1.0.0",
    author="Augment VIP Project",
    description="Cross-platform VS Code cleanup utility for Augment VIP users",
    long_description=long_description,
    long_description_content_type="text/markdown",
    packages=find_packages(),
    classifiers=[
        "Development Status :: 5 - Production/Stable",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.6",
        "Programming Language :: Python :: 3.7",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
    ],
    python_requires=">=3.6",
    install_requires=[
        "colorama>=0.4.4",
        "psutil>=5.8.0",
    ],
    entry_points={
        "console_scripts": [
            "augment-vip=augment_vip.cli:main",
        ],
    },
)
'''
    
    setup_path = package_path / "setup.py"
    with open(setup_path, 'w', encoding='utf-8') as f:
        f.write(setup_content)
    
    success(f"Created setup.py at: {setup_path}")


def create_readme(package_path):
    """Create README.md file"""
    readme_content = '''# Augment VIP - Cross-Platform Edition

A professional cross-platform toolkit for Augment VIP users, providing tools to manage and clean VS Code databases.

## Features

- **Database Cleaning**: Remove Augment-related entries from VS Code databases
- **Telemetry ID Modification**: Generate random telemetry IDs for VS Code
- **Cross-Platform Support**: Works on Windows, macOS, and Linux
- **Safe Operations**: Creates backups before making any changes

## Usage

```bash
# Clean VS Code databases
augment-vip clean

# Modify telemetry IDs
augment-vip modify-ids

# Run all operations
augment-vip all

# Preview operations without changes
augment-vip preview
```

## System Requirements

- Python 3.6 or higher
- VS Code installed on the system

## Installation

This package is installed automatically by the Augment VIP installation script.
'''
    
    readme_path = package_path / "README.md"
    with open(readme_path, 'w', encoding='utf-8') as f:
        f.write(readme_content)
    
    success(f"Created README.md at: {readme_path}")


def main():
    """Main installation function"""
    info("Starting Augment VIP installation (Python cross-platform version)")

    # Check Python version
    if not check_python_version():
        sys.exit(1)

    # Get current directory
    current_dir = Path.cwd()
    package_path = current_dir
    venv_path = current_dir / ".venv"

    info(f"Installation directory: {current_dir}")
    info(f"Detected system: {platform.system()}")

    # Create virtual environment
    if not create_virtual_environment(venv_path):
        sys.exit(1)

    # Install dependencies
    if not install_dependencies(venv_path):
        sys.exit(1)

    # Create setup.py and README.md
    create_setup_py(package_path)
    create_readme(package_path)

    # Install the package
    if not install_package(venv_path, package_path):
        sys.exit(1)

    # Show usage information
    system = platform.system()
    if system == "Windows":
        executable_path = venv_path / "Scripts" / "augment-vip.exe"
    else:
        executable_path = venv_path / "bin" / "augment-vip"

    success("Installation completed successfully!")
    info("\nYou can now use Augment VIP with the following commands:")
    info(f"  {executable_path} clean        # Clean VS Code databases")
    info(f"  {executable_path} modify-ids   # Modify telemetry IDs")
    info(f"  {executable_path} all          # Run all operations")
    info(f"  {executable_path} preview      # Preview operations")

    # Make executable on Unix systems
    if system != "Windows":
        try:
            os.chmod(executable_path, 0o755)
            info(f"Made {executable_path} executable")
        except Exception as e:
            warning(f"Could not make executable: {e}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
