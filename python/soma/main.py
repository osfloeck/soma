'''
main.py

Implementation of functions used in cli.py

Author: Oskar Floeck
Date: 11-09-2025
License: MIT
'''

import markdown
import time
import http.server
import yaml
import shutil
import importlib.resources as resources
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
from typing import Any, TypedDict, List
from enum import Enum, auto
from pathlib import Path
from jinja2 import Environment, FileSystemLoader
from datetime import datetime
from .templates import DEFAULT_TEMPLATES
from .seed import DEFAULT_CONTENT
from .assets import DEFAULT_ASSETS
from .build_utils import generate_build_hash, save_build_info, load_build_info, INJECT_SCRIPT

class ProcessMode(Enum):
    ROOT_PAGE = auto()
    CAT_PAGE = auto()
    CAT_INDEX = auto()

def init(name: str):
    """Initialise project structure"""
    site_path = Path(name)
    if site_path.exists():
        print(f"Error: Directory `{name}` already exists!")
        return

    # Create site structure
    site_path.mkdir()
    (site_path / "templates").mkdir()
    (site_path / "build").mkdir()
    (site_path / "assets").mkdir()
    (site_path / "assets" / "css").mkdir()
    (site_path / "assets" / "fonts").mkdir()  
    
    # Content directories
    (site_path / "blog").mkdir()
    (site_path / "projects").mkdir()
    
    # Init defaults
    create_default_templates(site_path / "templates")
    create_default_content(site_path)
    create_default_assets(site_path / "assets")
    copy_default_fonts(site_path / "assets" / "fonts")
    
    print(f"New soma instance `{name}` created!")
    print(f"Run `soma --help` to get started")
    
def create_default_templates(templates_dir: Path):
    """Create default HTML templates"""
    for template, content in DEFAULT_TEMPLATES.items():
        with open(templates_dir / template, 'w') as f:
            f.write(content)

def create_default_content(site_path: Path):
    """Create default markdown content"""
    for file_path, content in DEFAULT_CONTENT.items():
        with open(site_path / file_path, 'w') as f:
            f.write(content)

def create_default_assets(asset_path: Path):
    """Create default assets"""
    for file_path, content in DEFAULT_ASSETS.items():
        with open(asset_path / file_path, 'w') as f:
            f.write(content)
    
def copy_default_fonts(font_path: Path):
    """Copy default fonts from package"""
    try:
        with resources.as_file(resources.files('soma.fonts')) as font_dir:
            for font in font_dir.iterdir():
                if font.is_file():
                    shutil.copy(font, font_path / font.name)
    except Exception as e:
        print(f"soma (error: {e}")

def build(dev_mode: bool = False):
    """Build site"""    
    # Clear build contents
    if Path("build").exists():
        shutil.rmtree(Path("build"))
        Path("build").mkdir()
    
    # Generate build hash
    build_hash = generate_build_hash()
    save_build_info(Path("build"), build_hash)
    
    # Copy over assets to build
    build_assets()
    
    env = Environment(loader=FileSystemLoader('templates'))
    
    # Provides a function for templates to format dates
    def format_date(date_obj: datetime):
        """Format datetime e.g. '21st January, 2025'"""
        weekday = date_obj.strftime('%A')
        day = date_obj.day
        suffix = 'th' if 11 <= day <= 13 else {1: 'st', 2: 'nd', 3: 'rd'}.get(day % 10, 'th')
        month = date_obj.strftime('%B')
        year = date_obj.year
        return f"{weekday}, {day}{suffix} {month}, {year}"
    
    env.filters['format_date'] = format_date
    
    # Process items at root (e.g., index.md, about.md)
    for item in discover_root_items():
        build_page(env, item, ProcessMode.ROOT_PAGE, dev_mode, build_hash)
    
    # Process content in category
    for category_dir in discover_content():
        process_category_dir(env, category_dir, dev_mode, build_hash)
    
def build_assets():
    """Copy over assets from site to build"""
    assets_dir: Path = Path("assets")
    assets_build_dir: Path = Path("build") / "assets"
    
    if not assets_dir.exists():
        print("soma (error): No assets found in site!")
        return
    shutil.copytree(assets_dir, assets_build_dir)
    
