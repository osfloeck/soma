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
from typing import TypedDict, List
from pathlib import Path
from jinja2 import Environment, FileSystemLoader
from datetime import datetime
from dateutil.parser import parse as parse_date
from .templates import DEFAULT_TEMPLATES
from .content import DEFAULT_CONTENT

class MarkdownPage(TypedDict, total=False):
    """Define return type in parse_md"""
    title: str              # required
    template: str           # required
    date: datetime          # optional
    content: str            # required
    tags: List[str]         # optional
    categories: List[str]   # optional
    items: List[dict]       # optional (just category index pages) 

def init(name):
    """Initialise project structure."""
    
    # Check if dir exists
    site_path = Path(name)
    if site_path.exists():
        print(f"Error: Directory `{name}` already exists!")
        return

    # Create directory structure
    site_path.mkdir()

    # Essential directories
    (site_path / "templates").mkdir()
    (site_path / "build").mkdir()    
    
    # Non-Essential (Dummy) directories
    (site_path / "blog").mkdir()
    (site_path / "blog" / "content").mkdir()
    (site_path / "projects").mkdir()
    (site_path / "projects" / "content").mkdir()
    
    # Init default templates
    print("soma: Init default templates..")
    create_default_templates(site_path / "templates")
    
    # Init dummy content
    print("soma: Init dummy content..")
    create_default_content(site_path)
    
    print(f"New soma instance `{name}` created!")
    print(f"Run `soma --help` to get started")
    # Remember to CD into new project
    
def create_default_templates(templates_dir: Path):
    """Create default HTML templates"""
    for filename, content in DEFAULT_TEMPLATES.items():
        with open(templates_dir / filename, 'w') as f:
            f.write(content)

def create_default_content(site_path: Path):
    """Create default markdown content"""
    for file_path, content in DEFAULT_CONTENT.items():
        full_path = site_path / file_path
        with open(full_path, 'w') as f:
            f.write(content)

def build():
    print("soma (debug): Building site...")
    
    # Clear build contents
    if Path("build").exists():
        shutil.rmtree(Path("build"))
        Path("build").mkdir()
    
    env = Environment(loader=FileSystemLoader('templates'))
    
    # Check for index.md (home page) in root dir 
    root_path = Path("index.md")
    if not root_path.exists():
        print("Error: No index.md found in root directory!")
        print("To fix, please ensure index.md exists in root directory.")
        return
    
    # Process home
    process_page(env, root_path)
    
    # Discover content directories
    content_dirs = discover_content()
    
    # Process content
    for content_dir in content_dirs:
        process_content_dir(env, content_dir)

def discover_content() -> list[Path]:
    """Discover all directories that might contain content"""
    exclude = ['templates', 'build']
    content_dirs: list[Path] = []
    
    # Any folders found (that contain a content dir & an index.md) is a category
    p = Path('.')
    for directory in p.iterdir(): 
        if directory.is_dir() and directory.name not in exclude:
            has_content = (directory / 'content').is_dir()
            has_index = (directory / 'index.md').is_file()
            
            if not (has_content and has_index):
                print(f"soma (debug): Either content or index.md not present in {directory.name}!")
            else:
                content_dirs.append(directory)
                print(f"soma (debug): {directory.name} OK")  
    
    return content_dirs

def process_content_dir(env: Environment, content_dir: Path):
    """Process multiple markdown pages in a single dir"""
    
    for md_file in content_dir.glob("**/*.md"):
        
        # Skip drafts (e.g. _new-post.md)
        if md_file.name.startswith("_"):
            continue
        
        process_page(env, md_file)
    
    return

def process_page(env: Environment, md_file_path: Path):
    """Process a single markdown page"""
    
    try:
        # Parse frontmatter & content
        data: MarkdownPage = parse_md(md_file_path)
        template_name = str(data.get('template')) + ".html"
        
        if template_name is None:
            raise ValueError(f"Error: Unable to extract template for {md_file_path}!")
        
        # Case for category index page
        if md_file_path.name == "index.md" and template_name == "category.html":
            content_dir = md_file_path.parent / "content"
            if content_dir.exists():
                # Collect items for that category
                # This could be blog posts, recipies, projects
                items = collect_items(content_dir, md_file_path.parent.name)
                data['items'] = items
        
        # Render with template
        template = env.get_template(template_name)
        html_content = template.render(**data)
        
        # Build path
        md_file_path = md_file_path.with_suffix('.html')
        build_path: Path = Path("build") / md_file_path

        # Create directory
        build_dir = build_path.parent
        build_dir.mkdir(parents=True, exist_ok=True)
        
        # Write file
        with open(build_path, 'w') as f:
            f.write(html_content)
        
        print(f"  → Built: {build_path}")
        
    except Exception as e:
        print(f"Error processing {md_file_path}: {e}")

def collect_items(content_dir: Path, category_name: str) -> List[dict]:
    
    items = []
    
    for md_file in content_dir.glob("*.md"):
        
        # Ignore drafts
        if md_file.name.startswith("_"):
            continue
    
        try:
            item_data = parse_md(md_file)
            item_url = f"/{category_name}/content/{md_file.stem}.html"
            
    
    return items

def parse_md(file_path: Path) -> MarkdownPage:
    """Parse markdowd file with YAML frontmatter"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    req_frontmatter_fields = ['title', 'template']
    frontmatter = {}
    
    if not content.startswith('---'):
        raise ValueError(f"Missing frontmatter in {file_path}")
    
    # Break up md file (parts -> ['', 'frontmatter', 'content'])
    parts = content.split('---', 2)
    if len(parts) < 3:
        raise ValueError(f"Incomplete frontmatter in {file_path}")
    
    # Frontmatter processing
    try:
        frontmatter = yaml.safe_load(parts[1]) or {}
    except yaml.YAMLError as e:
        raise ValueError(f"Invalid YAML frontmatter in {file_path}: {e}")

    # Content processing
    html_content = markdown.markdown(parts[2])
    
    # Return type
    page: MarkdownPage = {
        'title': frontmatter['title'],
        'template': frontmatter['template'],
        'content': html_content
    }

    # Check fields
    for field in req_frontmatter_fields:
        if field not in frontmatter:
            raise ValueError(f"Missing required frontmatter field `{field}` in {file_path}")
    
    # Optional fields
    if 'date' in frontmatter:
        try:
            frontmatter['date'] = parse_date(frontmatter['date'])
        except Exception as e:
            raise ValueError(f"Invalid date format in {file_path}: {frontmatter['date']}")
    if 'tags' in frontmatter:
        page['tags'] = frontmatter['tags']
    if 'categories' in frontmatter:
        page['categories'] = frontmatter['categories']
    
    return page
    
def serve(port):
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
        os.chdir(original_dir)

def clean():
    print("Cleaning build directory...")
