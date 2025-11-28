'''
build_utils.py

Provides tools related to build state

Author: Oskar Floeck
Date: 27-11-2025
License: MIT
'''

from datetime import datetime
import json
from pathlib import Path
import secrets

# Simple polling script we inject into page
INJECT_SCRIPT = '''
    const currentHash = document.querySelector('meta[name="build-hash"]').content;
    setInterval(async () => {
        const response = await fetch('/.build-info.json');
        const buildInfo = await response.json();
        
        if (buildInfo.hash !== currentHash) {
            location.reload();
        }
    }, 1000);
'''

def generate_build_hash() -> str:
    """Generate hash"""
    return secrets.token_hex(6)

def save_build_info(build_dir: Path, file_hash: str) -> None:
    """Saves build info to the buld directory for livereload"""
    build_info = {
        "hash": file_hash,
        "timestamp": datetime.now().isoformat()
    }
    
    build_info_path = Path(build_dir) / ".build-info.json"
    with open(build_info_path, 'w') as f:
        json.dump(build_info, f)

def load_build_info(build_dir: Path) -> dict:
    """Loads build info from .build-info.json"""
    build_info = Path(build_dir) / ".build-info.json"
    
    try:
      with open(build_info, 'r') as f:
        return json.load(f)
    except FileNotFoundError as e:
        print(f"soma (error): {e}")
        return {}
    