def discover_content() -> list[Path]:
    """Discover directories (categories) that might contain content"""
    exclude = ['templates', 'build', 'assets']
    content_dirs: list[Path] = []
    
    # Any folders found that contain index.md is a category
    for directory in Path(".").iterdir(): 
        if not directory.is_dir():
            continue
        if directory.name.startswith("."):
            continue
        if directory.name in exclude:
            continue
        
        has_index_file = (directory / 'index.md').is_file()
        
        if has_index_file:
            content_dirs.append(directory)
            print(f"soma (info): {directory.name} OK")
        else:
            print(f"soma (warn): `index.md` not present in {directory.name}!")  
        
    return content_dirs

def discover_root_items() -> list[Path]:
    """Discover markdown content in root"""
    root_items: list[Path] = []
    
     # Check for index.md in root
    root_path = Path("index.md")
    if not root_path.exists():
        print("soma (error): No index.md found in root directory!")
    
    # Other items in root
    root_path = Path(".")
    for item in root_path.glob("*.md"):
        root_items.append(item)
    
    return root_items

def process_category_dir(env: Environment, category_dir: Path, dev_mode: bool = False, build_hash: str = ""):
    """Process markdown pages in a category dir"""
    for md_file in category_dir.glob("*.md"):

        if md_file.name.startswith("_"):
            continue

        mode = ProcessMode.CAT_PAGE
        if md_file.name == "index.md":
            mode = ProcessMode.CAT_INDEX

        build_page(env, md_file, mode, dev_mode, build_hash)

    
def build_page(env: Environment, md_file_path: Path, process_mode: ProcessMode, dev_mode: bool = False, build_hash: str = ""):
    """Process a single markdown page"""
    
    if md_file_path.name.startswith(("_", ".")):
        print(f"soma (info): Skipping draft/hidden {md_file_path}")
        return
    
    try:
        # Parse frontmatter & content
        context: dict[str, Any] = parse_md(md_file_path)
                
        # Add build timestamp to page
        extras: dict[str, Any] = {
            'build_hash': build_hash,
            'dev_mode': dev_mode,
            }
        
        # Inject build hash into each page in dev mode
        if dev_mode:
            extras['inject_script'] = INJECT_SCRIPT

        # Extract template from file
        template_name = str(context.get('template')) + ".html"
        if template_name is None:
            raise ValueError(f"Error: Unable to extract template for {md_file_path}!")
        
        # Category index page
        # If we are a category index (e.g. Blog index page), we need to collect all
        # relevant blog posts (i.e. items) for that category
        if process_mode == ProcessMode.CAT_INDEX:
            extras['items'] = collect_items(md_file_path.parent, md_file_path.parent.name)
        
        # Render with template
        template = env.get_template(template_name)
        html_content = template.render(**context, **extras)

        # Build path
        md_file_path = md_file_path.with_suffix('.html')
        if str(md_file_path.name) == "index.html":
            build_path: Path = Path("build") / md_file_path
        else:
            build_path: Path = Path("build") / md_file_path.parent / md_file_path.stem / "index.html"  

        # Create directory
        build_dir = build_path.parent
        build_dir.mkdir(parents=True, exist_ok=True)
        
        # Write file
        with open(build_path, 'w') as f:
            f.write(html_content)
                    
    except Exception as e:
        print(f"Error building {md_file_path}: {e}")

def collect_items(content_dir: Path, category_name: str) -> List[dict]:
    """Collects items found in a category directory"""
    items = []
    
    for md_file in content_dir.glob("*.md"):
        if md_file.name == "index.md":
            continue

        # Don't collect drafts
        if md_file.name.startswith(("_", ".")):
            continue
        
        try:
            item_data = parse_md(md_file)
            item_url = f"/{category_name}/{md_file.stem}"
            
            # Add item url for templates
            item: dict[str, Any] = {
                **item_data,  
                'url': item_url,
            }
            
            items.append(item)
            
        except Exception as e:
            print(f"Warning: Could not collect {md_file}: {e}")
            
    items.sort(key = lambda item: item['date'], reverse=True)    
    return items

