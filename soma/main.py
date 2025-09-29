'''
main.py

Implementation of functions used in cli.py.

Author: Oskar Floeck
Date: 11-09-2025
License: MIT
'''
import markdown
import yaml
from typing import TypedDict, List
from pathlib import Path
from jinja2 import Environment, FileSystemLoader
from datetime import datetime
from dateutil.parser import parse as parse_date
from .templates import DEFAULT_TEMPLATES
from .content import DEFAULT_CONTENT

def init(name):
    """Initialise project structure."""
    
    # Check if dir exists
    site_path = Path(name)
    if site_path.exists():
        print(f"Error: Directory `{name}` already exists!")
        return

    # Create directory structure
    print("soma: Creating directory structure..")
    site_path.mkdir()

    # Essential directories
    (site_path / "templates").mkdir()
    (site_path / "build").mkdir()    
    
    # Dummy directories
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
    print("soma: Building site...")
    
    env = Environment(loader=FileSystemLoader('templates'))
    
    # Check for index.md (home page) in root dir 
    root_index = Path("index.md")
    if not root_index.exists():
        print("Error: No index.md found in root directory!")
        print("To fix, please ensure index.md exists in root directory.")
        return
    
    # Process home
    print("soma: Processing home page")
    process_page(env, root_index, Path("build"))
    
    # Discover content directories
    content_dirs = discover_content()
    
    # Process content
    for dir in content_dirs:
        process_content_dir(env, dir)

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
                print(f"Either content or index.md not present in {directory.name}!")
            else:
                content_dirs.append(directory)
                print(f"{directory.name} OK")  
    
    return content_dirs

def process_content_dir(env: Environment, content_dir: Path):
    
    for md_file in content_dir.glob("**/*.md"):
        
        # Skip drafts (e.g. _new-post.md)
        if md_file.name.startswith("_"):
            continue
        
        # Determine output path
        build_path = Path("build") / content_dir.name / md_file.relative_to(content_dir)
        # print("soma (debug): " + str(build_path))
        
        process_page(env, md_file, build_path)
    
    return

def process_page(env: Environment, md_file: Path, out_dir: Path):
    """Process a single markdown page"""
    
    try:
        # Parse frontmatter & content
        data = parse_md(md_file)
        template = data.get('template', 'page.html')
        
    except Exception as e:
        print(f"Error processing {md_file}: {e}")

class MarkdownPage(TypedDict, total=False):
    """Define return type in parse_md"""
    title: str              # required
    date: datetime          # optional
    content: str            # required
    tags: List[str]         # optional
    categories: List[str]   # optional

def parse_md(file_path: Path) -> MarkdownPage:
    """Parse markdowd file with YAML frontmatter"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    required_fields = ['title']
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

    for field in required_fields:
        if field not in frontmatter:
            raise ValueError(f"Missing required frontmatter field `{field}` in {file_path}")
    
    # Content processing
    html_content = markdown.markdown(parts[2])
    
    # Return type
    page: MarkdownPage = {
        'title': frontmatter['title'],
        'content': html_content
    }
    
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
    print(f"Starting dev server on http://localhost:{port}")

def clean():
    print("Cleaning build directory...")
