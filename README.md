# soma
Static sites without the noise. A minimal static site generator built with Python.

This python tool allows users to quickly spin up a static site with minimal fuss and configuration. As this was a learning exercise to understand how static site generators work under the hood, its implementation prioritised simplicity over features.

![Alt text](https://i.imgur.com/8SYyAd3.png)


## Installation

```bash
# Install from uv (recommended)
uv tool install git+https://github.com/floeckdev/soma.git

# Install using pip
pip install git+https://github.com/floeckdev/soma.git

# For local development
git clone https://github.com/floeckdev/soma.git
cd soma
uv tool install -e .

# Verify
soma --help
```

**Requirements:** Python 3.13+, [uv](https://github.com/astral-sh/uv) (or pip)

## Quickstart

Running the following commands will spin up a default soma site ready to deploy.

```
# Choose your site directory
soma init

# Navigate to new site
cd new-soma

# Build the site
soma build

# Serve. Optionally with `--dev` for live reload
soma serve
```

## Features
Any folders added are recognised as categories, and content placed therin automatically processed as long as a few basic rules are followed.

1. The root dir of the project contains an index.md. This is your landing page. You are free to add additional pages such as about.md within this dir.

2. Category folders (placed within the root dir) contain an index.md which serve as the index page for the category and will collate all items for that category (accessible in items as seen in the template).

3. Each markdownfile contains a title, template and some content. Content files require a date. Tags and categories are optional.

### Example folder layout

Below is an example of what your layout should look like before building.

```
new-soma/
├── assets/
│   ├── css/
│   │   ├── pygments.css
│   │   └── style.css
│   └── fonts/
│       ├── cmunbi.otf
│       ├── cmunbx.otf
│       ├── cmumm.otf
│       └── cmunti.otf
├── blog/
│   ├── first-post.md
│   └── index.md
├── build/
├── projects/
│   ├── cool-project.md
│   └── index.md
├── templates/
│   ├── base.html
│   ├── category.html
│   ├── content.html
│   └── default.html
├── about.md
└── index.md
```

## Coming soon
- Search & pagination
- Tailwind support
- Better config
- Commands `new category` & `new item`
- Support for themes