def parse_md(file_path: Path) -> dict[str, Any]:
    """Parse markdown file with YAML frontmatter"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    if not content.startswith('---'):
        raise ValueError(f"Missing frontmatter in {file_path}")
    
    req_frontmatter_fields = ['title', 'template']
    frontmatter = {}
    
    # Break up md file (parts -> ['', 'frontmatter', 'content'])
    parts = content.split('---', 2)
    if len(parts) < 3:
        raise ValueError(f"Incomplete frontmatter in {file_path}")
    
    # Frontmatter processing
    try:
        frontmatter = yaml.safe_load(parts[1]) or {}
    except yaml.YAMLError as e:
        raise ValueError(f"Invalid YAML frontmatter in {file_path}: {e}")

    for field in req_frontmatter_fields:
        if field not in frontmatter:
            raise ValueError(f"Missing required frontmatter field `{field}` in {file_path}")
    
    # If we have a date, convert from str to datetime
    if 'date' in frontmatter and isinstance(frontmatter['date'], str):
        try:
            frontmatter['date'] = datetime.fromisoformat(frontmatter['date'])
        except ValueError as e:
            raise ValueError(f"soma (err): Invalid date format in {file_path}: {e}")
    
    # Content processing
    html_content = markdown.markdown(
        parts[2], 
        extensions=[
            'fenced_code',
            'codehilite',
            'tables',
            'smarty'
        ], 
        extension_configs={ 
            'codehilite': {
                'linenums': True,
                'use_pygments': True
            }
        }
    )
    
    # Prepare return
    page: dict[str, Any] = {
        **frontmatter,
        'content': html_content
    }
  
    return page
    
def serve(port, dev):
    """Serve the static site"""
    build_dir = Path("build")
    
    # Check build exists
    if not build_dir.exists():
        print("soma (error): Build directory not found! Run build first")
        return
    
    # Load and display current build info
    build_info = load_build_info(build_dir)
    print(f"soma (info): Build hash: {build_info.get('hash', 'unknown')}")
    print(f"soma (info): Build time: {build_info.get('timestamp', 'unknown')}")
    
    # If dev, build with dev_mode for script injection
    if dev:
        build(dev_mode = True)
    
    # Handler for our HTTP server
    class HTTPHandler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=str(build_dir), **kwargs)
    
        # Silent logs for retrieving build info
        def log_message(self, format, *args):
            if hasattr(self, 'path') and '.build-info.json' in self.path:
                return
            super().log_message(format, *args)
    
        # Disable caching in dev
        def end_headers(self):
            if dev:
                self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate')
                self.send_header('Expires', '0')
            super().end_headers()
        
    # Handler for watchdog
    class WatchdogHandler(FileSystemEventHandler):
        def __init__(self):
            self.last_build = 0
        
        def on_any_event(self, event):
            if event.is_directory:
                return
            
            path = Path(str(event.src_path))
            
            # Ignore paths & file suffix requirements
            if 'build' in path.parts or path.name.startswith('.'):
                return
            
            if not (path.suffix in ['.md', '.html', '.css']):
                return
            
            if event.event_type in ['modified', 'created', 'deleted']:
                current_time = time.time()
                
                # Debounce 1s
                if current_time - self.last_build > 1:
                    print(f"soma (info): Change detected: {path}")
                    print(f"Rebuilding...")
                    build(dev_mode = True)
                    self.last_build = current_time
                else:
                    print("Too fast! Debounced")
    
    if dev:
        observer = Observer()
        observer.schedule(WatchdogHandler(), ".", recursive=True)
        observer.start()
        print("Watch mode enabled - auto-rebuilding on changes")
        
    try:
        with http.server.ThreadingHTTPServer(("127.0.0.1", port), HTTPHandler) as server:
            print(f"Serving at http://localhost:{port}")
            server.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped")
    except OSError as e:
        print(f"Port {port} busy: {e}")

def clean():
    print("Cleaning build directory...")
