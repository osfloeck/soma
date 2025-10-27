'''
main.py

Implementation of functions used in cli.py

Author: Oskar Floeck
Date: 11-09-2025
License: MIT
'''

import markdown
import http.server
import socketserver
import os
import yaml
import shutil
import importlib.resources as resources
from halo import Halo
from typing import TypedDict, List, Required, NotRequired, Union
from enum import Enum
from pathlib import Path
from jinja2 import Environment, FileSystemLoader
from datetime import datetime
from dateutil.parser import parse as parse_date
from .templates import DEFAULT_TEMPLATES
from .seed import DEFAULT_CONTENT
from .assets import DEFAULT_ASSETS

class ProcessMode(Enum):
    ROOT_PAGE = 0
    CAT_PAGE = 1
    CAT_INDEX = 2

class MarkdownPageBase(TypedDict):
    title: str
    template: str
    content: str

class ContentPage(MarkdownPageBase):
    date: Required[datetime]
    tags: NotRequired[List[str]]
    categories: NotRequired[List[str]]

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
        full_path = site_path / file_path
        with open(full_path, 'w') as f:
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

def build():
    """Build site"""
    # Clear build contents
    if Path("build").exists():
        shutil.rmtree(Path("build"))
        Path("build").mkdir()
    
    # Copy over assets to build
    build_assets()
    
    env = Environment(loader=FileSystemLoader('templates'))
    
    def format_date(date_obj):
        """Format datetime e.g. 'Saturday, 19th Oct, 2025'"""
        day = date_obj.day
        suffix = 'th' if 11 <= day <= 13 else {1: 'st', 2: 'nd', 3: 'rd'}.get(day % 10, 'th')
        return date_obj.strftime(f"%A, {day}{suffix} %b, %Y")
    
    env.filters['format_date'] = format_date
    
    # Process items at root (e.g., index.md, about.md)
    root_items = discover_root_items()
    for item in root_items:
        render_page(env, item, ProcessMode.ROOT_PAGE)
    
    # Process content in category
    category_dirs = discover_content()
    for category_dir in category_dirs:
        process_category_dir(env, category_dir)

def build_assets():
    """Copy over assets from site to build"""
    assets_dir: Path = Path("assets")
    assets_build_dir: Path = Path("build") / "assets"
    
    if not assets_dir.exists():
        print("soma (error): No assets found in site!")
        return
    shutil.copytree(assets_dir, assets_build_dir)
    print(f"soma (info): Copied assets to build")
    
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

def process_category_dir(env: Environment, category_dir: Path):
    """Process markdown pages in a category dir"""
    for md_file in category_dir.glob("*.md"):
        if md_file.name == "index.md":
            render_page(env, md_file, ProcessMode.CAT_INDEX)
        else:
            render_page(env, md_file, ProcessMode.CAT_PAGE)
    
def render_page(env: Environment, md_file_path: Path, mode: ProcessMode):
    """Process a single markdown page"""
    
    if md_file_path.name.startswith(("_", ".")):
        print(f"soma (info): Skipping draft/hidden {md_file_path}")
        return
    
    try:
        # Parse frontmatter & content
        context: Union[ContentPage, MarkdownPageBase]    
        extras = {}

        if mode == ProcessMode.CAT_PAGE:
            context = parse_md(md_file_path, mode)
        else:
            context = parse_md(md_file_path, mode)
        
        template_name = str(context.get('template')) + ".html"
        if template_name is None:
            raise ValueError(f"Error: Unable to extract template for {md_file_path}!")
        
        # Category index page
        if mode == ProcessMode.CAT_INDEX:
            content_dir = md_file_path.parent
            items = collect_items(content_dir, md_file_path.parent.name)
            extras['items'] = items
        
        # Content item page
        if mode == ProcessMode.CAT_PAGE:
            extras['category_name'] = md_file_path.parent.name
        
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
        
        print(f"  → Built: {build_path}")
        
    except Exception as e:
        print(f"Error processing {md_file_path}: {e}")

def collect_items(content_dir: Path, category_name: str) -> List[ContentPage]:
    """Collects items found in a category directory"""
    items = []
    
    for md_file in content_dir.glob("*.md"):
        if md_file.name == "index.md":
            continue
        
        try:
            item_data = parse_md(md_file, ProcessMode.CAT_PAGE)
            if 'date' not in item_data:
                raise ValueError(f"soma (err): Expected date field in {md_file}")
            item_url = f"/{category_name}/{md_file.stem}"
            items.append({
                'title': item_data['title'],
                'url': item_url,
                'date': item_data['date'].strftime((f"%d/%m/%Y"))
            })
        except Exception as e:
            print(f"Warning: Could not collect {md_file}: {e}")
            
    items.sort(key = lambda item: item['date'], reverse=True)    
    return items

def parse_md(file_path: Path, mode: ProcessMode) -> Union[MarkdownPageBase, ContentPage]:
    """Parse markdowd file with YAML frontmatter"""
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
    
    # Content processing
    html_content = markdown.markdown(parts[2], extensions=[
        'fenced_code',
        'codehilite',
        'tables'  
    ])
    
    # Prepare return
    if mode == ProcessMode.CAT_PAGE: 
        cat_page: ContentPage = {
            'title': frontmatter['title'],
            'template': frontmatter['template'],
            'content': html_content,
            'date': parse_date(frontmatter['date'])
        }
        if 'tags' in frontmatter:
            cat_page['tags'] = frontmatter['tags']
        if 'categories' in frontmatter:
            cat_page['categories'] = frontmatter['categories']        
        return cat_page
    else:
        page: MarkdownPageBase = {
                'title': frontmatter['title'],
                'template': frontmatter['template'],
                'content': html_content
            }
        return page
    
def serve(port, dev):
    """Serve the static site"""
    
    build_dir = Path("build")
    
    # Check if build exists
    if not build_dir.exists():
        print("Error: build/ directory doesn't exist!")
        print("Run `soma build` first to generate the site.")
        return
    
    # Change to build directory for server
    original_dir = os.getcwd()
    os.chdir(build_dir)
    
    # Set up HTTP server
    Handler = http.server.SimpleHTTPRequestHandler
    httpd = None
    
    try:
        with socketserver.TCPServer(("", port), Handler) as httpd:
            print(f"✓ Serving site at http://localhost:{port}")
            print("Press Ctrl+C to stop the server")
            httpd.serve_forever()
    except OSError as e:
        if e.errno == 48 or e.errno == 98:  # Address already in use
            print(f"Error: Port {port} is already in use!")
            print("Try a different port with --port <number>")
        else:
            print(f"Error starting server: {e}")
    except KeyboardInterrupt:
        print("\n✓ Server stopped")
    finally:
        # Ensure server is properly shut down
        if httpd:
            httpd.shutdown()
            httpd.server_close()
        os.chdir(original_dir)
        print(f"✓ Port {port} freed, back in {original_dir}")

def clean():
    print("Cleaning build directory...")
